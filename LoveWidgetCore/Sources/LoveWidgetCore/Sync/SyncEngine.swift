import Foundation
import WidgetKit

// MARK: - SyncEngineDelegate

/// Callbacks from `SyncEngine` for state changes that require UI updates.
/// Implemented by `CanvasViewModel` on the `@MainActor`.
public protocol SyncEngineDelegate: AnyObject, Sendable {
    /// Called when a drawing update arrives from the partner
    func syncEngine(_ engine: SyncEngine, didReceiveRemoteDrawing drawing: Drawing) async
    /// Called when the sync status changes
    func syncEngine(_ engine: SyncEngine, didUpdateStatus status: SyncStatus) async
}

// MARK: - SyncEngine

/// The core synchronization actor for LoveWidget.
///
/// **Responsibilities:**
/// 1. Debounce local drawing changes (500ms) before uploading to reduce API calls
/// 2. Compute delta between current and last-synced drawing
/// 3. Persist every change to the App Group shared container (widget reads from here)
/// 4. Upload to Supabase with retry via exponential backoff
/// 5. Listen to Supabase Realtime for partner updates
/// 6. Merge incoming remote drawings with the local state via `ConflictResolver`
/// 7. Queue failed uploads and retry when connectivity returns
/// 8. Reload the WidgetKit timeline after every successful sync
///
/// **Threading model:**
/// - All mutable state lives inside the actor (Swift 6 safe)
/// - Delegates receive callbacks via `async` to bridge to `@MainActor`
/// - `Task.detached` is never used — all tasks are structured
public actor SyncEngine {

    // MARK: - Configuration

    /// How long to wait after the last stroke before uploading (debounce window)
    private static let uploadDebounceInterval: Duration = .milliseconds(500)

    // MARK: - Properties

    private let storage: AppGroupStorage
    private let drawingRepo: DrawingRepository
    private let conflictResolver: ConflictResolver
    private let backoff: ExponentialBackoff

    // Current pair context — set when pairing is established
    private var pairID: UUID?
    private var userID: UUID?

    // Last drawing we successfully uploaded (for delta computation)
    private var lastSyncedDrawing: Drawing = .empty

    // The current canonical drawing (includes any unsynced local changes)
    private var currentDrawing: Drawing = .empty

    // Debounce: cancel pending upload when a new stroke arrives within the window
    private var debounceTask: Task<Void, any Error>?

    // Background listener task (Supabase Realtime subscription)
    private var listenerTask: Task<Void, Never>?

    private var _status: SyncStatus = .idle

    /// Whether the engine has an active pair
    public var hasPair: Bool { pairID != nil }

    private weak var delegate: (any SyncEngineDelegate)?
    private let logger = LWLogger.sync

    // MARK: - Initialization

    public init(
        storage: AppGroupStorage,
        drawingRepo: DrawingRepository,
        conflictResolver: ConflictResolver,
        backoff: ExponentialBackoff = .sync
    ) {
        self.storage = storage
        self.drawingRepo = drawingRepo
        self.conflictResolver = conflictResolver
        self.backoff = backoff
    }

    // MARK: - Lifecycle

    /// Attach the delegate for UI callbacks.
    public func setDelegate(_ delegate: any SyncEngineDelegate) {
        self.delegate = delegate
    }

    /// Start the sync engine for the given pair.
    ///
    /// - Parameters:
    ///   - pairID: The active pair's UUID
    ///   - userID: The current user's UUID
    public func start(pairID: UUID, userID: UUID) async {
        self.pairID = pairID
        self.userID = userID

        setStatus(.connecting)

        // Load last known state from local storage
        if let localDrawing = try? storage.loadDrawing() {
            currentDrawing = localDrawing
            lastSyncedDrawing = localDrawing
        }

        // Fetch latest from server (may be ahead of local)
        await fetchAndMergeRemoteDrawing()

        // Start listening for partner updates
        startListeningForRemoteUpdates()

        // Process any pending upload from a previous offline session
        await retryPendingUploadIfNeeded()
    }

    /// Stop the sync engine (called when unpairing or on app termination).
    public func stop() {
        listenerTask?.cancel()
        listenerTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        setStatus(.idle)
        logger.info("SyncEngine stopped.")
    }

    // MARK: - Drawing Submission

    /// Submit a new drawing state for synchronization.
    ///
    /// Debounces rapid changes (e.g., during active drawing) so we don't
    /// spam the server with every single point. After the debounce window
    /// elapses with no new calls, the drawing is uploaded.
    ///
    /// - Parameter drawing: The updated drawing to sync
    public func submit(drawing: Drawing) async {
        currentDrawing = drawing

        // Save immediately to local storage so the widget always has fresh data
        try? storage.saveDrawing(drawing)

        // Cancel any pending debounced upload
        debounceTask?.cancel()

        // Schedule a new upload after the debounce interval
        debounceTask = Task<Void, Error> {
            do {
                try await Task.sleep(for: Self.uploadDebounceInterval)
                await uploadCurrentDrawing()
            } catch is CancellationError {
                // Normal — a newer submission arrived within the debounce window
            }
        }
    }

    // MARK: - Upload

    private func uploadCurrentDrawing() async {
        guard let pairID, let userID else {
            logger.warning("Cannot upload: not configured with pair/user IDs.")
            return
        }

        setStatus(.syncing)

        do {
            try await backoff.retry(maxAttempts: 5) {
                try await self.drawingRepo.upsertDrawing(
                    self.currentDrawing,
                    pairID: pairID,
                    userID: userID
                )
            }

            lastSyncedDrawing = currentDrawing

            // Clear any queued pending upload since we succeeded
            try? storage.clearPendingUpload()

            // Refresh the widget timeline
            reloadWidgetTimeline()

            setStatus(.connected)
            let version = currentDrawing.version
            logger.info("Successfully uploaded drawing v\(version)")
        } catch {
            logger.error("Upload failed after retries: \(error.localizedDescription)")
            setStatus(.error(message: error.localizedDescription))

            // Persist the failed upload for retry on next launch
            let pending = PendingUpload(
                drawing: currentDrawing,
                pairID: pairID,
                userID: userID
            )
            try? storage.savePendingUpload(pending)
        }
    }

    // MARK: - Remote Updates

    private func startListeningForRemoteUpdates() {
        guard let pairID, let userID else { return }

        listenerTask?.cancel()
        listenerTask = Task {
            logger.info("Starting realtime listener for pair \(pairID)")
            for await remoteDrawing in await drawingRepo.drawingUpdates(
                pairID: pairID,
                excludingUserID: userID
            ) {
                await handleRemoteDrawing(remoteDrawing)
            }
        }
    }

    private func handleRemoteDrawing(_ remote: Drawing) async {
        logger.info("Received remote drawing v\(remote.version)")

        // Merge remote with our current state to preserve unsent local strokes
        let merged = await conflictResolver.merge(local: currentDrawing, remote: remote)

        currentDrawing = merged
        lastSyncedDrawing = merged

        // Persist the merged drawing so it survives app relaunch
        try? storage.saveDrawing(merged)

        // Only pass partner's strokes to the UI and widget
        let partnerStrokes = remote.strokes(excluding: userID ?? UUID())
        try? storage.savePartnerDrawing(partnerStrokes)
        reloadWidgetTimeline()

        await delegate?.syncEngine(self, didReceiveRemoteDrawing: partnerStrokes)
        setStatus(.connected)
    }

    private func fetchAndMergeRemoteDrawing() async {
        guard let pairID, let userID else { return }
        do {
            guard let (remote, createdBy) = try await drawingRepo.fetchDrawingWithAuthor(pairID: pairID) else {
                setStatus(.connected)
                return
            }

            if createdBy == userID {
                // Drawing on the server is our own — merge into current state
                currentDrawing = await conflictResolver.merge(local: currentDrawing, remote: remote)
                lastSyncedDrawing = currentDrawing
                // Remote may contain partner strokes from a prior merge;
                // extract only partner strokes for the UI and widget.
                let partnerStrokes = remote.strokes(excluding: userID)
                try? storage.savePartnerDrawing(partnerStrokes)
                reloadWidgetTimeline()
                await delegate?.syncEngine(self, didReceiveRemoteDrawing: partnerStrokes)
                setStatus(.connected)
            } else {
                await handleRemoteDrawing(remote)
            }
        } catch {
            logger.warning("Initial fetch failed: \(error.localizedDescription)")
            setStatus(.disconnected(reason: error.localizedDescription))
        }
    }

    /// Manually fetch the latest drawing from the server and update the UI.
    public func fetchLatestPartnerDrawing() async {
        guard let pairID, let userID else { return }
        do {
            guard let (remote, createdBy) = try await drawingRepo.fetchDrawingWithAuthor(pairID: pairID) else {
                logger.info("No remote drawing found.")
                return
            }
            if createdBy == userID {
                let partnerStrokes = remote.strokes(excluding: userID)
                try? storage.savePartnerDrawing(partnerStrokes)
                reloadWidgetTimeline()
                await delegate?.syncEngine(self, didReceiveRemoteDrawing: partnerStrokes)
            } else {
                await handleRemoteDrawing(remote)
            }
        } catch {
            logger.warning("Manual fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Pending Upload Retry

    private func retryPendingUploadIfNeeded() async {
        guard let pending = try? storage.loadPendingUpload(),
              pending.attemptCount < PendingUpload.maximumAttempts else {
            try? storage.clearPendingUpload()
            return
        }

        logger.info(
            "Retrying pending upload (attempt \(pending.attemptCount + 1)/\(PendingUpload.maximumAttempts))…"
        )
        currentDrawing = pending.drawing
        await uploadCurrentDrawing()
    }

    // MARK: - Widget

    private func reloadWidgetTimeline() {
        // WidgetCenter is available only in the app target (not SPM package),
        // so we signal via UserDefaults that the widget should refresh.
        // The App target reads this and calls WidgetCenter.shared.reloadAllTimelines().
        StorageKeys.userDefaults().set(true, forKey: StorageKeys.widgetNeedsRefreshKey)
    }

    // MARK: - Status

    private func setStatus(_ status: SyncStatus) {
        _status = status
        Task { await delegate?.syncEngine(self, didUpdateStatus: status) }
    }

    public var status: SyncStatus { _status }
}

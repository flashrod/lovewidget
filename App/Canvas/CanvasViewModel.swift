import SwiftUI
import LoveWidgetCore
import WidgetKit

@Observable
@MainActor
public final class CanvasViewModel {

    // MARK: - Published State

    /// My drawing (strokes I'm currently drawing)
    public var drawing: Drawing = .empty

    /// The stroke currently being drawn
    public var activeStroke: Stroke?

    /// The last drawing received from partner
    public var partnerDrawing: Drawing = .empty

    /// Current sync/connection status
    public var syncStatus: SyncStatus = .idle

    /// Name of the partner user
    public var partnerName: String = "Your Partner"

    /// When the drawing was last synced with the server
    public var lastSyncedAt: Date?

    /// Whether there's an unsaved local change being debounced
    public var isPendingUpload: Bool = false

    /// Zoom scale for the canvas
    public var scale: CGFloat = 1.0

    /// Pan offset for the canvas
    public var offset: CGSize = .zero

    // MARK: - Tool State

    public var selectedColor: StrokeColor = .crimson
    public var brushWidth: Double = 3.0
    public var brushOpacity: Double = 1.0
    public var isColorPickerVisible: Bool = false

    // MARK: - Undo/Redo State

    public var canUndo: Bool = false
    public var canRedo: Bool = false

    /// Local reactions to partner's drawing
    public var reactions: [(emoji: String, date: Date)] = []

    /// Non-nil when the last send failed (cleared on next successful send)
    public var lastSendError: String?

    /// Whether a manual fetch is in progress
    public var isFetchingPartner: Bool = false

    // MARK: - Private

    private let engine: DrawingEngine
    private var syncEngine: SyncEngine?

    // MARK: - Initialization

    public init() {
        self.engine = DrawingEngine()
        drawing = engine.drawing
        activeStroke = engine.activeStroke
        canUndo = engine.canUndo
        canRedo = engine.canRedo
    }

    // MARK: - Sync Engine Binding

    public func attachSyncEngine(_ sync: SyncEngine) {
        self.syncEngine = sync
    }

    public func loadStoredDrawing(_ stored: Drawing) {
        engine.loadDrawing(stored)
        syncDrawingFromEngine()
    }

    // MARK: - Drawing Actions

    public func beginStroke(at point: CGPoint, pressure: Double = 1.0) {
        engine.currentColor = selectedColor
        engine.currentWidth = brushWidth
        engine.currentOpacity = brushOpacity
        engine.beginStroke(at: point, pressure: pressure)
        syncDrawingFromEngine()
    }

    public func continueStroke(to point: CGPoint, pressure: Double = 1.0) {
        engine.continueStroke(to: point, pressure: pressure)
        activeStroke = engine.activeStroke
    }

    public func endStroke() {
        let newDrawing = engine.endStroke()
        drawing = newDrawing
        activeStroke = nil
        canUndo = engine.canUndo
        canRedo = engine.canRedo
        syncDrawingFromEngine()
    }

    public func cancelStroke() {
        engine.cancelStroke()
        activeStroke = nil
    }

    // MARK: - Canvas Controls

    public func undo() {
        let newDrawing = engine.undo()
        drawing = newDrawing
        canUndo = engine.canUndo
        canRedo = engine.canRedo
    }

    public func redo() {
        let newDrawing = engine.redo()
        drawing = newDrawing
        canUndo = engine.canUndo
        canRedo = engine.canRedo
    }

    public func clear() {
        drawing = engine.clear()
        canUndo = engine.canUndo
        canRedo = engine.canRedo
        syncDrawingFromEngine()
        try? AppGroupStorage.shared.saveDrawing(drawing)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await syncEngine?.submit(drawing: drawing) }
    }

    public func resetZoom() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            scale = 1.0
            offset = .zero
        }
    }

    public func sendDrawing() {
        let capturedDrawing = drawing
        lastSendError = nil
        guard let se = syncEngine else {
            lastSendError = "Not connected"
            return
        }
        Task {
            guard await se.hasPair else {
                await MainActor.run { self.lastSendError = "Pair first in the Pair tab" }
                return
            }
            await se.submit(drawing: capturedDrawing)
            await MainActor.run {
                let entry = Drawing.Entry(
                    drawing: capturedDrawing,
                    authorName: partnerName,
                    type: .sent
                )
                try? AppGroupStorage.shared.appendHistory(entry)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    public func addReaction(_ emoji: String) {
        reactions.append((emoji, Date()))
        if reactions.count > 20 {
            reactions = Array(reactions.suffix(20))
        }
    }

    public func fetchLatestDrawing() {
        Task {
            isFetchingPartner = true
            await syncEngine?.fetchLatestPartnerDrawing()
            isFetchingPartner = false
        }
    }

    // MARK: - Remote Drawing

    public func applyRemoteDrawing(_ remote: Drawing) {
        partnerDrawing = remote
        lastSyncedAt = Date()
        let entry = Drawing.Entry(
            drawing: remote,
            authorName: partnerName,
            type: .received
        )
        try? AppGroupStorage.shared.appendHistory(entry)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private

    private func syncDrawingFromEngine() {
        drawing = engine.drawing
        activeStroke = engine.activeStroke
        canUndo = engine.canUndo
        canRedo = engine.canRedo
    }
}

// MARK: - SyncEngineDelegate

extension CanvasViewModel: SyncEngineDelegate {
    nonisolated public func syncEngine(
        _ engine: SyncEngine,
        didReceiveRemoteDrawing drawing: Drawing
    ) async {
        await MainActor.run {
            self.applyRemoteDrawing(drawing)
        }
    }

    nonisolated public func syncEngine(
        _ engine: SyncEngine,
        didUpdateStatus status: SyncStatus
    ) async {
        await MainActor.run {
            self.syncStatus = status
        }
    }
}

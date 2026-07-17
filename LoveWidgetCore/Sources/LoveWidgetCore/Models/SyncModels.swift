import Foundation

// MARK: - StrokeDelta

/// The minimal diff between two drawings used for efficient synchronization.
///
/// Instead of transmitting the full drawing (~50KB for a complex canvas),
/// LoveWidget sends only the strokes that changed since the last sync.
/// A typical incremental update is <1KB.
///
/// Usage:
/// ```swift
/// let delta = StrokeDelta.compute(from: previousDrawing, to: currentDrawing)
/// // Upload delta.added strokes and delta.removed IDs
/// ```
public struct StrokeDelta: Codable, Sendable, Equatable {
    /// New strokes to be added to the canvas
    public let added: [Stroke]
    /// IDs of strokes that were removed (erased)
    public let removed: [UUID]
    /// The drawing version after applying this delta
    public let resultingVersion: Int

    public init(added: [Stroke] = [], removed: [UUID] = [], resultingVersion: Int) {
        self.added = added
        self.removed = removed
        self.resultingVersion = resultingVersion
    }

    /// True when this delta contains no changes
    public var isEmpty: Bool { added.isEmpty && removed.isEmpty }

    // MARK: - Delta Computation

    /// Compute the minimal delta between two drawing states.
    ///
    /// - Parameters:
    ///   - old: The previous known state of the drawing
    ///   - new: The current state of the drawing
    /// - Returns: A delta describing what changed
    public static func compute(from old: Drawing, to new: Drawing) -> StrokeDelta {
        let oldIDs = Set(old.strokes.map(\.id))
        let newIDs = Set(new.strokes.map(\.id))

        let addedIDs   = newIDs.subtracting(oldIDs)
        let removedIDs = oldIDs.subtracting(newIDs)

        let added   = new.strokes.filter { addedIDs.contains($0.id) }
        let removed = Array(removedIDs)

        return StrokeDelta(
            added: added,
            removed: removed,
            resultingVersion: new.version
        )
    }

    // MARK: - Application

    /// Applies this delta to a drawing, returning the updated drawing.
    ///
    /// The applied result may differ from the original new drawing if strokes
    /// were reordered during conflict resolution — that is intentional.
    public func applying(to drawing: Drawing) -> Drawing {
        var strokes = drawing.strokes
        // Remove deleted strokes
        strokes.removeAll { removed.contains($0.id) }
        // Deduplicate and append new strokes
        let existingIDs = Set(strokes.map(\.id))
        let uniqueAdded = added.filter { !existingIDs.contains($0.id) }
        strokes.append(contentsOf: uniqueAdded)
        return Drawing(strokes: strokes, updatedAt: Date(), version: resultingVersion)
    }
}

// MARK: - SyncEvent

/// A Supabase Realtime broadcast event carrying a drawing delta.
///
/// Broadcast payload sent via the Supabase Realtime channel for a pair.
/// Both clients listen on the same channel; each ignores events it created.
public struct SyncEvent: Codable, Sendable, Equatable {
    /// The pair this event belongs to
    public let pairID: UUID
    /// The actual changes
    public let delta: StrokeDelta
    /// When the event was generated on the sender's machine
    public let timestamp: Date
    /// UUID of the user who made the change (for ignoring own events)
    public let createdBy: UUID

    public init(
        pairID: UUID,
        delta: StrokeDelta,
        timestamp: Date = Date(),
        createdBy: UUID
    ) {
        self.pairID = pairID
        self.delta = delta
        self.timestamp = timestamp
        self.createdBy = createdBy
    }

    enum CodingKeys: String, CodingKey {
        case pairID    = "pair_id"
        case delta
        case timestamp
        case createdBy = "created_by"
    }
}

// MARK: - SyncStatus

/// The current state of the real-time synchronization connection.
///
/// Drives UI indicators (menu bar icon, canvas status badge).
/// All cases are `Sendable` to cross actor boundaries safely.
public enum SyncStatus: Sendable, Equatable, CustomStringConvertible {
    case idle
    case connecting
    case connected
    case syncing
    case disconnected(reason: String)
    case error(message: String)

    public var isLive: Bool {
        switch self {
        case .connected, .syncing: return true
        default: return false
        }
    }

    public var description: String {
        switch self {
        case .idle:                      return "Idle"
        case .connecting:                return "Connecting…"
        case .connected:                 return "Connected"
        case .syncing:                   return "Syncing…"
        case .disconnected(let reason):  return "Disconnected: \(reason)"
        case .error(let message):        return "Error: \(message)"
        }
    }

    /// SF Symbol name for this status (for status bar / indicators)
    public var systemImageName: String {
        switch self {
        case .idle:          return "wifi.slash"
        case .connecting:    return "wifi.exclamationmark"
        case .connected:     return "wifi"
        case .syncing:       return "arrow.triangle.2.circlepath"
        case .disconnected:  return "wifi.slash"
        case .error:         return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - PendingUpload

/// A drawing upload that failed and is queued for retry.
///
/// Persisted in the App Group container so it survives app restarts.
/// The sync engine retries this with exponential backoff when connectivity returns.
public struct PendingUpload: Codable, Sendable, Equatable {
    public let drawing: Drawing
    public let pairID: UUID
    public let userID: UUID
    public let queuedAt: Date
    public let attemptCount: Int

    public init(
        drawing: Drawing,
        pairID: UUID,
        userID: UUID,
        queuedAt: Date = Date(),
        attemptCount: Int = 0
    ) {
        self.drawing = drawing
        self.pairID = pairID
        self.userID = userID
        self.queuedAt = queuedAt
        self.attemptCount = attemptCount
    }

    /// Returns a copy with the attempt counter incremented
    public func incrementingAttempt() -> PendingUpload {
        PendingUpload(
            drawing: drawing,
            pairID: pairID,
            userID: userID,
            queuedAt: queuedAt,
            attemptCount: attemptCount + 1
        )
    }

    /// Maximum attempts before giving up (prevents unbounded retry loops)
    public static let maximumAttempts = 10
}

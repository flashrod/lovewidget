import Foundation

// MARK: - ConflictResolver

/// Resolves conflicts between two diverged drawing states.
///
/// **Strategy: Last-Write-Wins at the stroke level**
///
/// When both users draw simultaneously while offline:
/// 1. Each side's local strokes are collected by UUID
/// 2. Strokes present in only one version are kept unconditionally
/// 3. Strokes present in both versions use `createdAt` as a tiebreaker
///    (the newer stroke wins — ensures the most recent intent is preserved)
/// 4. Removals are honored: if a stroke is absent in either version, it stays absent
///
/// The merged result is a Drawing that contains the union of both users' work.
public actor ConflictResolver {

    private let logger = LWLogger.sync

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Merge a local drawing with a remote drawing.
    ///
    /// - Parameters:
    ///   - local: The current state on this device (may have unsent strokes)
    ///   - remote: The state just fetched from Supabase
    /// - Returns: The merged drawing with a new version
    public func merge(local: Drawing, remote: Drawing) -> Drawing {
        // Fast path: one side is empty
        if local.strokes.isEmpty { return bumpVersion(remote) }
        if remote.strokes.isEmpty { return bumpVersion(local) }

        // Fast path: versions are identical (no conflict)
        if local == remote { return local }

        logger.info(
            "Merging: local v\(local.version) (\(local.strokes.count) strokes) " +
            "vs remote v\(remote.version) (\(remote.strokes.count) strokes)"
        )

        let merged = mergeStrokes(from: local, and: remote)
        let resultVersion = max(local.version, remote.version) + 1

        let result = Drawing(
            strokes: merged,
            updatedAt: Date(),
            version: resultVersion
        )

        logger.info("Merge complete: \(result.strokes.count) strokes, v\(resultVersion)")
        return result
    }

    // MARK: - Private

    private func mergeStrokes(from local: Drawing, and remote: Drawing) -> [Stroke] {
        // Build lookup maps for O(1) access
        let localByID:  [UUID: Stroke] = Dictionary(uniqueKeysWithValues: local.strokes.map  { ($0.id, $0) })
        let remoteByID: [UUID: Stroke] = Dictionary(uniqueKeysWithValues: remote.strokes.map { ($0.id, $0) })

        let allIDs = Set(localByID.keys).union(remoteByID.keys)
        var merged: [Stroke] = []

        for id in allIDs {
            switch (localByID[id], remoteByID[id]) {
            case let (localStroke?, remoteStroke?):
                // Both have the stroke: keep the newer version
                let winner = localStroke.createdAt >= remoteStroke.createdAt
                    ? localStroke
                    : remoteStroke
                merged.append(winner)

            case let (localStroke?, nil):
                // Only local has it: keep it (local user drew it)
                merged.append(localStroke)

            case let (nil, remoteStroke?):
                // Only remote has it: keep it (partner drew it)
                merged.append(remoteStroke)

            case (nil, nil):
                // Should be logically impossible
                break
            }
        }

        // Sort by createdAt to maintain consistent render order (painter's algorithm)
        return merged.sorted { $0.createdAt < $1.createdAt }
    }

    private func bumpVersion(_ drawing: Drawing) -> Drawing {
        Drawing(
            strokes: drawing.strokes,
            updatedAt: drawing.updatedAt,
            version: drawing.version + 1
        )
    }
}

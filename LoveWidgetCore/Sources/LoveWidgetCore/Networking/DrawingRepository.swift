import Foundation
@preconcurrency import Supabase

// MARK: - DrawingRepositoryError

public enum DrawingRepositoryError: Error, LocalizedError, Sendable {
    case notFound(pairID: UUID)
    case versionConflict(local: Int, remote: Int)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "No drawing found for pair \(id)."
        case .versionConflict(let local, let remote):
            return "Version conflict: local=\(local), remote=\(remote). Merging."
        }
    }
}

// MARK: - DrawingRepository

/// Manages the single `drawings` row per pair in Supabase.
///
/// **Storage strategy:**
/// The full `Drawing` JSON is stored in the `drawing_json` JSONB column.
/// On each sync, the row is upserted (INSERT ON CONFLICT UPDATE).
/// Conflict resolution happens before uploading via `ConflictResolver`.
public actor DrawingRepository {

    // MARK: - Row Types

    /// Raw Supabase row for the drawings table
    private struct DrawingRow: Decodable {
        // swiftlint:disable identifier_name
        let id: UUID
        let pair_id: UUID
        let drawing_json: Drawing     // JSONB decoded directly into Drawing
        let updated_at: Date
        let created_by: UUID
        // swiftlint:enable identifier_name
    }

    /// Upsert payload: insert or update if pair_id already exists
    private struct DrawingUpsert: Encodable {
        // swiftlint:disable identifier_name
        let pair_id: String
        let drawing_json: Drawing
        let created_by: String
        // swiftlint:enable identifier_name
    }

    // MARK: - Properties

    private let clientActor: SupabaseClientActor
    private let logger = LWLogger.network

    // MARK: - Initialization

    public init(clientActor: SupabaseClientActor) {
        self.clientActor = clientActor
    }

    // MARK: - Public API

    /// Fetch the latest drawing for a pair from Supabase.
    ///
    /// Returns `.empty` if no drawing has been uploaded yet.
    public func fetchDrawing(pairID: UUID) async throws -> Drawing {
        let rows: [DrawingRow] = try await clientActor.supabase
            .from("drawings")
            .select()
            .eq("pair_id", value: pairID.uuidString)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            logger.info("No drawing yet for pair \(pairID) — using empty canvas.")
            return .empty
        }

        logger.debug("Fetched drawing v\(row.drawing_json.version) for pair \(pairID)")
        return row.drawing_json
    }

    /// Upsert the full drawing to Supabase.
    ///
    /// Uses `onConflict: "pair_id"` so a second upload for the same pair
    /// updates the existing row instead of creating a duplicate.
    ///
    /// - Parameters:
    ///   - drawing: The current drawing state to persist
    ///   - pairID: The pair this drawing belongs to
    ///   - userID: The user performing the upload (stored as `created_by`)
    public func upsertDrawing(_ drawing: Drawing, pairID: UUID, userID: UUID) async throws {
        let upsert = DrawingUpsert(
            pair_id: pairID.uuidString,
            drawing_json: drawing,
            created_by: userID.uuidString
        )

        try await clientActor.supabase
            .from("drawings")
            .upsert(upsert, onConflict: "pair_id")
            .execute()

        logger.info("Upserted drawing v\(drawing.version) for pair \(pairID)")
    }

    /// Subscribe to real-time drawing updates for a pair.
    ///
    /// Returns an `AsyncStream` that emits a new `Drawing` whenever the partner
    /// updates the shared canvas. The stream never emits the caller's own uploads
    /// (filtered by `userID`).
    ///
    /// - Parameters:
    ///   - pairID: The pair to listen on
    ///   - excludingUserID: Skip events where `created_by` equals this user ID
    public func drawingUpdates(
        pairID: UUID,
        excludingUserID: UUID
    ) -> AsyncStream<Drawing> {
        AsyncStream { continuation in
            Task {
                let channel = await clientActor.supabase.realtimeV2
                    .channel("drawings:\(pairID.uuidString)")

                let stream = channel.postgresChange(
                    AnyAction.self,
                    table: "drawings",
                    filter: "pair_id=eq.\(pairID.uuidString)"
                )

                await channel.subscribe()
                LWLogger.network.info("Subscribed to drawing updates for pair \(pairID)")

                for await action in stream {
                    guard case .update(let update) = action else { continue }
                    let record = update.record

                    guard let createdByAny = record["created_by"],
                          case .string(let createdByString) = createdByAny,
                          let createdByUUID = UUID(uuidString: createdByString),
                          createdByUUID != excludingUserID
                    else { continue }

                    guard let drawingAny = record["drawing_json"],
                          let drawingData = try? JSONEncoder().encode(drawingAny),
                          let drawing = try? decoder.decode(Drawing.self, from: drawingData)
                    else { continue }

                    continuation.yield(drawing)
                }

                continuation.onTermination = { _ in
                    Task { await channel.unsubscribe() }
                }
            }
        }
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

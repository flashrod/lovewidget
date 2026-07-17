import Foundation
@preconcurrency import Supabase

// MARK: - PairRepositoryError

public enum PairRepositoryError: Error, LocalizedError, Sendable {
    case invalidInviteCode(String)
    case inviteCodeNotFound(String)
    case inviteCodeAlreadyUsed(String)
    case cannotPairWithSelf
    case notPaired
    case userNotMemberOfPair

    public var errorDescription: String? {
        switch self {
        case .invalidInviteCode(let code):
            return "'\(code)' is not a valid invite code. Expected format: XXX-XXXX."
        case .inviteCodeNotFound(let code):
            return "No pair found for invite code '\(code)'. Please check and try again."
        case .inviteCodeAlreadyUsed(let code):
            return "Invite code '\(code)' has already been used."
        case .cannotPairWithSelf:
            return "You cannot pair with yourself."
        case .notPaired:
            return "You are not currently paired with anyone."
        case .userNotMemberOfPair:
            return "You are not a member of this pair."
        }
    }
}

// MARK: - PairRepository

/// Manages pairing operations against the `pairs` table in Supabase.
public actor PairRepository {

    // MARK: - Row Types

    private struct PairRow: Decodable {
        // swiftlint:disable identifier_name
        let id: UUID
        let invite_code: String
        let user_one: UUID
        let user_two: UUID?
        let created_at: Date
        // swiftlint:enable identifier_name

        func toPair() -> Pair {
            Pair(
                id: id,
                inviteCode: invite_code,
                userOneID: user_one,
                userTwoID: user_two,
                createdAt: created_at
            )
        }
    }

    private struct PairInsert: Encodable {
        // swiftlint:disable identifier_name
        let invite_code: String
        let user_one: String   // UUID as string for Supabase
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

    /// Create a new pair record with a generated invite code.
    ///
    /// - Parameter userOneID: UUID of the user creating the pair
    /// - Returns: The newly created `Pair`
    public func createPair(userOneID: UUID) async throws -> Pair {
        let code = InviteCodeGenerator.generate()
        let insert = PairInsert(invite_code: code, user_one: userOneID.uuidString)

        let row: PairRow = try await clientActor.supabase
            .from("pairs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        logger.info("Created pair \(row.id) with invite code \(code)")
        return row.toPair()
    }

    /// Join an existing pair using the invite code.
    ///
    /// Calls the `join_pair(invite_code, user_two_id)` Postgres function,
    /// which locks the row atomically and validates the code.
    ///
    /// - Parameters:
    ///   - inviteCode: The code entered by the second user
    ///   - userTwoID: UUID of the joining user
    /// - Returns: The completed `Pair`
    public func joinPair(inviteCode: String, userTwoID: UUID) async throws -> Pair {
        let normalized = InviteCodeGenerator.normalize(inviteCode)
        guard InviteCodeGenerator.isValid(normalized) else {
            throw PairRepositoryError.invalidInviteCode(inviteCode)
        }

        do {
            let row: PairRow = try await clientActor.supabase
                .rpc("join_pair", params: [
                    "p_invite_code": normalized,
                    "p_user_two_id": userTwoID.uuidString,
                ])
                .select()
                .single()
                .execute()
                .value

            logger.info("Joined pair \(row.id) via invite code \(normalized)")
            return row.toPair()
        } catch let error as PostgrestError {
            // Map Postgres exception messages to typed errors
            let message = error.message
            if message.contains("invite_code_not_found") {
                throw PairRepositoryError.inviteCodeNotFound(normalized)
            } else if message.contains("invite_code_already_used") {
                throw PairRepositoryError.inviteCodeAlreadyUsed(normalized)
            } else if message.contains("cannot_pair_with_self") {
                throw PairRepositoryError.cannotPairWithSelf
            }
            throw error
        }
    }

    /// Fetch the pair for a given user. Returns nil if no pair exists.
    public func fetchPair(for userID: UUID) async throws -> Pair? {
        let rows: [PairRow] = try await clientActor.supabase
            .from("pairs")
            .select()
            .or("user_one.eq.\(userID.uuidString),user_two.eq.\(userID.uuidString)")
            .limit(1)
            .execute()
            .value

        return rows.first?.toPair()
    }

    /// Fetch a pair by ID.
    public func fetchPair(id: UUID) async throws -> Pair? {
        let rows: [PairRow] = try await clientActor.supabase
            .from("pairs")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first?.toPair()
    }

    /// Delete (reset) a pair. Only call this when the user explicitly resets.
    ///
    /// - Parameter pairID: The pair to delete
    public func deletePair(id pairID: UUID) async throws {
        try await clientActor.supabase
            .from("pairs")
            .delete()
            .eq("id", value: pairID.uuidString)
            .execute()

        logger.info("Deleted pair \(pairID)")
    }
}

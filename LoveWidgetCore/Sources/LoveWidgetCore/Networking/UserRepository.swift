import Foundation
@preconcurrency import Supabase

// MARK: - UserRepositoryError

public enum UserRepositoryError: Error, LocalizedError, Sendable {
    case notFound(deviceID: String)
    case unauthenticated

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "No user found for device ID '\(id)'."
        case .unauthenticated:
            return "User is not authenticated with Supabase."
        }
    }
}

// MARK: - UserRepository

/// Manages CRUD operations for `users` records in Supabase.
///
/// **Lifecycle:**
/// On first launch, a user record does not exist. The app calls
/// `createOrFetchUser(name:)` which performs an upsert.
/// On subsequent launches, `fetchUser(by:)` returns the existing record.
public actor UserRepository {

    // MARK: - Properties

    private let clientActor: SupabaseClientActor
    private let logger = LWLogger.network

    // MARK: - Row Types (match Supabase table schema)

    private struct UserRow: Decodable {
        let id: UUID
        let name: String
        // swiftlint:disable:next identifier_name
        let device_id: String
        let created_at: Date

        func toAppUser() -> AppUser {
            AppUser(id: id, name: name, deviceID: device_id, createdAt: created_at)
        }
    }

    private struct UserInsert: Encodable {
        let id: UUID
        let name: String
        // swiftlint:disable:next identifier_name
        let device_id: String
    }

    private struct UserUpdate: Encodable {
        let name: String
    }

    // MARK: - Initialization

    public init(clientActor: SupabaseClientActor) {
        self.clientActor = clientActor
    }

    // MARK: - Public API

    /// Fetch the user record for this device, creating one if it doesn't exist.
    ///
    /// - Parameters:
    ///   - name: Display name (only used during creation; ignored on subsequent calls)
    ///   - deviceID: Stable hardware UUID for this device
    /// - Returns: The fetched or newly created `AppUser`
    public func createOrFetchUser(name: String, deviceID: String) async throws -> AppUser {
        // Ensure we're authenticated so auth.uid() is valid
        try await clientActor.ensureAuthenticated()

        guard let authUserID = await clientActor.authenticatedUserID else {
            throw UserRepositoryError.unauthenticated
        }

        // Try to fetch by device_id first (handles reinstall or new device)
        if let existing = try await fetchUser(by: deviceID) {
            logger.info("Found existing user: \(existing.id)")
            return existing
        }

        // Create new user record
        let insert = UserInsert(id: authUserID, name: name, device_id: deviceID)
        let row: UserRow = try await clientActor.supabase
            .from("users")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        logger.info("Created new user: \(row.id)")
        return row.toAppUser()
    }

    /// Fetch a user record by device ID. Returns nil if not found.
    public func fetchUser(by deviceID: String) async throws -> AppUser? {
        let rows: [UserRow] = try await clientActor.supabase
            .from("users")
            .select()
            .eq("device_id", value: deviceID)
            .limit(1)
            .execute()
            .value

        return rows.first?.toAppUser()
    }

    /// Fetch any user by their UUID.
    public func fetchUser(id: UUID) async throws -> AppUser? {
        let rows: [UserRow] = try await clientActor.supabase
            .from("users")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first?.toAppUser()
    }

    /// Update the display name for the current user.
    public func updateName(_ name: String, userID: UUID) async throws {
        let update = UserUpdate(name: name)
        try await clientActor.supabase
            .from("users")
            .update(update)
            .eq("id", value: userID.uuidString)
            .execute()

        logger.info("Updated display name for user \(userID)")
    }
}

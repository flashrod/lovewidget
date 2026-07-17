import Foundation

// MARK: - Pair

/// Represents a pairing between exactly two LoveWidget users.
///
/// A pair is created when user one generates an invite code. It becomes
/// complete when user two enters that code. Once complete, both users
/// share a single drawing canvas identified by `id`.
public struct Pair: Codable, Sendable, Equatable, Identifiable {
    /// Unique pair identifier — also the key for the shared drawing
    public let id: UUID
    /// Short invite code like "ABC-9GH" (expires after 24 hours)
    public let inviteCode: String
    /// The user who created the pair and generated the invite code
    public let userOneID: UUID
    /// The user who joined via the invite code. Nil until someone joins.
    public let userTwoID: UUID?
    /// When the pair was created
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        inviteCode: String,
        userOneID: UUID,
        userTwoID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.inviteCode = inviteCode
        self.userOneID = userOneID
        self.userTwoID = userTwoID
        self.createdAt = createdAt
    }

    // MARK: - Derived Properties

    /// True when both users have joined
    public var isComplete: Bool { userTwoID != nil }

    /// Given the current user's ID, returns the partner's ID
    public func partnerID(currentUserID: UUID) -> UUID? {
        if userOneID == currentUserID { return userTwoID }
        if userTwoID == currentUserID { return userOneID }
        return nil
    }

    /// Whether the given user is part of this pair
    public func includes(userID: UUID) -> Bool {
        userOneID == userID || userTwoID == userID
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case inviteCode = "invite_code"
        case userOneID  = "user_one"
        case userTwoID  = "user_two"
        case createdAt  = "created_at"
    }
}

// MARK: - PairLocalState

/// A compact pair snapshot cached in the App Group shared container.
///
/// This is what the widget and background service read without
/// making a network request. It is kept in sync by the main app.
public struct PairLocalState: Codable, Sendable, Equatable {
    /// The pair's UUID (matches the drawing's pair_id in the database)
    public let pairID: UUID
    /// UUID of the partner user (nil while waiting for pairing)
    public let partnerID: UUID?
    /// Partner's display name for widget and notification display
    public let partnerName: String?
    /// The invite code (kept for UI display if partner hasn't joined)
    public let inviteCode: String
    /// When pairing was completed
    public let pairedAt: Date

    public init(
        pairID: UUID,
        partnerID: UUID?,
        partnerName: String?,
        inviteCode: String,
        pairedAt: Date = Date()
    ) {
        self.pairID = pairID
        self.partnerID = partnerID
        self.partnerName = partnerName
        self.inviteCode = inviteCode
        self.pairedAt = pairedAt
    }

    /// True when the pair has a second user
    public var isPaired: Bool { partnerID != nil }

    /// The display name to use for the partner, with fallback
    public var partnerDisplayName: String {
        partnerName ?? "Your Partner"
    }
}

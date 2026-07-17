import Foundation

// MARK: - AppUser

/// Represents a registered user of LoveWidget.
///
/// Named `AppUser` to avoid collision with Supabase's internal `User` type.
/// The `id` field mirrors `auth.uid()` from Supabase anonymous auth.
public struct AppUser: Codable, Sendable, Equatable, Identifiable, Hashable {
    /// Matches Supabase auth.uid() — used in RLS policies
    public let id: UUID
    /// User's chosen display name
    public let name: String
    /// Stable hardware device identifier (from IOKit UUID)
    public let deviceID: String
    /// When this user record was first created
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        deviceID: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deviceID = deviceID
        self.createdAt = createdAt
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case deviceID  = "device_id"
        case createdAt = "created_at"
    }
}

// MARK: - AppUserSettings

/// User preferences and session identifiers persisted locally in the App Group.
///
/// These settings are stored in the shared container so both the main app
/// and the background sync service can access them.
public struct AppUserSettings: Codable, Sendable, Equatable {
    /// User's chosen display name (may differ from AppUser.name after rename)
    public var displayName: String
    /// Enables notification when partner updates the drawing
    public var notificationsEnabled: Bool
    /// App should launch automatically at login
    public var launchAtLogin: Bool
    /// Force dark color scheme regardless of system setting
    public var prefersDarkMode: Bool
    /// UUID of this device's Supabase user record
    public var userID: UUID?
    /// Preferred brush width
    public var defaultBrushWidth: Double
    /// Preferred stroke color
    public var defaultColor: StrokeColor

    public init(
        displayName: String = "",
        notificationsEnabled: Bool = true,
        launchAtLogin: Bool = false,
        prefersDarkMode: Bool = false,
        userID: UUID? = nil,
        defaultBrushWidth: Double = 3.0,
        defaultColor: StrokeColor = .crimson
    ) {
        self.displayName = displayName
        self.notificationsEnabled = notificationsEnabled
        self.launchAtLogin = launchAtLogin
        self.prefersDarkMode = prefersDarkMode
        self.userID = userID
        self.defaultBrushWidth = defaultBrushWidth
        self.defaultColor = defaultColor
    }

    /// True when the user has completed onboarding (has a display name)
    public var isOnboardingComplete: Bool {
        !displayName.isEmpty && userID != nil
    }
}

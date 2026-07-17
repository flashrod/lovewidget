import Testing
import Foundation
@testable import LoveWidgetCore

@Suite("User Model")
struct UserModelTests {

    let userID = UUID()
    let deviceID = "ABC-123"

    @Test("AppUser creation")
    func appUserCreation() {
        let user = AppUser(id: userID, name: "Alice", deviceID: deviceID)
        #expect(user.id == userID)
        #expect(user.name == "Alice")
        #expect(user.deviceID == deviceID)
    }

    @Test("AppUser name trimming")
    func appUserNameTrimming() {
        let user = AppUser(name: "  Bob  ", deviceID: deviceID)
        #expect(user.name == "Bob")
    }

    @Test("AppUser Codable round-trip")
    func appUserCodable() throws {
        let user = AppUser(id: userID, name: "Alice", deviceID: deviceID)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(user)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppUser.self, from: data)

        #expect(decoded.id == userID)
        #expect(decoded.name == "Alice")
        #expect(decoded.deviceID == deviceID)
    }

    // MARK: - AppUserSettings

    @Test("Settings defaults")
    func settingsDefaults() {
        let settings = AppUserSettings()
        #expect(settings.displayName.isEmpty)
        #expect(settings.notificationsEnabled == true)
        #expect(settings.launchAtLogin == false)
        #expect(settings.prefersDarkMode == false)
        #expect(settings.userID == nil)
        #expect(settings.defaultBrushWidth == 3.0)
        #expect(settings.defaultColor == .crimson)
    }

    @Test("Settings onboarding check")
    func settingsOnboarding() {
        let incomplete = AppUserSettings(displayName: "", userID: nil)
        #expect(!incomplete.isOnboardingComplete)

        let complete = AppUserSettings(displayName: "Alice", userID: UUID())
        #expect(complete.isOnboardingComplete)
    }

    @Test("Settings Codable round-trip")
    func settingsCodable() throws {
        let settings = AppUserSettings(
            displayName: "Alice",
            notificationsEnabled: false,
            launchAtLogin: true,
            prefersDarkMode: true,
            userID: userID,
            defaultBrushWidth: 8.0,
            defaultColor: .sapphire
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppUserSettings.self, from: data)

        #expect(decoded.displayName == "Alice")
        #expect(decoded.notificationsEnabled == false)
        #expect(decoded.launchAtLogin == true)
        #expect(decoded.defaultBrushWidth == 8.0)
        #expect(decoded.defaultColor == .sapphire)
    }
}

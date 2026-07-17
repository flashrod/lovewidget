import Foundation
import IOKit

// MARK: - DeviceIdentifier

/// Provides a stable, persistent identifier for this Mac.
///
/// **Strategy:**
/// 1. Attempt to read the IOKit hardware UUID (`IOPlatformUUID`).
///    This is stable across app installs and user accounts on the same Mac.
/// 2. If IOKit is unavailable (sandboxing restrictions), fall back to a
///    generated UUID stored in `UserDefaults.standard`.
///
/// This identifier is stored in the `users` table in Supabase, allowing
/// the app to recognize a returning device after reinstallation.
public struct DeviceIdentifier: Sendable {

    // MARK: - Public API

    /// The stable identifier for this device. Thread-safe.
    public static let current: String = {
        if let hwUUID = hardwareUUID() {
            return hwUUID
        }
        return fallbackUUID()
    }()

    // MARK: - Private Implementations

    /// Read the hardware UUID from IOKit's platform expert service.
    private static func hardwareUUID() -> String? {
        let matchingDict = IOServiceMatching("IOPlatformExpertDevice")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict)
        defer { IOObjectRelease(service) }

        guard service != IO_OBJECT_NULL else { return nil }

        let cfValue = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )

        return cfValue?.takeRetainedValue() as? String
    }

    /// Generate or retrieve a UUID stored in UserDefaults.
    /// This is a fallback when IOKit is unavailable (rare in macOS apps).
    private static func fallbackUUID() -> String {
        let key = "com.lovewidget.deviceID.fallback"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

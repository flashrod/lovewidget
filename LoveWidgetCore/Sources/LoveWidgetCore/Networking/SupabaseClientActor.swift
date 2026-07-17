import Foundation
import Supabase
import Auth

// MARK: - UserDefaults Auth Storage

/// Stores Supabase auth sessions in `UserDefaults` instead of the keychain.
///
/// This avoids the macOS sandbox keychain prompt
/// ("LoveWidget wants to use your confidential info stored in SupabaseGotrue").
final class UserDefaultsAuthStorage: @unchecked Sendable, AuthLocalStorage {
    private let defaults = UserDefaults.standard
    private let prefix = "com.lovewidget.auth."

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: prefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: prefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: prefix + key)
    }
}

// MARK: - SupabaseConfigurationError

public enum SupabaseConfigurationError: Error, LocalizedError, Sendable {
    case missingURL
    case invalidURL(String)
    case missingAnonKey
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .missingURL:
            return "SUPABASE_URL is not set. Copy Config.xcconfig.template → Config.xcconfig and fill in your values."
        case .invalidURL(let raw):
            return "SUPABASE_URL '\(raw)' is not a valid URL."
        case .missingAnonKey:
            return "SUPABASE_ANON_KEY is not set. Copy Config.xcconfig.template → Config.xcconfig and fill in your values."
        case .notConfigured:
            return "SupabaseClientActor has not been configured. Call configure(with:) before use."
        }
    }
}

// MARK: - SupabaseConfiguration

/// Supabase connection parameters loaded from Info.plist at runtime.
///
/// Values come from `Config.xcconfig` via the build settings → Info.plist injection pipeline:
/// 1. `Config.xcconfig` sets `SUPABASE_URL` and `SUPABASE_ANON_KEY`
/// 2. `project.yml` maps those to `XCCONFIG_FILE` for the target
/// 3. `App/Info.plist` reads `$(SUPABASE_URL)` and `$(SUPABASE_ANON_KEY)`
/// 4. This struct reads from `Bundle.main.infoDictionary`
public struct SupabaseConfiguration: Sendable {
    public let url: URL
    public let anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }

    /// Load from the main bundle's Info.plist.
    public static func fromMainBundle() throws -> SupabaseConfiguration {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty else {
            throw SupabaseConfigurationError.missingURL
        }
        guard let url = URL(string: urlString) else {
            throw SupabaseConfigurationError.invalidURL(urlString)
        }
        guard let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !anonKey.isEmpty else {
            throw SupabaseConfigurationError.missingAnonKey
        }
        return SupabaseConfiguration(url: url, anonKey: anonKey)
    }
}

// MARK: - SupabaseClientActor

/// Thread-safe actor wrapping the Supabase Swift SDK client.
///
/// This is the single point of entry for all Supabase operations.
/// Repositories receive an instance via dependency injection (not via a global singleton).
///
/// **Authentication strategy:**
/// LoveWidget uses Supabase anonymous auth. Each device signs in once anonymously,
/// obtains a stable `auth.uid()`, and links it to the `users` table.
/// The anon JWT is automatically refreshed by the SDK.
public actor SupabaseClientActor {

    // MARK: - Properties

    private let client: SupabaseClient
    private let logger = LWLogger.network

    // MARK: - Initialization

    public init(configuration: SupabaseConfiguration) {
        self.client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    storage: UserDefaultsAuthStorage()
                )
            )
        )
        logger.info("SupabaseClient initialized for \(configuration.url.host ?? "unknown")")
    }

    // MARK: - Client Access

    /// The underlying SDK client. Provided to repositories for query building.
    public var supabase: SupabaseClient { client }

    // MARK: - Authentication

    /// Sign in anonymously. Safe to call multiple times (no-ops if already signed in).
    public func ensureAuthenticated() async throws {
        do {
            _ = try await client.auth.session
            logger.debug("Session already active.")
        } catch {
            logger.info("No active session. Signing in anonymously…")
            try await client.auth.signInAnonymously()
            logger.info("Anonymous sign-in successful.")
        }
    }

    /// The currently authenticated user's UUID, or nil if not signed in.
    public var authenticatedUserID: UUID? {
        get async {
            try? await client.auth.session.user.id
        }
    }

    /// Sign out and clear the session.
    public func signOut() async throws {
        try await client.auth.signOut()
        logger.info("Signed out.")
    }
}

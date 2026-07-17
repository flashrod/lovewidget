import Foundation

// MARK: - StorageKeys

/// All constants related to App Group shared container storage.
///
/// The App Group identifier `group.com.lovewidget.app` must match
/// exactly what is configured in both targets' entitlements files.
public enum StorageKeys {

    // MARK: - App Group

    /// The shared container identifier. Both the main app and
    /// the widget extension must declare this in their entitlements.
    public static let appGroupIdentifier = "group.com.lovewidget.app"

    // MARK: - File Names

    /// The current shared drawing canvas
    public static let drawingFile        = "drawing.json"
    /// User preferences and session info
    public static let settingsFile       = "settings.json"
    /// Active pair information
    public static let pairFile           = "pair.json"
    /// History of sent and received drawings
    public static let historyFile        = "drawing_history.json"
    /// A failed upload queued for retry
    public static let pendingUploadFile  = "pending_upload.json"
    /// Rotating application log file
    public static let logsFile           = "logs.txt"
    /// Old log file after rotation
    public static let logsRotatedFile    = "logs_old.txt"

    // MARK: - UserDefaults

    /// Returns a UserDefaults instance, preferring the App Group suite
    /// (for widget sharing) but falling back to standard when ad-hoc
    /// signing prevents App Group access.
    public static func userDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// ISO8601 string of the last successful sync timestamp
    public static let lastSyncTimestampKey = "lw.lastSyncTimestamp"
    /// Bool: whether the widget needs a timeline refresh
    public static let widgetNeedsRefreshKey = "lw.widgetNeedsRefresh"

    // MARK: - Limits

    /// Maximum log file size before rotation (1 MB)
    public static let maxLogFileSizeBytes = 1_000_000
}

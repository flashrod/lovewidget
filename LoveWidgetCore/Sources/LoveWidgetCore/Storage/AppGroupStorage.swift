import Foundation

// MARK: - AppGroupStorageError

/// Errors thrown by `AppGroupStorage`.
public enum AppGroupStorageError: Error, LocalizedError, Sendable {
    case containerNotFound(groupIdentifier: String)
    case encodingFailed(Error)
    case writeFailed(Error)
    case readFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .containerNotFound(let id):
            return "Container not found for '\(id)'."
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Write failed: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Read failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - AppGroupStorage

/// Thread-safe, actor-based read/write access to the App Group shared container.
///
/// Both the main app and the WidgetKit extension read from this storage.
/// Writes are atomic (using `.atomic` flag) to prevent data corruption if the
/// process is terminated mid-write.
///
/// All public methods are `nonisolated throws` so callers outside the actor
/// can perform synchronous access when the actor is not yet running (e.g., during
/// WidgetKit timeline entry generation, which is not async).
public final class AppGroupStorage: @unchecked Sendable {

    // MARK: - Properties

    private let groupIdentifier: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    /// The resolved container directory URL (App Group or sandbox fallback).
    public private(set) var containerURL: URL

    // MARK: - Shared Instance

    /// The shared storage instance using the default App Group identifier.
    public static let shared = AppGroupStorage()

    // MARK: - Initialization

    public init(groupIdentifier: String = StorageKeys.appGroupIdentifier) {
        self.groupIdentifier = groupIdentifier

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        self.containerURL = Self.resolveContainer(groupIdentifier: groupIdentifier)
    }

    // MARK: - Container

    /// Resolve the storage container URL once at init.
    /// Tries the App Group container first; if it's not accessible
    /// (ad-hoc signing, sandbox restrictions), falls back to the
    /// app's sandbox Application Support / LoveWidget directory.
    private static func resolveContainer(groupIdentifier: String) -> URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if exists, isDir.boolValue {
                LWLogger.storage.info("Using App Group container: \(url.path)")
                return url
            }
            LWLogger.storage.info("App Group container URL resolved but not accessible on disk — falling back.")
        }
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        // Use the standard directory for the real app, or derive from identifier
        // for isolated instances (e.g. tests with unique identifiers).
        let dirName: String
        if groupIdentifier == StorageKeys.appGroupIdentifier {
            dirName = "LoveWidget"
        } else {
            // Use a hash of the identifier to create unique per-instance directories
            let suffix = abs(groupIdentifier.hashValue)
            dirName = "LoveWidget-\(suffix)"
        }
        let url = appSupport.appendingPathComponent(dirName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        LWLogger.storage.info("Using app sandbox container: \(url.path)")
        return url
    }

    private func fileURL(for name: String) -> URL {
        containerURL.appendingPathComponent(name)
    }

    // MARK: - Generic Read / Write

    /// Encode and atomically write a Codable value to the named file.
    public func write<T: Codable & Sendable>(_ value: T, to fileName: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: fileName)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch let error as AppGroupStorageError {
            throw error
        } catch {
            if error is EncodingError {
                throw AppGroupStorageError.encodingFailed(error)
            }
            throw AppGroupStorageError.writeFailed(error)
        }
    }

    /// Read and decode a Codable value from the named file.
    /// Returns `nil` if the file does not exist or is corrupted.
    public func read<T: Codable & Sendable>(_ type: T.Type, from fileName: String) throws -> T? {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch is DecodingError {
            LWLogger.storage.warning("Corrupted file '\(fileName)' — ignoring.")
            return nil
        } catch {
            throw AppGroupStorageError.readFailed(error)
        }
    }

    /// Delete the named file if it exists.
    public func delete(fileName: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Drawing

    /// Load the current shared drawing, returning `.empty` if none is saved.
    public func loadDrawing() throws -> Drawing {
        try read(Drawing.self, from: StorageKeys.drawingFile) ?? .empty
    }

    /// Atomically persist the current shared drawing.
    public func saveDrawing(_ drawing: Drawing) throws {
        try write(drawing, to: StorageKeys.drawingFile)
    }

    // MARK: - Settings

    /// Load user settings, returning defaults if none are saved.
    public func loadSettings() throws -> AppUserSettings {
        try read(AppUserSettings.self, from: StorageKeys.settingsFile) ?? AppUserSettings()
    }

    /// Persist user settings.
    public func saveSettings(_ settings: AppUserSettings) throws {
        try write(settings, to: StorageKeys.settingsFile)
    }

    // MARK: - Pair

    /// Load the local pair state. Returns `nil` if the user is not paired.
    public func loadPair() throws -> PairLocalState? {
        try read(PairLocalState.self, from: StorageKeys.pairFile)
    }

    /// Persist the local pair state.
    public func savePair(_ pair: PairLocalState) throws {
        try write(pair, to: StorageKeys.pairFile)
    }

    /// Remove all pair state (called on "Reset Pair").
    public func clearPair() throws {
        try delete(fileName: StorageKeys.pairFile)
    }

    // MARK: - History

    /// Load all drawing history entries.
    public func loadHistory() throws -> [Drawing.Entry] {
        try read([Drawing.Entry].self, from: StorageKeys.historyFile) ?? []
    }

    /// Append a new entry to the drawing history.
    public func appendHistory(_ entry: Drawing.Entry) throws {
        var history = try loadHistory()
        history.append(entry)
        // Keep max 100 entries to avoid unbounded growth
        if history.count > 100 {
            history = Array(history.suffix(100))
        }
        try write(history, to: StorageKeys.historyFile)
    }

    /// Clear all drawing history.
    public func clearHistory() throws {
        try delete(fileName: StorageKeys.historyFile)
    }

    // MARK: - Pending Upload

    /// Load any failed upload queued for retry.
    public func loadPendingUpload() throws -> PendingUpload? {
        try read(PendingUpload.self, from: StorageKeys.pendingUploadFile)
    }

    /// Persist a failed upload for later retry.
    public func savePendingUpload(_ upload: PendingUpload) throws {
        try write(upload, to: StorageKeys.pendingUploadFile)
    }

    /// Remove the pending upload after it has been successfully retried.
    public func clearPendingUpload() throws {
        try delete(fileName: StorageKeys.pendingUploadFile)
    }

    // MARK: - Logs

    /// Append a timestamped message to the rotating log file.
    ///
    /// When the log exceeds `StorageKeys.maxLogFileSizeBytes`, the current
    /// log is renamed to `logs_old.txt` and a fresh log is started.
    public func appendLog(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: StorageKeys.logsFile)
        let formatted = "[\(Date().formatted(.iso8601))] \(message)\n"
        guard let data = formatted.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: url.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int,
           size > StorageKeys.maxLogFileSizeBytes {
            let rotated = fileURL(for: StorageKeys.logsRotatedFile)
            _ = try? FileManager.default.replaceItemAt(rotated, withItemAt: url)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Read the full log file as a string.
    public func readLogs() -> String {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: StorageKeys.logsFile)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return "(no logs)"
        }
        return text
    }
}

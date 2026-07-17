import Testing
import Foundation
@testable import LoveWidgetCore

@Suite("App Group Storage")
final class AppGroupStorageTests {

    let storage: AppGroupStorage

    init() {
        storage = AppGroupStorage(
            groupIdentifier: "group.com.lovewidget.test.\(UUID().uuidString)"
        )
    }

    // MARK: - Container Resolution

    @Test("Container URL resolves to fallback for unknown App Group")
    func containerURLUsesFallback() {
        let url = storage.containerURL
        #expect(url.path.contains("LoveWidget"))
        #expect(!url.path.contains("Group Containers"))
    }

    @Test("Container URL directory exists after init")
    func containerDirectoryExists() {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: storage.containerURL.path, isDirectory: &isDir)
        #expect(exists)
        #expect(isDir.boolValue)
    }

    // MARK: - Generic Read/Write

    @Test("Write then read a simple value")
    func writeReadRoundTrip() throws {
        let value = ["hello", "world"]
        try storage.write(value, to: "test_strings.json")
        let loaded: [String]? = try storage.read([String].self, from: "test_strings.json")
        #expect(loaded == value)
    }

    @Test("Read non-existent file returns nil")
    func readNonExistentReturnsNil() throws {
        let result: String? = try storage.read(String.self, from: "nonexistent.json")
        #expect(result == nil)
    }

    @Test("Write then delete then read returns nil")
    func writeDeleteRead() throws {
        try storage.write("data", to: "delete_me.json")
        try storage.delete(fileName: "delete_me.json")
        let result: String? = try storage.read(String.self, from: "delete_me.json")
        #expect(result == nil)
    }

    @Test("Delete non-existent file does not throw")
    func deleteNonExistent() throws {
        try storage.delete(fileName: "does_not_exist.json")
    }

    @Test("Overwrite existing file")
    func overwriteFile() throws {
        try storage.write("first", to: "overwrite.json")
        try storage.write("second", to: "overwrite.json")
        let loaded: String? = try storage.read(String.self, from: "overwrite.json")
        #expect(loaded == "second")
    }

    // MARK: - Drawing

    @Test("Save and load drawing")
    func saveLoadDrawing() throws {
        let drawing = Drawing.empty
        try storage.saveDrawing(drawing)
        let loaded = try storage.loadDrawing()
        #expect(loaded.strokes.isEmpty)
        #expect(loaded.version == 0)
    }

    @Test("Load drawing when none saved returns empty")
    func loadDrawingDefaultsToEmpty() throws {
        try storage.delete(fileName: StorageKeys.drawingFile)
        let loaded = try storage.loadDrawing()
        #expect(loaded.strokes.isEmpty)
        #expect(loaded.version == 0)
    }

    @Test("Save drawing with strokes round-trips correctly")
    func saveDrawingWithStrokes() throws {
        let point = DrawingPoint(x: 1, y: 2, pressure: 0.5)
        let stroke = Stroke(
            color: StrokeColor(red: 1, green: 0, blue: 0),
            width: 3, opacity: 1,
            points: [point],
            authorID: UUID()
        )
        let drawing = Drawing.empty.appending(stroke)
        try storage.saveDrawing(drawing)
        let loaded = try storage.loadDrawing()
        #expect(loaded.strokes.count == 1)
        #expect(loaded.version == drawing.version)
    }

    // MARK: - Settings

    @Test("Save and load settings")
    func saveLoadSettings() throws {
        let settings = AppUserSettings(
            displayName: "TestUser",
            notificationsEnabled: false,
            launchAtLogin: true,
            prefersDarkMode: true,
            userID: UUID(),
            defaultBrushWidth: 5.0,
            defaultColor: .sapphire
        )
        try storage.saveSettings(settings)
        let loaded = try storage.loadSettings()
        #expect(loaded.displayName == "TestUser")
        #expect(loaded.notificationsEnabled == false)
        #expect(loaded.launchAtLogin == true)
        #expect(loaded.prefersDarkMode == true)
        #expect(loaded.defaultBrushWidth == 5.0)
        #expect(loaded.defaultColor == .sapphire)
    }

    @Test("Load settings when none saved returns defaults")
    func loadSettingsDefaults() throws {
        try storage.delete(fileName: StorageKeys.settingsFile)
        let loaded = try storage.loadSettings()
        #expect(loaded.displayName.isEmpty)
        #expect(loaded.notificationsEnabled == true)
        #expect(loaded.launchAtLogin == false)
        #expect(loaded.prefersDarkMode == false)
    }

    // MARK: - Pair

    @Test("Save and load pair state")
    func saveLoadPair() throws {
        let pair = PairLocalState(
            pairID: UUID(),
            partnerID: UUID(),
            partnerName: "Partner",
            inviteCode: "ABC-1234"
        )
        try storage.savePair(pair)
        let loaded = try storage.loadPair()
        #expect(loaded?.pairID == pair.pairID)
        #expect(loaded?.partnerID == pair.partnerID)
        #expect(loaded?.partnerDisplayName == "Partner")
        #expect(loaded?.inviteCode == "ABC-1234")
        #expect(loaded?.isPaired == true)
    }

    @Test("Save unpaired state correctly")
    func saveUnpairedState() throws {
        let pair = PairLocalState(
            pairID: UUID(),
            partnerID: nil,
            partnerName: nil,
            inviteCode: "ABC-1234"
        )
        try storage.savePair(pair)
        let loaded = try storage.loadPair()
        #expect(loaded?.isPaired == false)
        #expect(loaded?.partnerID == nil)
    }

    @Test("Clear pair after save returns nil")
    func clearPair() throws {
        let pair = PairLocalState(
            pairID: UUID(),
            partnerID: nil,
            partnerName: nil,
            inviteCode: "ABC-1234"
        )
        try storage.savePair(pair)
        try storage.clearPair()
        let loaded = try storage.loadPair()
        #expect(loaded == nil)
    }

    @Test("Clear pair when none saved does not throw")
    func clearPairNoneSaved() throws {
        try storage.delete(fileName: StorageKeys.pairFile)
        try storage.clearPair()
    }

    // MARK: - History

    @Test("Append and load history")
    func appendLoadHistory() throws {
        try storage.delete(fileName: StorageKeys.historyFile)
        let entry = Drawing.Entry(
            drawing: .empty,
            authorName: "Me",
            type: .sent
        )
        try storage.appendHistory(entry)
        let history = try storage.loadHistory()
        #expect(history.count == 1)
        #expect(history[0].authorName == "Me")
        #expect(history[0].type == .sent)
    }

    @Test("Append multiple history entries")
    func appendMultipleHistory() throws {
        try storage.delete(fileName: StorageKeys.historyFile)
        for _ in 0..<5 {
            try storage.appendHistory(
                Drawing.Entry(drawing: .empty, authorName: "A", type: .sent)
            )
        }
        let history = try storage.loadHistory()
        #expect(history.count == 5)
    }

    @Test("History caps at 100 entries")
    func historyCapsAt100() throws {
        try storage.delete(fileName: StorageKeys.historyFile)
        for i in 0..<101 {
            try storage.appendHistory(
                Drawing.Entry(drawing: .empty, authorName: "\(i)", type: .sent)
            )
        }
        let history = try storage.loadHistory()
        #expect(history.count == 100)
    }

    @Test("Clear history")
    func clearHistory() throws {
        try storage.appendHistory(
            Drawing.Entry(drawing: .empty, authorName: "A", type: .sent)
        )
        try storage.clearHistory()
        let history = try storage.loadHistory()
        #expect(history.isEmpty)
    }

    // MARK: - Pending Upload

    @Test("Save and load pending upload")
    func saveLoadPendingUpload() throws {
        let upload = PendingUpload(
            drawing: .empty,
            pairID: UUID(),
            userID: UUID()
        )
        try storage.savePendingUpload(upload)
        let loaded = try storage.loadPendingUpload()
        #expect(loaded?.pairID == upload.pairID)
        #expect(loaded?.userID == upload.userID)
        #expect(loaded?.attemptCount == 0)
    }

    @Test("Clear pending upload")
    func clearPendingUpload() throws {
        let upload = PendingUpload(
            drawing: .empty,
            pairID: UUID(),
            userID: UUID()
        )
        try storage.savePendingUpload(upload)
        try storage.clearPendingUpload()
        let loaded = try storage.loadPendingUpload()
        #expect(loaded == nil)
    }

    @Test("Pending upload increments attempt")
    func pendingUploadIncrement() throws {
        let upload = PendingUpload(
            drawing: .empty,
            pairID: UUID(),
            userID: UUID()
        )
        let incremented = upload.incrementingAttempt()
        #expect(incremented.attemptCount == 1)
        #expect(incremented.drawing.version == upload.drawing.version)
        #expect(incremented.pairID == upload.pairID)
        #expect(incremented.userID == upload.userID)
    }

    @Test("Pending upload max attempts")
    func pendingUploadMaxAttempts() throws {
        #expect(PendingUpload.maximumAttempts == 10)
    }

    // MARK: - Logs

    @Test("Append and read logs")
    func appendReadLogs() throws {
        try storage.delete(fileName: StorageKeys.logsFile)
        storage.appendLog("Test message")
        let logs = storage.readLogs()
        #expect(logs.contains("Test message"))
        #expect(logs != "(no logs)")
    }

    @Test("Read logs when empty")
    func readLogsEmpty() throws {
        try storage.delete(fileName: StorageKeys.logsFile)
        let logs = storage.readLogs()
        #expect(logs == "(no logs)")
    }

    @Test("Append multiple log lines")
    func appendMultipleLogs() throws {
        try storage.delete(fileName: StorageKeys.logsFile)
        storage.appendLog("line1")
        storage.appendLog("line2")
        let logs = storage.readLogs()
        #expect(logs.contains("line1"))
        #expect(logs.contains("line2"))
    }

    // MARK: - Error Cases

    @Test("Write with encoding failure produces encodingFailed error")
    func writeEncodingFailure() throws {
        // A struct that can't be encoded should produce .encodingFailed
        // We test this by checking the error type from write
        do {
            try storage.write(UnencodableStruct(), to: "fail.json")
            #expect(Bool(false), "Expected throw")
        } catch let error as AppGroupStorageError {
            if case .encodingFailed = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected encodingFailed, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected AppGroupStorageError")
        }
    }
}

/// Helper: a struct that intentionally fails encoding
private struct UnencodableStruct: Codable, Sendable {
    init() {}
    func encode(to encoder: any Encoder) throws {
        throw EncodingError.invalidValue(self, .init(
            codingPath: [], debugDescription: "intentional failure"
        ))
    }
    init(from decoder: any Decoder) throws {
        throw DecodingError.dataCorrupted(.init(
            codingPath: [], debugDescription: "intentional failure"
        ))
    }
}

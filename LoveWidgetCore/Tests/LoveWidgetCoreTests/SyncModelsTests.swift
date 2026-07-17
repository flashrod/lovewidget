import Testing
import Foundation
@testable import LoveWidgetCore

@Suite("Sync Models")
struct SyncModelsTests {

    let color = StrokeColor(red: 0, green: 0, blue: 0)
    let authorID = UUID()

    private func makeStroke(x: Double, y: Double) -> Stroke {
        Stroke(
            color: color,
            width: 2,
            points: [DrawingPoint(x: x, y: y)],
            authorID: authorID
        )
    }

    // MARK: - StrokeDelta

    @Test("Delta from empty is empty")
    func deltaFromEmpty() {
        let delta = StrokeDelta.compute(from: .empty, to: .empty)
        #expect(delta.isEmpty)
    }

    @Test("Delta detects additions")
    func deltaAdditions() {
        let s1 = makeStroke(x: 10, y: 20)
        let old = Drawing.empty
        let new = Drawing(strokes: [s1], version: 1)
        let delta = StrokeDelta.compute(from: old, to: new)
        #expect(delta.added.count == 1)
        #expect(delta.added.first!.id == s1.id)
        #expect(delta.removed.isEmpty)
        #expect(delta.resultingVersion == 1)
    }

    @Test("Delta detects removals")
    func deltaRemovals() {
        let s1 = makeStroke(x: 10, y: 20)
        let old = Drawing(strokes: [s1], version: 1)
        let new = Drawing.empty
        let delta = StrokeDelta.compute(from: old, to: new)
        #expect(delta.added.isEmpty)
        #expect(delta.removed.count == 1)
        #expect(delta.removed.first == s1.id)
    }

    @Test("Delta detects additions and removals")
    func deltaBoth() {
        let s1 = makeStroke(x: 10, y: 20)
        let s2 = makeStroke(x: 30, y: 40)
        let s3 = makeStroke(x: 50, y: 60)
        let old = Drawing(strokes: [s1, s2], version: 1)
        let new = Drawing(strokes: [s2, s3], version: 2)
        let delta = StrokeDelta.compute(from: old, to: new)
        #expect(delta.added.count == 1)
        #expect(delta.added.first!.id == s3.id)
        #expect(delta.removed.count == 1)
        #expect(delta.removed.first == s1.id)
    }

    @Test("Delta applying to empty drawing")
    func deltaApplyToEmpty() {
        let s1 = makeStroke(x: 10, y: 20)
        let delta = StrokeDelta(added: [s1], removed: [], resultingVersion: 1)
        let result = delta.applying(to: .empty)
        #expect(result.strokes.count == 1)
        #expect(result.version == 1)
    }

    @Test("Delta applying skips strokes already in drawing")
    func deltaApplyDeduplicates() {
        let s1 = makeStroke(x: 10, y: 20)
        let existing = Drawing(strokes: [s1], version: 0)
        let delta = StrokeDelta(added: [s1], removed: [], resultingVersion: 1)
        let result = delta.applying(to: existing)
        #expect(result.strokes.count == 1)
    }

    @Test("Delta applying removes strokes")
    func deltaApplyRemoves() {
        let s1 = makeStroke(x: 10, y: 20)
        let drawing = Drawing(strokes: [s1], version: 0)
        let delta = StrokeDelta(added: [], removed: [s1.id], resultingVersion: 1)
        let result = delta.applying(to: drawing)
        #expect(result.strokes.isEmpty)
    }

    @Test("Delta Codable round-trip")
    func deltaCodable() throws {
        let s1 = makeStroke(x: 10, y: 20)
        let delta = StrokeDelta(added: [s1], removed: [], resultingVersion: 3)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(delta)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(StrokeDelta.self, from: data)

        #expect(decoded.added.count == 1)
        #expect(decoded.resultingVersion == 3)
    }

    // MARK: - SyncEvent

    @Test("SyncEvent creation")
    func syncEventCreation() {
        let delta = StrokeDelta(added: [], removed: [], resultingVersion: 1)
        let event = SyncEvent(pairID: UUID(), delta: delta, createdBy: authorID)
        #expect(event.pairID != UUID())
        #expect(event.delta.resultingVersion == 1)
        #expect(event.createdBy == authorID)
    }

    @Test("SyncEvent Codable round-trip")
    func syncEventCodable() throws {
        let delta = StrokeDelta(added: [], removed: [], resultingVersion: 1)
        let event = SyncEvent(pairID: UUID(), delta: delta, createdBy: authorID)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SyncEvent.self, from: data)

        #expect(decoded.pairID == event.pairID)
        #expect(decoded.createdBy == authorID)
    }

    // MARK: - SyncStatus

    @Test("SyncStatus isLive")
    func syncStatusIsLive() {
        #expect(SyncStatus.connected.isLive == true)
        #expect(SyncStatus.syncing.isLive == true)
        #expect(SyncStatus.idle.isLive == false)
        #expect(SyncStatus.connecting.isLive == false)
        #expect(SyncStatus.disconnected(reason: "").isLive == false)
        #expect(SyncStatus.error(message: "").isLive == false)
    }

    @Test("SyncStatus descriptions")
    func syncStatusDescriptions() {
        #expect(SyncStatus.idle.description == "Idle")
        #expect(SyncStatus.connecting.description == "Connecting…")
        #expect(SyncStatus.connected.description == "Connected")
        #expect(SyncStatus.syncing.description == "Syncing…")
        #expect(SyncStatus.disconnected(reason: "timeout").description == "Disconnected: timeout")
        #expect(SyncStatus.error(message: "fail").description == "Error: fail")
    }

    @Test("SyncStatus systemImageName")
    func syncStatusSystemImage() {
        #expect(SyncStatus.connected.systemImageName == "wifi")
        #expect(SyncStatus.disconnected(reason: "").systemImageName == "wifi.slash")
        #expect(SyncStatus.error(message: "").systemImageName == "exclamationmark.triangle.fill")
    }

    @Test("SyncStatus Equatable")
    func syncStatusEquatable() {
        #expect(SyncStatus.disconnected(reason: "x") == SyncStatus.disconnected(reason: "x"))
        #expect(SyncStatus.disconnected(reason: "x") != SyncStatus.disconnected(reason: "y"))
    }

    // MARK: - PendingUpload

    @Test("PendingUpload increment attempt")
    func pendingUploadIncrement() {
        let upload = PendingUpload(drawing: .empty, pairID: UUID(), userID: authorID, attemptCount: 2)
        let incremented = upload.incrementingAttempt()
        #expect(incremented.attemptCount == 3)
        #expect(incremented.drawing == .empty)
    }

    @Test("PendingUpload maximum attempts")
    func pendingUploadMaxAttempts() {
        #expect(PendingUpload.maximumAttempts == 10)
    }
}

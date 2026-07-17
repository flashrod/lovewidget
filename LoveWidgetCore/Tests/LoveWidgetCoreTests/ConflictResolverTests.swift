import Testing
import Foundation
@testable import LoveWidgetCore

@Suite("Conflict Resolver")
struct ConflictResolverTests {

    let resolver = ConflictResolver()
    let color = StrokeColor(red: 0, green: 0, blue: 0)
    let authorA = UUID()
    let authorB = UUID()

    private func makeStroke(id: UUID? = nil, author: UUID, x: Double, y: Double) -> Stroke {
        let point = DrawingPoint(x: x, y: y)
        return Stroke(
            id: id ?? UUID(),
            color: color,
            width: 2,
            points: [point],
            createdAt: Date(),
            authorID: author
        )
    }

    private func makeStroke(id: UUID? = nil, author: UUID, x: Double, y: Double, at time: Date) -> Stroke {
        let point = DrawingPoint(x: x, y: y)
        return Stroke(
            id: id ?? UUID(),
            color: color,
            width: 2,
            points: [point],
            createdAt: time,
            authorID: author
        )
    }

    // MARK: - Edge Cases

    @Test("Both empty returns empty")
    func bothEmpty() async {
        let result = await resolver.merge(local: .empty, remote: .empty)
        #expect(result.strokes.isEmpty)
    }

    @Test("One side empty keeps other")
    func oneSideEmpty() async {
        let stroke = makeStroke(author: authorA, x: 10, y: 20)
        let local = Drawing(strokes: [stroke])
        let result = await resolver.merge(local: local, remote: .empty)
        #expect(result.strokes.count == 1)
        #expect(result.strokes.first?.id == stroke.id)
    }

    @Test("Identical drawings fast path")
    func identicalDrawings() async {
        let stroke = makeStroke(author: authorA, x: 10, y: 20)
        let drawing = Drawing(strokes: [stroke], version: 3)
        let result = await resolver.merge(local: drawing, remote: drawing)
        #expect(result == drawing)
    }

    // MARK: - Normal Merge

    @Test("Non-overlapping strokes are unioned")
    func nonOverlappingStrokes() async {
        let s1 = makeStroke(author: authorA, x: 10, y: 20)
        let s2 = makeStroke(author: authorB, x: 30, y: 40)
        let local = Drawing(strokes: [s1])
        let remote = Drawing(strokes: [s2])
        let result = await resolver.merge(local: local, remote: remote)
        #expect(result.strokes.count == 2)
    }

    @Test("Duplicate strokes keep newer")
    func duplicateStrokesNewerWins() async {
        let oldDate = Date(timeIntervalSince1970: 0)
        let newDate = Date(timeIntervalSince1970: 1000)
        let strokeID = UUID()

        let oldStroke = makeStroke(id: strokeID, author: authorA, x: 10, y: 20, at: oldDate)
        let newStroke = makeStroke(id: strokeID, author: authorB, x: 99, y: 99, at: newDate)

        let local = Drawing(strokes: [oldStroke])
        let remote = Drawing(strokes: [newStroke])

        let result = await resolver.merge(local: local, remote: remote)
        #expect(result.strokes.count == 1)
        #expect(result.strokes.first!.points.first!.x == 99)
    }

    @Test("Strokes only in remote are preserved")
    func remoteOnlyStrokes() async {
        let localStroke = makeStroke(author: authorA, x: 10, y: 20)
        let remoteStroke = makeStroke(author: authorB, x: 30, y: 40)
        let local = Drawing(strokes: [localStroke])
        let remote = Drawing(strokes: [remoteStroke])
        let result = await resolver.merge(local: local, remote: remote)
        #expect(result.strokes.contains { $0.id == localStroke.id })
        #expect(result.strokes.contains { $0.id == remoteStroke.id })
    }

    // MARK: - Version

    @Test("Merge bumps version when both have strokes")
    func versionBump() async {
        let s1 = makeStroke(author: authorA, x: 10, y: 20)
        let s2 = makeStroke(author: authorB, x: 30, y: 40)
        let local = Drawing(strokes: [s1], version: 3)
        let remote = Drawing(strokes: [s2], version: 5)
        let result = await resolver.merge(local: local, remote: remote)
        #expect(result.version == 6)
        #expect(result.strokes.count == 2)
    }

    @Test("Merge with empty remote bumps local version")
    func versionBumpEmptyRemote() async {
        let s1 = makeStroke(author: authorA, x: 10, y: 20)
        let local = Drawing(strokes: [s1], version: 3)
        let remote = Drawing(strokes: [], version: 5)
        let result = await resolver.merge(local: local, remote: remote)
        #expect(result.version == 4)
        #expect(result.strokes.count == 1)
    }

    @Test("Merge result is sorted by createdAt")
    func mergeResultSorted() async {
        let early = Date(timeIntervalSince1970: 100)
        let late  = Date(timeIntervalSince1970: 200)

        let earlyStroke = makeStroke(author: authorA, x: 10, y: 20, at: early)
        let lateStroke  = makeStroke(author: authorB, x: 30, y: 40, at: late)

        let local = Drawing(strokes: [lateStroke])
        let remote = Drawing(strokes: [earlyStroke])

        let result = await resolver.merge(local: local, remote: remote)
        #expect(result.strokes.count == 2)
        #expect(result.strokes[0].createdAt < result.strokes[1].createdAt)
    }
}

import Testing
import Foundation
@testable import LoveWidgetCore

// swiftlint:disable force_unwrapping

@Suite("Drawing Serialization")
struct DrawingSerializationTests {

    let testPoint = DrawingPoint(x: 10.0, y: 20.0, pressure: 0.5)
    let testColor = StrokeColor(red: 0.5, green: 0.2, blue: 0.8)
    let authorID = UUID()

    // MARK: - DrawingPoint

    @Test("DrawingPoint properties")
    func drawingPointProperties() {
        let point = testPoint
        #expect(point.x == 10.0)
        #expect(point.y == 20.0)
        #expect(point.pressure == 0.5)
    }

    @Test("DrawingPoint pressure clamping")
    func drawingPointPressureClamping() {
        let low = DrawingPoint(x: 0, y: 0, pressure: -0.5)
        #expect(low.pressure == 0)

        let high = DrawingPoint(x: 0, y: 0, pressure: 1.5)
        #expect(high.pressure == 1.0)
    }

    @Test("DrawingPoint CGPoint conversion")
    func drawingPointCGPoint() {
        let cg = testPoint.cgPoint
        #expect(cg.x == 10.0)
        #expect(cg.y == 20.0)
    }

    @Test("DrawingPoint Codable round-trip")
    func drawingPointCodable() throws {
        let data = try JSONEncoder().encode(testPoint)
        let decoded = try JSONDecoder().decode(DrawingPoint.self, from: data)
        #expect(decoded.x == testPoint.x)
        #expect(decoded.y == testPoint.y)
        #expect(decoded.pressure == testPoint.pressure)
    }

    @Test("DrawingPoint Equatable")
    func drawingPointEquatable() {
        let a = DrawingPoint(x: 1, y: 2)
        let b = DrawingPoint(x: 1, y: 2)
        #expect(a == b)
    }

    // MARK: - StrokeColor

    @Test("StrokeColor properties")
    func strokeColorProperties() {
        let color = testColor
        #expect(color.red == 0.5)
        #expect(color.green == 0.2)
        #expect(color.blue == 0.8)
        #expect(color.alpha == 1.0)
    }

    @Test("StrokeColor component clamping")
    func strokeColorClamping() {
        let clamped = StrokeColor(red: 2.0, green: -0.5, blue: 0.5, alpha: 2.0)
        #expect(clamped.red == 1.0)
        #expect(clamped.green == 0.0)
        #expect(clamped.alpha == 1.0)
    }

    @Test("StrokeColor hex conversion")
    func strokeColorHex() {
        let color = StrokeColor(red: 1.0, green: 0.5, blue: 0.0)
        #expect(color.hexString == "#FF8000")
    }

    @Test("StrokeColor hex initializer")
    func strokeColorHexInit() {
        let color = StrokeColor(hex: "#FF8000")!
        #expect(abs(color.red - 1.0) < 0.01)
        #expect(abs(color.green - 0.502) < 0.01)
        #expect(abs(color.blue - 0.0) < 0.01)
    }

    @Test("StrokeColor hex init without hash")
    func strokeColorHexInitNoHash() {
        let color = StrokeColor(hex: "FF8000")!
        #expect(abs(color.red - 1.0) < 0.01)
    }

    @Test("StrokeColor hex init invalid returns nil")
    func strokeColorHexInvalid() {
        #expect(StrokeColor(hex: "XYZ") == nil)
        #expect(StrokeColor(hex: "#FF") == nil)
        #expect(StrokeColor(hex: "") == nil)
    }

    @Test("StrokeColor withAlpha")
    func strokeColorWithAlpha() {
        let semi = testColor.withAlpha(0.5)
        #expect(semi.alpha == 0.5)
        #expect(semi.red == testColor.red)
    }

    @Test("StrokeColor presets count")
    func strokeColorPresets() {
        #expect(StrokeColor.presets.count == 10)
    }

    @Test("StrokeColor Codable round-trip")
    func strokeColorCodable() throws {
        let data = try JSONEncoder().encode(testColor)
        let decoded = try JSONDecoder().decode(StrokeColor.self, from: data)
        #expect(decoded == testColor)
    }

    // MARK: - Stroke

    @Test("Stroke creation")
    func strokeCreation() {
        let stroke = Stroke(
            color: testColor,
            width: 5.0,
            opacity: 0.8,
            points: [testPoint],
            authorID: authorID
        )
        #expect(stroke.color == testColor)
        #expect(stroke.width == 5.0)
        #expect(stroke.opacity == 0.8)
        #expect(stroke.points.count == 1)
        #expect(stroke.authorID == authorID)
    }

    @Test("Stroke width clamping")
    func strokeWidthClamping() {
        let thin = Stroke(color: testColor, width: 0.1, points: [], authorID: authorID)
        #expect(thin.width == 0.5)

        let thick = Stroke(color: testColor, width: 100, points: [], authorID: authorID)
        #expect(thick.width == 64.0)
    }

    @Test("Stroke opacity clamping")
    func strokeOpacityClamping() {
        let low = Stroke(color: testColor, width: 2, opacity: 0, points: [], authorID: authorID)
        #expect(low.opacity == 0.01)

        let high = Stroke(color: testColor, width: 2, opacity: 2, points: [], authorID: authorID)
        #expect(high.opacity == 1.0)
    }

    @Test("Stroke bounding box empty")
    func strokeBoundingBoxEmpty() {
        let stroke = Stroke(color: testColor, width: 2, points: [], authorID: authorID)
        #expect(stroke.boundingBox == .zero)
    }

    @Test("Stroke bounding box")
    func strokeBoundingBox() {
        let points = [
            DrawingPoint(x: 10, y: 20),
            DrawingPoint(x: 100, y: 200),
            DrawingPoint(x: 50, y: 60),
        ]
        let stroke = Stroke(color: testColor, width: 2, points: points, authorID: authorID)
        #expect(stroke.boundingBox.origin.x == 10)
        #expect(stroke.boundingBox.origin.y == 20)
        #expect(stroke.boundingBox.width == 90)
        #expect(stroke.boundingBox.height == 180)
    }

    @Test("Stroke appending point")
    func strokeAppendingPoint() {
        let stroke = Stroke(color: testColor, width: 2, points: [testPoint], authorID: authorID)
        let newPoint = DrawingPoint(x: 30, y: 40)
        let extended = stroke.appending(point: newPoint)
        #expect(extended.points.count == 2)
        #expect(extended.id == stroke.id)
        #expect(extended.points.last!.x == 30)
    }

    @Test("Stroke Codable round-trip")
    func strokeCodable() throws {
        let stroke = Stroke(
            color: testColor,
            width: 3.0,
            opacity: 0.7,
            points: [testPoint, DrawingPoint(x: 30, y: 40)],
            authorID: authorID
        )
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(Stroke.self, from: data)
        #expect(decoded.id == stroke.id)
        #expect(decoded.color == stroke.color)
        #expect(decoded.width == stroke.width)
        #expect(decoded.points.count == stroke.points.count)
    }

    // MARK: - Drawing

    @Test("Drawing empty")
    func drawingEmpty() {
        let empty = Drawing.empty
        #expect(empty.strokes.isEmpty)
        #expect(empty.version == 0)
    }

    @Test("Drawing appending stroke")
    func drawingAppendingStroke() {
        let stroke = Stroke(
            color: testColor,
            width: 2,
            points: [testPoint],
            authorID: authorID
        )
        let drawing = Drawing.empty.appending(stroke)
        #expect(drawing.strokes.count == 1)
        #expect(drawing.version == 1)
    }

    @Test("Drawing removing stroke")
    func drawingRemovingStroke() {
        let s1 = Stroke(color: testColor, width: 2, points: [testPoint], authorID: authorID)
        let s2 = Stroke(color: testColor, width: 2, points: [testPoint], authorID: authorID)
        let drawing = Drawing(strokes: [s1, s2]).removing(strokeID: s1.id)
        #expect(drawing.strokes.count == 1)
        #expect(drawing.strokes.first!.id == s2.id)
    }

    @Test("Drawing clearing")
    func drawingClearing() {
        let stroke = Stroke(
            color: testColor,
            width: 2,
            points: [testPoint],
            authorID: authorID
        )
        let drawing = Drawing(strokes: [stroke]).cleared()
        #expect(drawing.strokes.isEmpty)
        #expect(drawing.version > 0)
    }

    @Test("Drawing replacing stroke")
    func drawingReplacingStroke() {
        let original = Stroke(
            color: testColor,
            width: 2,
            points: [testPoint],
            authorID: authorID
        )
        let drawing = Drawing(strokes: [original])
        let replacement = Stroke(
            id: original.id,
            color: testColor,
            width: 8,
            points: [testPoint],
            authorID: authorID
        )
        let updated = drawing.replacing(replacement)
        #expect(updated.strokes.first!.width == 8)
    }

    @Test("Drawing stroke lookup")
    func drawingStrokeLookup() {
        let stroke = Stroke(color: testColor, width: 2, points: [testPoint], authorID: authorID)
        let drawing = Drawing(strokes: [stroke])
        #expect(drawing.stroke(id: stroke.id) != nil)
        #expect(drawing.stroke(id: UUID()) == nil)
    }

    @Test("Drawing estimated byte count")
    func drawingEstimatedByteCount() {
        let stroke = Stroke(
            color: testColor,
            width: 2,
            points: Array(repeating: testPoint, count: 10),
            authorID: authorID
        )
        let drawing = Drawing(strokes: [stroke])
        #expect(drawing.estimatedByteCount == 400)
    }

    @Test("Drawing Codable round-trip")
    func drawingCodable() throws {
        let stroke = Stroke(
            color: testColor,
            width: 2,
            points: [testPoint, DrawingPoint(x: 50, y: 60)],
            authorID: authorID
        )
        let drawing = Drawing(strokes: [stroke], version: 5)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(drawing)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Drawing.self, from: data)

        #expect(decoded.strokes.count == 1)
        #expect(decoded.strokes.first!.id == stroke.id)
        #expect(decoded.version == 5)
    }

    @Test("Drawing Equatable")
    func drawingEquatable() {
        let a = Drawing(strokes: [], version: 0)
        let b = Drawing(strokes: [], version: 0)
        #expect(a == b)
    }
}

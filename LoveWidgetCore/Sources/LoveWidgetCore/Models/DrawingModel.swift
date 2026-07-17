import Foundation
import CoreGraphics

// MARK: - DrawingPoint

/// A single captured point in a stroke path.
///
/// Points carry spatial coordinates and a timestamp to enable:
/// - Velocity-based stroke width variation
/// - Drawing playback animation
/// - Fine-grained conflict resolution
public struct DrawingPoint: Codable, Sendable, Equatable, Hashable {
    /// Horizontal position in the canvas coordinate space
    public let x: Double
    /// Vertical position in the canvas coordinate space
    public let y: Double
    /// Pressure level (0.0–1.0). Defaults to 1.0 for mouse input.
    public let pressure: Double
    /// Time the point was recorded
    public let timestamp: Date

    public init(
        x: Double,
        y: Double,
        pressure: Double = 1.0,
        timestamp: Date = Date()
    ) {
        self.x = x
        self.y = y
        self.pressure = max(0, min(1, pressure))
        self.timestamp = timestamp
    }

    /// Convenience initializer from CGPoint
    public init(point: CGPoint, pressure: Double = 1.0, timestamp: Date = Date()) {
        self.init(x: point.x, y: point.y, pressure: pressure, timestamp: timestamp)
    }

    /// Convert back to CGPoint
    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - StrokeColor

/// An RGBA color representation that is Codable and Sendable.
///
/// SwiftUI.Color cannot be directly encoded, so colors are stored
/// as component values and converted to/from SwiftUI.Color at the UI layer.
public struct StrokeColor: Codable, Sendable, Equatable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = max(0, min(1, red))
        self.green = max(0, min(1, green))
        self.blue = max(0, min(1, blue))
        self.alpha = max(0, min(1, alpha))
    }

    // MARK: - Preset Colors

    public static let black      = StrokeColor(red: 0.04, green: 0.04, blue: 0.04)
    public static let white      = StrokeColor(red: 0.98, green: 0.98, blue: 0.98)
    public static let crimson    = StrokeColor(red: 0.863, green: 0.149, blue: 0.247)
    public static let coral      = StrokeColor(red: 0.996, green: 0.431, blue: 0.443)
    public static let rose       = StrokeColor(red: 0.965, green: 0.455, blue: 0.631)
    public static let lavender   = StrokeColor(red: 0.698, green: 0.596, blue: 0.957)
    public static let sapphire   = StrokeColor(red: 0.220, green: 0.424, blue: 0.871)
    public static let teal       = StrokeColor(red: 0.239, green: 0.737, blue: 0.663)
    public static let amber      = StrokeColor(red: 0.996, green: 0.733, blue: 0.176)
    public static let slate      = StrokeColor(red: 0.427, green: 0.478, blue: 0.541)

    /// All preset colors, in palette order
    public static let presets: [StrokeColor] = [
        .black, .white, .crimson, .coral, .rose,
        .lavender, .sapphire, .teal, .amber, .slate,
    ]

    // MARK: - Hex Conversion

    /// CSS-style hex string, e.g. "#FF4C6A"
    public var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Initialize from a hex string. Supports "#RRGGBB" and "RRGGBB".
    public init?(hex: String) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("#") { normalized = String(normalized.dropFirst()) }
        guard normalized.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        guard Scanner(string: normalized).scanHexInt64(&rgbValue) else { return nil }
        self.red   = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        self.green = Double((rgbValue & 0x00FF00) >>  8) / 255.0
        self.blue  = Double( rgbValue & 0x0000FF       ) / 255.0
        self.alpha = 1.0
    }

    /// Returns a new color with the specified alpha level
    public func withAlpha(_ newAlpha: Double) -> StrokeColor {
        StrokeColor(red: red, green: green, blue: blue, alpha: newAlpha)
    }
}

// MARK: - Stroke

/// A complete pen stroke on the canvas.
///
/// Strokes are immutable value types. Each is identified by a stable UUID,
/// enabling delta-based synchronization — only changed strokes are transmitted.
public struct Stroke: Codable, Sendable, Equatable, Identifiable {
    /// Stable unique identifier for delta sync
    public let id: UUID
    /// Visual color of this stroke
    public let color: StrokeColor
    /// Base line width in canvas points (before pressure scaling)
    public let width: Double
    /// Global opacity (0.0–1.0)
    public let opacity: Double
    /// Captured drawing points in temporal order
    public let points: [DrawingPoint]
    /// Timestamp when the stroke was first created
    public let createdAt: Date
    /// UUID of the user who drew this stroke
    public let authorID: UUID

    public init(
        id: UUID = UUID(),
        color: StrokeColor,
        width: Double,
        opacity: Double = 1.0,
        points: [DrawingPoint],
        createdAt: Date = Date(),
        authorID: UUID
    ) {
        self.id = id
        self.color = color
        self.width = max(0.5, min(64.0, width))
        self.opacity = max(0.01, min(1.0, opacity))
        self.points = points
        self.createdAt = createdAt
        self.authorID = authorID
    }

    // MARK: - Derived Properties

    /// Axis-aligned bounding box of this stroke's points
    public var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        // swiftlint:disable:next force_unwrapping
        return CGRect(
            x: xs.min()!,
            y: ys.min()!,
            width: xs.max()! - xs.min()!,
            height: ys.max()! - ys.min()!
        )
    }

    /// Returns a new stroke appending an additional point
    public func appending(point: DrawingPoint) -> Stroke {
        Stroke(
            id: id,
            color: color,
            width: width,
            opacity: opacity,
            points: points + [point],
            createdAt: createdAt,
            authorID: authorID
        )
    }
}

// MARK: - Drawing

/// The complete shared canvas for a pair of users.
///
/// Designed as an immutable value type. All mutations return a new Drawing.
/// Strokes are rendered in array order (painter's algorithm: last on top).
public struct Drawing: Codable, Sendable, Equatable {
    /// All strokes in render order
    public let strokes: [Stroke]
    /// Last time this drawing was modified
    public let updatedAt: Date
    /// Monotonically increasing version counter for conflict detection
    public let version: Int

    public init(
        strokes: [Stroke] = [],
        updatedAt: Date = Date(),
        version: Int = 0
    ) {
        self.strokes = strokes
        self.updatedAt = updatedAt
        self.version = version
    }

    /// An empty drawing — use as initial state
    public static let empty = Drawing()

    // MARK: - DrawingEntry

    /// A single history entry for a sent or received drawing.
    public struct Entry: Codable, Sendable, Identifiable, Equatable {
        public let id: UUID
        public let drawing: Drawing
        public let authorName: String
        public let type: EntryType
        public let timestamp: Date

        public enum EntryType: String, Codable, Sendable, Equatable {
            case sent
            case received
        }

        public init(
            id: UUID = UUID(),
            drawing: Drawing,
            authorName: String,
            type: EntryType,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.drawing = drawing
            self.authorName = authorName
            self.type = type
            self.timestamp = timestamp
        }
    }

    // MARK: - Mutations (return new values)

    /// Returns a new Drawing with the given stroke appended
    public func appending(_ stroke: Stroke) -> Drawing {
        Drawing(
            strokes: strokes + [stroke],
            updatedAt: Date(),
            version: version + 1
        )
    }

    /// Returns a new Drawing with the specified stroke removed
    public func removing(strokeID: UUID) -> Drawing {
        Drawing(
            strokes: strokes.filter { $0.id != strokeID },
            updatedAt: Date(),
            version: version + 1
        )
    }

    /// Returns a new Drawing with all strokes cleared
    public func cleared() -> Drawing {
        Drawing(strokes: [], updatedAt: Date(), version: version + 1)
    }

    /// Returns a new Drawing replacing an existing stroke with an updated one
    public func replacing(_ stroke: Stroke) -> Drawing {
        let updated = strokes.map { $0.id == stroke.id ? stroke : $0 }
        return Drawing(strokes: updated, updatedAt: Date(), version: version + 1)
    }

    // MARK: - Lookup

    /// Find a stroke by its UUID
    public func stroke(id: UUID) -> Stroke? {
        strokes.first { $0.id == id }
    }

    // MARK: - Metadata

    /// Estimated compressed JSON size in bytes (used for sync budget decisions)
    public var estimatedByteCount: Int {
        strokes.reduce(0) { $0 + ($1.points.count * 40) }
    }
}

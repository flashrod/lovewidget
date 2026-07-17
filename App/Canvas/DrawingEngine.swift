import Foundation
import CoreGraphics
import LoveWidgetCore

// MARK: - DrawingEngine

/// Manages the in-progress stroke and the complete drawing history.
///
/// Acts as the bridge between raw touch/mouse events from `CanvasView`
/// and the immutable `Drawing` domain model consumed by `SyncEngine`.
///
/// **Undo/Redo:**
/// The undo stack stores the full `Drawing` state after each completed stroke.
/// Undo pops the stack; redo restores from a forward stack.
/// Max stack depth is 50 to bound memory usage.
@MainActor
public final class DrawingEngine: ObservableObject {

    // MARK: - Published State

    /// The current canonical drawing (all completed strokes)
    @Published public private(set) var drawing: Drawing = .empty

    /// The stroke currently being drawn (not yet committed to `drawing`)
    @Published public private(set) var activeStroke: Stroke?

    /// Whether undo is available
    @Published public private(set) var canUndo: Bool = false

    /// Whether redo is available
    @Published public private(set) var canRedo: Bool = false

    // MARK: - Configuration

    public var currentColor: StrokeColor = .crimson
    public var currentWidth: Double = 3.0
    public var currentOpacity: Double = 1.0
    public var currentUserID: UUID = UUID()

    // MARK: - Private State

    private var undoStack: [Drawing] = []
    private var redoStack: [Drawing] = []
    private static let maxUndoDepth = 50

    private var activePoints: [DrawingPoint] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Stroke Lifecycle

    /// Begin a new stroke at the given canvas position.
    public func beginStroke(at point: CGPoint, pressure: Double = 1.0) {
        let drawingPoint = DrawingPoint(point: point, pressure: pressure)
        activePoints = [drawingPoint]

        activeStroke = Stroke(
            color: currentColor,
            width: currentWidth,
            opacity: currentOpacity,
            points: activePoints,
            authorID: currentUserID
        )
    }

    /// Continue the active stroke with a new point.
    ///
    /// Points are smoothed using Catmull-Rom parameterization via `SplineSmoothing`.
    /// Only adds the point if it's far enough from the last point to avoid noise.
    public func continueStroke(to point: CGPoint, pressure: Double = 1.0) {
        guard activeStroke != nil else { return }

        // Minimum distance filter: suppress jitter below 1pt
        if let last = activePoints.last, last.cgPoint.distance(to: point) < 1.0 { return }

        let drawingPoint = DrawingPoint(point: point, pressure: pressure)
        activePoints.append(drawingPoint)

        activeStroke = Stroke(
            id: activeStroke?.id ?? UUID(),
            color: currentColor,
            width: currentWidth,
            opacity: currentOpacity,
            points: activePoints,
            authorID: currentUserID
        )
    }

    /// Finish the current stroke and commit it to the drawing.
    ///
    /// - Returns: The updated drawing after committing (for sync submission)
    @discardableResult
    public func endStroke() -> Drawing {
        guard let stroke = activeStroke, stroke.points.count >= 2 else {
            // Single-point tap: discard (prevents accidental dots)
            activeStroke = nil
            activePoints = []
            return drawing
        }

        // Push current state onto undo stack before modifying
        pushUndoState()

        drawing = drawing.appending(stroke)
        activeStroke = nil
        activePoints = []

        return drawing
    }

    /// Cancel the current in-progress stroke without committing it.
    public func cancelStroke() {
        activeStroke = nil
        activePoints = []
    }

    // MARK: - Undo / Redo

    /// Undo the last stroke.
    @discardableResult
    public func undo() -> Drawing {
        guard !undoStack.isEmpty else { return drawing }

        redoStack.append(drawing)
        drawing = undoStack.removeLast()

        updateUndoRedoState()
        return drawing
    }

    /// Redo the last undone stroke.
    @discardableResult
    public func redo() -> Drawing {
        guard !redoStack.isEmpty else { return drawing }

        undoStack.append(drawing)
        drawing = redoStack.removeLast()

        updateUndoRedoState()
        return drawing
    }

    // MARK: - Canvas Operations

    /// Clear all strokes from the canvas.
    @discardableResult
    public func clear() -> Drawing {
        guard !drawing.strokes.isEmpty else { return drawing }
        pushUndoState()
        drawing = drawing.cleared()
        return drawing
    }

    /// Replace the entire drawing (called when a remote update arrives).
    ///
    /// Does NOT push to the undo stack — remote updates should not
    /// pollute the local undo history.
    public func applyRemoteDrawing(_ remoteDrawing: Drawing) {
        drawing = remoteDrawing
        activeStroke = nil
        activePoints = []
        // Clear redo stack since history is now diverged
        redoStack = []
        updateUndoRedoState()
    }

    /// Replace the drawing with a new one loaded from storage on launch.
    public func loadDrawing(_ stored: Drawing) {
        drawing = stored
        undoStack = []
        redoStack = []
        updateUndoRedoState()
    }

    // MARK: - Private Helpers

    private func pushUndoState() {
        redoStack = []  // New action clears redo history
        undoStack.append(drawing)
        if undoStack.count > Self.maxUndoDepth {
            undoStack.removeFirst()
        }
        updateUndoRedoState()
    }

    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

// MARK: - CGPoint Distance

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }
}

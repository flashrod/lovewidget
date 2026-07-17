import Foundation
import CoreGraphics

public struct SplineSmoothing: Sendable {

    public static func path(from points: [DrawingPoint], closed: Bool = false) -> CGPath {
        let cgPoints = points.map(\.cgPoint)
        return path(through: cgPoints, closed: closed)
    }

    public static func path(through points: [CGPoint], closed: Bool = false) -> CGPath {
        let path = CGMutablePath()
        guard points.count >= 2 else {
            if let p = points.first {
                path.addEllipse(in: CGRect(x: p.x - 0.5, y: p.y - 0.5, width: 1, height: 1))
            }
            return path
        }

        path.move(to: points[0])

        for index in 0..<(points.count - 1) {
            let p0 = points[max(0, index - 1)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(points.count - 1, index + 2)]

            let (cp1, cp2) = catmullRomControlPoints(p0: p0, p1: p1, p2: p2, p3: p3)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        if closed { path.closeSubpath() }
        return path
    }

    public static func variableWidthPath(
        from points: [DrawingPoint],
        baseWidth: Double
    ) -> CGPath {
        guard points.count >= 2 else {
            return path(from: points)
        }

        let path = CGMutablePath()
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []

        for index in 0..<points.count {
            let point    = points[index]
            let width    = baseWidth * point.pressure

            let prev = index > 0 ? points[index - 1].cgPoint : point.cgPoint
            let next = index < points.count - 1 ? points[index + 1].cgPoint : point.cgPoint
            let tangent = CGPoint(
                x: next.x - prev.x,
                y: next.y - prev.y
            ).normalized()

            let normal = CGPoint(x: -tangent.y, y: tangent.x)

            let center = point.cgPoint
            upper.append(CGPoint(
                x: center.x + normal.x * width * 0.5,
                y: center.y + normal.y * width * 0.5
            ))
            lower.append(CGPoint(
                x: center.x - normal.x * width * 0.5,
                y: center.y - normal.y * width * 0.5
            ))
        }

        let upperPath = Self.path(through: upper)
        let lowerReversed = Self.path(through: lower.reversed())

        path.addPath(upperPath)
        path.addPath(lowerReversed)
        path.closeSubpath()

        return path
    }

    private static func catmullRomControlPoints(
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint
    ) -> (cp1: CGPoint, cp2: CGPoint) {
        let cp1 = CGPoint(
            x: p1.x + (p2.x - p0.x) / 6.0,
            y: p1.y + (p2.y - p0.y) / 6.0
        )
        let cp2 = CGPoint(
            x: p2.x - (p3.x - p1.x) / 6.0,
            y: p2.y - (p3.y - p1.y) / 6.0
        )
        return (cp1, cp2)
    }
}

private extension CGPoint {
    func normalized() -> CGPoint {
        let len = sqrt(x * x + y * y)
        guard len > 0 else { return CGPoint(x: 1, y: 0) }
        return CGPoint(x: x / len, y: y / len)
    }
}

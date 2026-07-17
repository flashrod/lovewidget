import SwiftUI
import LoveWidgetCore

struct StrokeRenderer {
    static func render(_ stroke: Stroke, in context: GraphicsContext, scale: CGFloat = 1) {
        guard stroke.points.count >= 2 else {
            if let point = stroke.points.first {
                let dotRect = CGRect(
                    x: point.x - stroke.width / 2,
                    y: point.y - stroke.width / 2,
                    width: stroke.width,
                    height: stroke.width
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(Color(stroke.color).opacity(stroke.opacity))
                )
            }
            return
        }

        let cgPath = SplineSmoothing.path(from: stroke.points)
        let path = Path(cgPath)

        var copy = context
        copy.opacity = stroke.opacity
        copy.stroke(
            path,
            with: .color(Color(stroke.color)),
            style: StrokeStyle(
                lineWidth: max(1, stroke.width * scale),
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    static func renderAll(_ drawing: Drawing, in context: GraphicsContext, size: CGSize) {
        var context = context
        let padding: CGFloat = 8
        let innerSize = CGSize(
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )
        let bbox = drawing.boundingBox
        let scale = min(
            innerSize.width / max(bbox.width, 1),
            innerSize.height / max(bbox.height, 1)
        )
        let offsetX = padding + (innerSize.width - bbox.width * scale) / 2 - bbox.minX * scale
        let offsetY = padding + (innerSize.height - bbox.height * scale) / 2 - bbox.minY * scale

        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)

        for stroke in drawing.strokes {
            render(stroke, in: context, scale: scale)
        }
    }
}

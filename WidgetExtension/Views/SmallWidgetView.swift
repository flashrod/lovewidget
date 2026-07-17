import WidgetKit
import SwiftUI
import LoveWidgetCore

struct SmallWidgetView: View {

    let entry: LoveWidgetEntry

    var body: some View {
        ZStack {
            canvasPreview
                .opacity(0.15)

            VStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)

                Text(entry.partnerName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let updated = entry.lastUpdated {
                    Text(updated, style: .relative)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var canvasPreview: some View {
        Canvas { context, size in
            for stroke in entry.drawing.strokes {
                guard stroke.points.count >= 2 else { continue }
                let path = SplineSmoothing.path(from: stroke.points)
                context.stroke(
                    Path(path),
                    with: .color(Color(stroke.color).opacity(stroke.opacity)),
                    style: StrokeStyle(lineWidth: max(1, stroke.width * 0.3))
                )
            }
        }
    }
}

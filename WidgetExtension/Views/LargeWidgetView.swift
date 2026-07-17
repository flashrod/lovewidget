import WidgetKit
import SwiftUI
import LoveWidgetCore

struct LargeWidgetView: View {

    let entry: LoveWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text("LoveWidget")
                        .font(.system(size: 11, weight: .semibold))
                }

                Spacer()

                Text(entry.partnerName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Canvas
            canvasPreview
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                )

            // Status bar
            HStack {
                Circle()
                    .fill(entry.syncStatus.isLive ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)

                Text(entry.syncStatus.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()

                if let updated = entry.lastUpdated {
                    Label(
                        updated.formatted(.relative(presentation: .named)),
                        systemImage: "clock"
                    )
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
    }

    private var canvasPreview: some View {
        Canvas { context, size in
            for stroke in entry.drawing.strokes {
                guard stroke.points.count >= 2 else { continue }
                let path = SplineSmoothing.path(from: stroke.points)
                context.stroke(
                    Path(path),
                    with: .color(Color(stroke.color).opacity(stroke.opacity)),
                    style: StrokeStyle(lineWidth: max(1, stroke.width * 0.6))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

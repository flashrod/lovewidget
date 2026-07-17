import WidgetKit
import SwiftUI
import LoveWidgetCore

struct MediumWidgetView: View {

    let entry: LoveWidgetEntry

    var body: some View {
        HStack(spacing: 12) {
            canvasPreview
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                    Text("LoveWidget")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(entry.partnerName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if let updated = entry.lastUpdated {
                    Label(
                        updated.formatted(.relative(presentation: .named)),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack {
                    Circle()
                        .fill(entry.syncStatus.isLive ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(entry.syncStatus.description)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(8)
    }

    private var canvasPreview: some View {
        Canvas { context, size in
            for stroke in entry.drawing.strokes {
                guard stroke.points.count >= 2 else { continue }
                let path = SplineSmoothing.path(from: stroke.points)
                context.stroke(
                    Path(path),
                    with: .color(Color(stroke.color).opacity(stroke.opacity)),
                    style: StrokeStyle(lineWidth: max(1, stroke.width * 0.5))
                )
            }
        }
        .frame(width: 120, height: 120)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

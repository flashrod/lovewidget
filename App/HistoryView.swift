import SwiftUI
import LoveWidgetCore

struct HistoryView: View {

    @State private var entries: [Drawing.Entry] = []
    @State private var selectedEntryID: UUID?
    @State private var selectedEntry: Drawing.Entry?

    var body: some View {
        VStack(spacing: 0) {
            header

            if entries.isEmpty {
                emptyState
            } else {
                HSplitView {
                    listSidebar
                    detailView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: loadEntries)
        .onChange(of: selectedEntryID) { _, newID in
            selectedEntry = entries.first { $0.id == newID }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            Text("History")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            if !entries.isEmpty {
                Text("\(entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No History Yet")
                .font(.title3.weight(.semibold))
            Text("Drawings you send and receive will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listSidebar: some View {
        List(entries.reversed(), id: \.id, selection: $selectedEntryID) { entry in
            HistoryRow(entry: entry)
                .tag(entry.id)
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(minWidth: 220, idealWidth: 260)
    }

    @ViewBuilder
    private var detailView: some View {
        if let entry = selectedEntry {
            HistoryDetailView(entry: entry)
                .frame(minWidth: 300, idealWidth: .infinity, maxWidth: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.and.pencil.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("Select a drawing to view")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadEntries() {
        entries = (try? AppGroupStorage.shared.loadHistory()) ?? []
    }
}

struct HistoryRow: View {
    let entry: Drawing.Entry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.type == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(entry.type == .sent ? Color.accentColor : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.type == .sent ? "Sent" : "Received")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(entry.drawing.strokes.count) strokes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.authorName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct HistoryDetailView: View {
    let entry: Drawing.Entry

    private let previewSize: CGFloat = 240

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: entry.type == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(entry.type == .sent ? Color.accentColor : .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.type == .sent ? "Sent to" : "Received from")
                        .font(.headline)
                    Text(entry.authorName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Divider()

            Canvas { context, size in
                for stroke in entry.drawing.strokes {
                    renderStroke(stroke, in: context)
                }
            }
            .frame(width: previewSize, height: previewSize)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            )

            VStack(alignment: .leading, spacing: 6) {
                Label("\(entry.drawing.strokes.count) strokes", systemImage: "pencil.tip")
                    .font(.caption)
                Label("Version \(entry.drawing.version)", systemImage: "number")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func renderStroke(_ stroke: Stroke, in context: GraphicsContext) {
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
            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
        )
    }
}

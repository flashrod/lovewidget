import SwiftUI
import LoveWidgetCore

struct MenuBarPopoverView: View {
    let onClose: (() -> Void)?

    @State private var drawing: Drawing = .empty
    @State private var partnerName: String = ""
    @State private var lastUpdated: Date?
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    private let storage = AppGroupStorage.shared

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            drawingPreview
            Divider()
            footerView
        }
        .frame(width: 240)
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
            Text(partnerName.isEmpty ? "LoveWidget" : partnerName)
                .font(.headline)
            Spacer()
            Text(relativeDateString(from: lastUpdated))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var drawingPreview: some View {
        Group {
            if drawing.strokes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "pencil.tip")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No drawing yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                DrawingPreview(drawing: drawing)
                    .frame(height: 160)
                    .padding(8)
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Button("Open LoveWidget") {
                openMainWindow()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func refresh() {
        drawing = (try? storage.loadPartnerDrawing()) ?? .empty
        let pair = try? storage.loadPair()
        partnerName = pair?.partnerDisplayName ?? ""
        lastUpdated = StorageKeys.userDefaults().object(forKey: StorageKeys.lastSyncTimestampKey) as? Date
    }

    private func openMainWindow() {
        onClose?()
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

private func relativeDateString(from date: Date?) -> String {
    guard let date else { return "" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

struct DrawingPreview: View {
    let drawing: Drawing

    var body: some View {
        Canvas { context, size in
            StrokeRenderer.renderAll(drawing, in: context, size: size)
        }
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

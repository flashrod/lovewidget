import SwiftUI
import LoveWidgetCore

struct ConnectionStatusBadge: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected:    return .green
        case .syncing:      return .blue
        case .connecting:   return .orange
        case .idle:         return .secondary
        case .disconnected: return .gray
        case .error:        return .red
        }
    }

    private var statusText: String {
        switch status {
        case .connected:    return "Connected"
        case .syncing:      return "Syncing"
        case .connecting:   return "Connecting"
        case .idle:         return "Idle"
        case .disconnected: return "Disconnected"
        case .error:        return "Error"
        }
    }
}

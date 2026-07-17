import SwiftUI
import LoveWidgetCore

enum AppNavigation: String, CaseIterable {
    case canvas   = "Canvas"
    case pair     = "Pair"
    case history  = "History"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .canvas:   return "pencil.and.outline"
        case .pair:     return "person.2.fill"
        case .history:  return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

struct OnboardingView: View {
    @State private var displayName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text("Welcome to LoveWidget")
                .font(.title2.weight(.semibold))

            Text("Enter your display name so your partner can recognize you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            TextField("Your Name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            Spacer()

            Button("Continue") {
                var settings = (try? AppGroupStorage.shared.loadSettings()) ?? AppUserSettings()
                settings.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                settings.userID = settings.userID
                try? AppGroupStorage.shared.saveSettings(settings)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .frame(width: 380, height: 380)
    }
}

struct ContentView: View {

    var canvasViewModel: CanvasViewModel
    let syncEngine: SyncEngine?
    let supabaseClient: SupabaseClientActor?
    let userRepo: UserRepository?
    let pairRepo: PairRepository?
    @State private var selectedNav: AppNavigation = .canvas
    @State private var sidebarVisible = true
    @State private var showOnboarding = false

    var body: some View {
        HSplitView {
            if sidebarVisible {
                sidebar
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
            }

            navigationContent
                .frame(minWidth: 400, idealWidth: .infinity, maxWidth: .infinity)
        }
        .frame(minWidth: 650, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .onAppear {
            let settings = (try? AppGroupStorage.shared.loadSettings()) ?? AppUserSettings()
            showOnboarding = !settings.isOnboardingComplete
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ForEach(AppNavigation.allCases, id: \.self) { item in
                sidebarRow(item: item)
            }
            Spacer()
            partnerInfo
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack {
            Image(systemName: "heart.fill")
                .font(.system(size: 18))
                .foregroundStyle(.red)
            Text("LoveWidget")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private func sidebarRow(item: AppNavigation) -> some View {
        Button {
            selectedNav = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selectedNav == item ? Color.accentColor : .secondary)
                    .frame(width: 22)
                Text(item.rawValue)
                    .font(.system(size: 13, weight: selectedNav == item ? .semibold : .regular))
                    .foregroundStyle(selectedNav == item ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedNav == item ? Color.accentColor.opacity(0.1) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private var partnerInfo: some View {
        HStack(spacing: 8) {
            ConnectionStatusBadge(status: canvasViewModel.syncStatus)
            Spacer()
            if !canvasViewModel.partnerName.isEmpty {
                Label(canvasViewModel.partnerName, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var navigationContent: some View {
        switch selectedNav {
        case .canvas:
            CanvasView(viewModel: canvasViewModel)
        case .pair:
            PairingView(
                canvasViewModel: canvasViewModel,
                syncEngine: syncEngine,
                supabaseClient: supabaseClient,
                userRepo: userRepo,
                pairRepo: pairRepo
            )
        case .history:
            HistoryView()
        case .settings:
            SettingsView(canvasViewModel: canvasViewModel)
        }
    }
}

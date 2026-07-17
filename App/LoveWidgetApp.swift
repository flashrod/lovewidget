import SwiftUI
import LoveWidgetCore

@main
struct LoveWidgetApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var canvasViewModel: CanvasViewModel
    @State private var syncEngine: SyncEngine?
    @State private var supabaseClient: SupabaseClientActor?
    @State private var isConfigured = false
    @State private var configurationError: String?

    init() {
        let vm = CanvasViewModel()
        self._canvasViewModel = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = configurationError {
                    ConfigurationErrorView(message: error)
                } else if isConfigured {
                    ContentView(
                        canvasViewModel: canvasViewModel,
                        syncEngine: syncEngine,
                        supabaseClient: supabaseClient
                    )
                } else {
                    ProgressView("Setting up…")
                        .frame(width: 300, height: 200)
                }
            }
            .task {
                await configureServices()
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 700)
    }

    private func configureServices() async {
        do {
            let config = try SupabaseConfiguration.fromMainBundle()
            let client = SupabaseClientActor(configuration: config)
            self.supabaseClient = client

            let storage = AppGroupStorage.shared
            let drawingRepo = DrawingRepository(clientActor: client)
            let _ = PairRepository(clientActor: client)
            let _ = UserRepository(clientActor: client)
            let conflictResolver = ConflictResolver()

            let engine = SyncEngine(
                storage: storage,
                drawingRepo: drawingRepo,
                conflictResolver: conflictResolver
            )
            self.syncEngine = engine

            canvasViewModel.attachSyncEngine(engine)
            await engine.setDelegate(canvasViewModel)

            if let localDrawing = try? storage.loadDrawing() {
                await MainActor.run {
                    canvasViewModel.loadStoredDrawing(localDrawing)
                }
            }

            if let localPair = try? storage.loadPair(), let userID = try? storage.loadSettings().userID {
                Task {
                    await engine.start(pairID: localPair.pairID, userID: userID)
                }
            }

            self.isConfigured = true
        } catch {
            self.configurationError = error.localizedDescription
        }
    }
}

struct ConfigurationErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.adjustable")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Configuration Error")
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Copy Config.xcconfig.template → Config.xcconfig\nand fill in your Supabase credentials.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(width: 420, height: 280)
    }
}

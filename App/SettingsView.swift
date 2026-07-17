import SwiftUI
import LoveWidgetCore
import ServiceManagement

struct SettingsView: View {

    var canvasViewModel: CanvasViewModel
    @State private var displayName: String = ""
    @State private var notificationsEnabled = true
    @State private var launchAtLogin = false
    @State private var prefersDarkMode = false
    @State private var defaultBrushWidth: Double = 3.0
    @State private var defaultColor: StrokeColor = .crimson
    @State private var showClearConfirmation = false
    @State private var showSavedIndicator = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                Section("Profile") {
                    TextField("Display Name", text: $displayName)
                }

                Section("Canvas Defaults") {
                    HStack {
                        Text("Brush Width")
                        Spacer()
                        Text("\(Int(defaultBrushWidth))pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $defaultBrushWidth, in: 1...20, step: 0.5)

                    HStack {
                        Text("Default Color")
                        Spacer()
                        Circle()
                            .fill(Color(defaultColor))
                            .frame(width: 20, height: 20)
                    }
                }

                Section("Notifications") {
                    Toggle("Drawing Updates", isOn: $notificationsEnabled)
                }

                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $prefersDarkMode)
                }

                Section("Launch") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                }

                Section {
                    Button("Clear All Data", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            }
            .formStyle(.grouped)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: loadSettings)
        .confirmationDialog(
            "Clear all drawing data?",
            isPresented: $showClearConfirmation
        ) {
            Button("Clear", role: .destructive) {
                canvasViewModel.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase your local drawing. Your partner's data is not affected.")
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            Text("Settings")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            if showSavedIndicator {
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            Button("Save") {
                saveSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func loadSettings() {
        let settings = (try? AppGroupStorage.shared.loadSettings()) ?? AppUserSettings()
        displayName = settings.displayName
        notificationsEnabled = settings.notificationsEnabled
        launchAtLogin = settings.launchAtLogin
        prefersDarkMode = settings.prefersDarkMode
        defaultBrushWidth = settings.defaultBrushWidth
        defaultColor = settings.defaultColor
    }

    private func saveSettings() {
        let settings = AppUserSettings(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            notificationsEnabled: notificationsEnabled,
            launchAtLogin: launchAtLogin,
            prefersDarkMode: prefersDarkMode,
            userID: (try? AppGroupStorage.shared.loadSettings())?.userID,
            defaultBrushWidth: defaultBrushWidth,
            defaultColor: defaultColor
        )
        try? AppGroupStorage.shared.saveSettings(settings)

        canvasViewModel.brushWidth = defaultBrushWidth
        canvasViewModel.selectedColor = defaultColor

        NSApp.appearance = prefersDarkMode
            ? NSAppearance(named: .darkAqua)
            : nil

        applyLaunchAtLogin(launchAtLogin)

        withAnimation(.easeInOut(duration: 0.15)) {
            showSavedIndicator = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.15)) {
                showSavedIndicator = false
            }
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                LWLogger.app.warning("Launch at login: \(error.localizedDescription)")
            }
        }
    }
}

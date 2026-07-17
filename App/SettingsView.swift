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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

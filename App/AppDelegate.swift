import AppKit
import LoveWidgetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        LWLogger.app.info("LoveWidget did finish launching.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        LWLogger.app.info("LoveWidget will terminate.")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "heart.fill",
                accessibilityDescription: "LoveWidget"
            )
        }

        statusMenu = NSMenu()
        statusMenu?.addItem(
            withTitle: "Show LoveWidget",
            action: #selector(showWindow),
            keyEquivalent: ""
        )
        statusMenu?.addItem(.separator())
        statusMenu?.addItem(
            withTitle: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        statusItem?.menu = statusMenu
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func updateMenuBarIcon(status: SyncStatus) {
        guard let button = statusItem?.button else { return }

        let imageName: String
        let tintColor: NSColor

        switch status {
        case .connected:
            imageName = "heart.fill"
            tintColor = .systemRed
        case .syncing:
            imageName = "heart.fill"
            tintColor = .systemBlue
        case .connecting:
            imageName = "heart"
            tintColor = .systemOrange
        case .idle, .disconnected, .error:
            imageName = "heart.slash"
            tintColor = .systemGray
        }

        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)
        image?.isTemplate = false
        button.image = image
        button.contentTintColor = tintColor
    }
}



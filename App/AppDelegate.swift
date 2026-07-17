import AppKit
import SwiftUI
import LoveWidgetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

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
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        if popover == nil {
            let contentView = MenuBarPopoverView(onClose: { [weak self] in
                self?.popover?.performClose(nil)
            })
            let hostingController = NSHostingController(rootView: contentView)
            let newPopover = NSPopover()
            newPopover.contentSize = NSSize(width: 240, height: 320)
            newPopover.behavior = .transient
            newPopover.contentViewController = hostingController
            popover = newPopover
        }

        popover?.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )

        if let popoverWindow = popover?.contentViewController?.view.window {
            popoverWindow.makeKey()
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

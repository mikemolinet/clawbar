import AppKit
import SwiftUI

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let state: AppState
    private var lastBucket: IconBucket?
    private var allSessionsWindow: AllSessionsWindowController?
    private var settingsWindow: NSWindow?

    public init(state: AppState) {
        self.state = state
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        setupIcon()
        setupMenu()
        startObserving()
    }

    private func setupIcon() {
        statusItem.button?.image = IconRenderer.renderLoading()
        statusItem.button?.toolTip = "ClawBar"
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Card item
        let cardItem = NSMenuItem()
        allSessionsWindow = AllSessionsWindowController(state: state)
        let hostingView = NSHostingView(rootView: MenuCardView(state: state, onShowAllSessions: { [weak self] in
            self?.statusItem.menu?.cancelTracking()
            self?.allSessionsWindow?.show()
        }))

        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        cardItem.view = hostingView
        menu.addItem(cardItem)

        // Separator
        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit ClawBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func startObserving() {
        // Use a timer to check for icon + size updates
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateIconIfNeeded()
                self?.updateMenuSize()
            }
        }
    }

    private func updateIconIfNeeded() {
        let bucket = state.iconBucket
        guard bucket != lastBucket else { return }
        lastBucket = bucket

        statusItem.button?.image = IconRenderer.render(bucket: bucket)
    }

    private func updateMenuSize() {
        guard let cardItem = statusItem.menu?.items.first,
              let hostingView = cardItem.view as? NSHostingView<MenuCardView> else { return }

        let fittingSize = hostingView.fittingSize
        if abs(hostingView.frame.size.height - fittingSize.height) > 1 {
            hostingView.frame = NSRect(origin: .zero, size: fittingSize)
        }
    }

    @objc private func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(state: state)
        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 360, height: 260)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClawBar Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        updateMenuSize()
    }
}

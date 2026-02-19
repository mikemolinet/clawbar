import AppKit
import SwiftUI

@main
public struct ClawBarApp {
    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // No dock icon
        app.run()
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var coordinator: AppCoordinator?
    private let state = AppState()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = AppCoordinator(state: state)
        statusItemController = StatusItemController(state: state, onRetryClaude: { [weak self] in
            self?.coordinator?.retryClaude()
        })
        coordinator?.start()

        // Listen for sleep/wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        coordinator?.stop()
    }

    @objc private func systemDidWake(_ notification: Notification) {
        coordinator?.start()
    }
}

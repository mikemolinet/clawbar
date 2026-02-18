import AppKit
import SwiftUI

@MainActor
public final class AllSessionsWindowController {
    private var window: NSPanel?
    private let state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public func show() {
        if let existing = window, existing.isVisible {
            existing.orderFront(nil)
            return
        }

        let view = AllSessionsView(state: state, onClose: { [weak self] in
            self?.close()
        })

        let hostingView = NSHostingView(rootView: view)
        let fittingSize = hostingView.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "All Sessions"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow

        // Position near top-right of screen (near menu bar)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - fittingSize.width - 16
            let y = screenFrame.maxY - fittingSize.height - 8
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        window = panel
    }

    public func close() {
        window?.close()
        window = nil
    }
}

struct AllSessionsView: View {
    @Bindable var state: AppState
    let onClose: () -> Void

    private static let openClawColor = Color(red: 0.9, green: 0.3, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🦞")
                    .font(.system(size: 14))
                Text("All Sessions")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            if state.openClawSessions.isEmpty {
                Text("No active sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(state.openClawSessions.enumerated()), id: \.element.sessionName) { _, context in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(context.sessionName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.0f%% used", context.percentUsed))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ContextProgressBar(
                            percent: context.percentUsed,
                            tint: Self.openClawColor,
                            label: "\(context.sessionName) context"
                        )

                        HStack {
                            Text(context.formattedTokens)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            if context.compactionCount > 0 {
                                Text("· \(context.compactionCount) compaction\(context.compactionCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if context.sessionName != state.openClawSessions.last?.sessionName {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

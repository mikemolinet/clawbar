import SwiftUI

public struct OpenClawCard: View {
    let sessions: [OpenClawContext]
    let status: ConnectionStatus
    let showUsed: Bool
    let lastUpdate: Date?
    let onShowAll: (() -> Void)?

    public init(
        sessions: [OpenClawContext],
        status: ConnectionStatus,
        showUsed: Bool = true,
        lastUpdate: Date? = nil,
        onShowAll: (() -> Void)? = nil
    ) {
        self.sessions = sessions
        self.status = status
        self.showUsed = showUsed
        self.lastUpdate = lastUpdate
        self.onShowAll = onShowAll
    }

    private static let openClawColor = Color(red: 0.9, green: 0.3, blue: 0.2)

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("🦞")
                    .font(.system(size: 12))
                Text("OpenClaw")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if let lastUpdate {
                    Text(TimeFormatting.relativeAgo(lastUpdate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !status.isConnected {
                statusMessage
            } else if sessions.isEmpty {
                Text("No active sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let visible = Array(sessions.prefix(2))
                let remaining = sessions.count - 2

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(visible.enumerated()), id: \.element.sessionName) { _, context in
                        sessionRow(context)
                    }
                }

                if remaining > 0 {
                    Button(action: { onShowAll?() }) {
                        Text("+ \(remaining) more session\(remaining == 1 ? "" : "s")")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 280, alignment: .leading)
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch status {
        case .disconnected:
            Text("Not connected to OpenClaw")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .connecting:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .waitingForApproval:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for approval...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Approve 'ClawBar' in your OpenClaw dashboard")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
        case .connected:
            EmptyView()
        }
    }

    @ViewBuilder
    private func sessionRow(_ context: OpenClawContext) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(context.sessionName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(percentText(context))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
            }

            ContextProgressBar(
                percent: context.percentUsed,
                tint: Self.openClawColor,
                label: "\(context.sessionName) context",
                thresholdPercent: 90
            )

            HStack {
                Text(context.formattedTokens)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if context.compactionCount > 0 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(context.compactionCount) compaction\(context.compactionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func percentText(_ context: OpenClawContext) -> String {
        let value = showUsed ? context.percentUsed : context.percentRemaining
        let suffix = showUsed ? "used" : "left"
        return String(format: "%.0f%% %@", value, suffix)
    }
}

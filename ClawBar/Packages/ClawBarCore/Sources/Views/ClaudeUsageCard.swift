import SwiftUI

public struct ClaudeUsageCard: View {
    let usage: ClaudeUsage?
    let status: ClaudeConnectionStatus
    let showUsed: Bool
    let lastUpdate: Date?
    var onRetry: (() -> Void)?

    public init(
        usage: ClaudeUsage?,
        status: ClaudeConnectionStatus,
        showUsed: Bool = true,
        lastUpdate: Date? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.usage = usage
        self.status = status
        self.showUsed = showUsed
        self.lastUpdate = lastUpdate
        self.onRetry = onRetry
    }

    private static let claudeColor = Color(red: 0.85, green: 0.45, blue: 0.35) // Anthropic coral

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Self.claudeColor)
                Text("Claude")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if let lastUpdate {
                    Text(TimeFormatting.relativeAgo(lastUpdate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if status != .available {
                HStack {
                    Text(status.displayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let onRetry {
                        Button("Retry") { onRetry() }
                            .buttonStyle(.plain)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            } else if let usage {
                usageContent(usage)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 280, alignment: .leading)
    }

    @ViewBuilder
    private func usageContent(_ usage: ClaudeUsage) -> some View {
        // Session (5h)
        if let session = usage.session {
            windowSection(
                title: "Session (5h)",
                window: session
            )
        }

        // Weekly (7d)
        if let weekly = usage.weekly {
            windowSection(
                title: "Weekly (7d)",
                window: weekly
            )
        }

        // Overage
        if let extra = usage.extraUsage, extra.isEnabled {
            HStack {
                Text("Overage:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(extra.usedCredits, currency: extra.currency))
                    .font(.subheadline.monospacedDigit())
                if let limit = extra.monthlyLimit {
                    Text("/ \(formatCurrency(limit, currency: extra.currency))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func windowSection(title: String, window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(percentText(window))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
            }

            ContextProgressBar(
                percent: window.percentUsed,
                tint: Self.claudeColor,
                label: title
            )

            if let resetText = TimeFormatting.relativeReset(window.resetsAt) {
                Text(resetText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func percentText(_ window: UsageWindow) -> String {
        let value = showUsed ? window.percentUsed : window.percentRemaining
        let suffix = showUsed ? "used" : "left"
        return String(format: "%.0f%% %@", value, suffix)
    }

    private func formatCurrency(_ amount: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        formatter.maximumFractionDigits = amount >= 1000 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

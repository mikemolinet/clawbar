import SwiftUI

public struct TokenUsageCard: View {
    let tokenUsage: TokenUsageData?

    public init(tokenUsage: TokenUsageData?) {
        self.tokenUsage = tokenUsage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                Text("Token Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if let tokenUsage {
                HStack {
                    // Today
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if let today = tokenUsage.today {
                            Text(TokenFormatting.format(today.totalTokens))
                                .font(.subheadline.monospacedDigit())
                                .fontWeight(.medium)
                            HStack(spacing: 6) {
                                Label(TokenFormatting.format(today.combinedInput), systemImage: "arrow.down.circle")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                Label(TokenFormatting.format(today.output), systemImage: "arrow.up.circle")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            Text("0")
                                .font(.subheadline.monospacedDigit())
                                .fontWeight(.medium)
                        }
                    }

                    Spacer()

                    // Last 30 Days
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last 30 Days")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(TokenFormatting.format(tokenUsage.totalTokens))
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.medium)
                        HStack(spacing: 6) {
                            Label(TokenFormatting.format(tokenUsage.totalInput), systemImage: "arrow.down.circle")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            Label(TokenFormatting.format(tokenUsage.totalOutput), systemImage: "arrow.up.circle")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } else {
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 280, alignment: .leading)
    }
}

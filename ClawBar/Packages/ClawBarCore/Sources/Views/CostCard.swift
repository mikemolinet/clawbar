import SwiftUI

public struct CostCard: View {
    let costData: CostData?

    public init(costData: CostData?) {
        self.costData = costData
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("API Cost")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if let costData {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(formatCost(costData.costToday))
                            .font(.title3.monospacedDigit())
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last 30 Days")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(formatCost(costData.costLast30Days))
                            .font(.title3.monospacedDigit())
                            .fontWeight(.medium)
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

    private func formatCost(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = amount >= 100 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

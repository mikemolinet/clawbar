import SwiftUI

public struct ContextProgressBar: View {
    let percent: Double
    let tint: Color
    let label: String
    var thresholdPercent: Double? = nil

    public init(percent: Double, tint: Color, label: String, thresholdPercent: Double? = nil) {
        self.percent = percent
        self.tint = tint
        self.label = label
        self.thresholdPercent = thresholdPercent
    }

    private var clamped: Double {
        min(100, max(0, percent))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * clamped / 100)

                // Threshold marker (e.g. compaction at 90%)
                if let threshold = thresholdPercent, threshold > 0, threshold < 100 {
                    let xPos = proxy.size.width * threshold / 100
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 1.5, height: proxy.size.height + 4)
                        .position(x: xPos, y: proxy.size.height / 2)
                        .help("Compaction triggers at \(Int(threshold))%")
                }
            }
        }
        .frame(height: 6)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

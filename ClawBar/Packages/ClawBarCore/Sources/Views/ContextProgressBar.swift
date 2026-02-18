import SwiftUI

public struct ContextProgressBar: View {
    let percent: Double
    let tint: Color
    let label: String

    public init(percent: Double, tint: Color, label: String) {
        self.percent = percent
        self.tint = tint
        self.label = label
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
            }
        }
        .frame(height: 6)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

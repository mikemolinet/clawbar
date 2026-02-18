import Foundation

public struct OpenClawContext: Sendable, Equatable {
    public let sessionName: String
    public let totalTokens: Int
    public let contextWindow: Int
    public let compactionCount: Int
    public let isCompacting: Bool
    public let fetchedAt: Date

    public init(
        sessionName: String,
        totalTokens: Int,
        contextWindow: Int,
        compactionCount: Int,
        isCompacting: Bool,
        fetchedAt: Date = .now
    ) {
        self.sessionName = sessionName
        self.totalTokens = totalTokens
        self.contextWindow = contextWindow
        self.compactionCount = compactionCount
        self.isCompacting = isCompacting
        self.fetchedAt = fetchedAt
    }

    public var percentUsed: Double {
        guard contextWindow > 0 else { return 0 }
        return min(100, Double(totalTokens) / Double(contextWindow) * 100)
    }

    public var percentRemaining: Double {
        100 - percentUsed
    }

    public var formattedTokens: String {
        "\(formatTokenCount(totalTokens)) / \(formatTokenCount(contextWindow))"
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return "\(count / 1_000)k"
        }
        return "\(count)"
    }
}

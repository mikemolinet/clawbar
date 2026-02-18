import Foundation
import SwiftUI

@MainActor
@Observable
public final class AppState {
    public var openClawSessions: [OpenClawContext] = []
    public var claudeUsage: ClaudeUsage?
    public var tokenUsage: TokenUsageData?
    public var openClawStatus: ConnectionStatus = .disconnected
    public var claudeStatus: ClaudeConnectionStatus = .unknown
    public var lastOpenClawUpdate: Date?
    public var lastClaudeUpdate: Date?

    // Settings
    public var showUsed: Bool = true // true = "X% used", false = "X% remaining"

    public init() {}

    public var claudeSessionPercent: Double? {
        claudeUsage?.session?.percentUsed
    }

    public var claudeWeeklyPercent: Double? {
        claudeUsage?.weekly?.percentUsed
    }

    public var openClawPercent: Double? {
        // Use the highest context usage for the icon
        openClawSessions.map(\.percentUsed).max()
    }

    /// Bucket for icon caching — quantize to 5% steps
    public var iconBucket: IconBucket {
        IconBucket(
            openClaw: quantize(openClawPercent),
            claude: quantize(claudeSessionPercent),
            openClawConnected: openClawStatus.isConnected,
            claudeAvailable: claudeStatus == .available
        )
    }

    private func quantize(_ percent: Double?) -> Int {
        guard let percent else { return -1 }
        return min(20, Int(percent / 5))
    }
}

public struct IconBucket: Equatable, Hashable {
    public let openClaw: Int
    public let claude: Int
    public let openClawConnected: Bool
    public let claudeAvailable: Bool
}

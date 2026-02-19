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
    public var showUsed: Bool {
        get { UserDefaults.standard.object(forKey: "showUsed") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showUsed") }
    }
    public var soundsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundsEnabled") }
    }

    // Notification toggles (all default ON)
    public var notifyContext75: Bool {
        get { UserDefaults.standard.object(forKey: "notifyContext75") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notifyContext75") }
    }
    public var notifyContext85: Bool {
        get { UserDefaults.standard.object(forKey: "notifyContext85") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notifyContext85") }
    }
    public var notifyContextCompacted: Bool {
        get { UserDefaults.standard.object(forKey: "notifyContextCompacted") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notifyContextCompacted") }
    }
    public var notifyClaudeSession: Bool {
        get { UserDefaults.standard.object(forKey: "notifyClaudeSession") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notifyClaudeSession") }
    }

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

import Foundation

public struct ClaudeUsage: Sendable, Equatable {
    public let session: UsageWindow?
    public let weekly: UsageWindow?
    public let weeklyOAuthApps: UsageWindow?
    public let weeklySonnet: UsageWindow?
    public let extraUsage: ExtraUsage?
    public let fetchedAt: Date

    public init(
        session: UsageWindow?,
        weekly: UsageWindow?,
        weeklyOAuthApps: UsageWindow?,
        weeklySonnet: UsageWindow?,
        extraUsage: ExtraUsage?,
        fetchedAt: Date = .now
    ) {
        self.session = session
        self.weekly = weekly
        self.weeklyOAuthApps = weeklyOAuthApps
        self.weeklySonnet = weeklySonnet
        self.extraUsage = extraUsage
        self.fetchedAt = fetchedAt
    }
}

public struct UsageWindow: Sendable, Equatable {
    public let utilization: Double
    public let resetsAt: Date?

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    public var percentUsed: Double {
        min(100, max(0, utilization))
    }

    public var percentRemaining: Double {
        100 - percentUsed
    }

    public var timeUntilReset: TimeInterval? {
        guard let resetsAt else { return nil }
        let remaining = resetsAt.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
}

public struct ExtraUsage: Sendable, Equatable {
    public let isEnabled: Bool
    public let monthlyLimit: Double?
    public let usedCredits: Double
    public let utilization: Double?
    public let currency: String?

    public init(
        isEnabled: Bool,
        monthlyLimit: Double?,
        usedCredits: Double,
        utilization: Double?,
        currency: String?
    ) {
        self.isEnabled = isEnabled
        self.monthlyLimit = monthlyLimit
        self.usedCredits = usedCredits
        self.utilization = utilization
        self.currency = currency
    }
}

public struct ClaudeCredentials: Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let subscriptionType: String?
    public let rateLimitTier: String?

    public init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        subscriptionType: String?,
        rateLimitTier: String?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
        self.rateLimitTier = rateLimitTier
    }

    public var isExpired: Bool {
        expiresAt < .now
    }
}

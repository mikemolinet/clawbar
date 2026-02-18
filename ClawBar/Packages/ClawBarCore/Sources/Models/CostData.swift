import Foundation

public struct CostData: Sendable, Equatable {
    public let daily: [DailyCost]
    public let fetchedAt: Date

    public init(daily: [DailyCost], fetchedAt: Date = .now) {
        self.daily = daily
        self.fetchedAt = fetchedAt
    }

    public var costToday: Double {
        guard let today = daily.last else { return 0 }
        let todayStr = Self.dateString(for: .now)
        return today.date == todayStr ? today.totalCost : 0
    }

    public var costLast30Days: Double {
        daily.reduce(0) { $0 + $1.totalCost }
    }

    private static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

public struct DailyCost: Sendable, Equatable {
    public let date: String
    public let totalTokens: Int
    public let totalCost: Double
    public let inputCost: Double
    public let outputCost: Double
    public let cacheReadCost: Double
    public let cacheWriteCost: Double

    public init(
        date: String,
        totalTokens: Int,
        totalCost: Double,
        inputCost: Double,
        outputCost: Double,
        cacheReadCost: Double,
        cacheWriteCost: Double
    ) {
        self.date = date
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.inputCost = inputCost
        self.outputCost = outputCost
        self.cacheReadCost = cacheReadCost
        self.cacheWriteCost = cacheWriteCost
    }
}

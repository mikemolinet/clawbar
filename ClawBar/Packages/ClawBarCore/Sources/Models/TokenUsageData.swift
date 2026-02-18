import Foundation

public struct TokenUsageData: Sendable, Equatable {
    public let daily: [DailyTokenUsage]
    public let fetchedAt: Date

    public init(daily: [DailyTokenUsage], fetchedAt: Date = .now) {
        self.daily = daily
        self.fetchedAt = fetchedAt
    }

    public var today: DailyTokenUsage? {
        let todayStr = Self.dateString(for: .now)
        return daily.first { $0.date == todayStr }
    }

    public var totalInput: Int {
        daily.reduce(0) { $0 + $1.combinedInput }
    }

    public var totalOutput: Int {
        daily.reduce(0) { $0 + $1.output }
    }

    public var totalTokens: Int {
        daily.reduce(0) { $0 + $1.totalTokens }
    }

    private static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

public struct DailyTokenUsage: Sendable, Equatable {
    public let date: String
    public let input: Int
    public let output: Int
    public let cacheRead: Int
    public let cacheWrite: Int
    public let totalTokens: Int

    public init(date: String, input: Int, output: Int, cacheRead: Int, cacheWrite: Int, totalTokens: Int) {
        self.date = date
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.totalTokens = totalTokens
    }

    /// Input + cache read + cache write (all tokens sent to the model)
    public var combinedInput: Int {
        input + cacheRead + cacheWrite
    }
}

public enum TokenFormatting {
    public static func format(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

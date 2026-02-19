import Foundation

public protocol ClaudeUsageProviding: Sendable {
    func fetchUsage() async throws -> ClaudeUsage
}

public final class ClaudeUsagePoller: ClaudeUsageProviding, Sendable {
    private let keychainReader: KeychainReading
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let betaHeader = "oauth-2025-04-20"

    public init(keychainReader: KeychainReading = KeychainReader()) {
        self.keychainReader = keychainReader
    }

    public func fetchUsage() async throws -> ClaudeUsage {
        let credentials = try keychainReader.readClaudeCredentials()
        if credentials.isExpired {
            throw ClawBarError.claudeTokenExpired
        }
        return try await fetchWithToken(credentials.accessToken)
    }

    private func fetchWithToken(_ token: String) async throws -> ClaudeUsage {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("ClawBar/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClawBarError.claudeAPIError(statusCode: 0, message: "Invalid response")
        }

        switch http.statusCode {
        case 200:
            return try parseUsageResponse(data)
        case 401:
            throw ClawBarError.claudeTokenExpired
        default:
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClawBarError.claudeAPIError(statusCode: http.statusCode, message: body)
        }
    }

    private func parseUsageResponse(_ data: Data) throws -> ClaudeUsage {
        let json = try JSONDecoder().decode(UsageAPIResponse.self, from: data)

        return ClaudeUsage(
            session: json.fiveHour.map { parseWindow($0) },
            weekly: json.sevenDay.map { parseWindow($0) },
            weeklyOAuthApps: json.sevenDayOauthApps.map { parseWindow($0) },
            weeklySonnet: json.sevenDaySonnet.map { parseWindow($0) },
            extraUsage: json.extraUsage.map { parseExtra($0) },
            fetchedAt: .now
        )
    }

    private func parseWindow(_ window: UsageWindowResponse) -> UsageWindow {
        UsageWindow(
            utilization: window.utilization ?? 0,
            resetsAt: parseISO8601(window.resetsAt)
        )
    }

    private func parseExtra(_ extra: ExtraUsageResponse) -> ExtraUsage {
        ExtraUsage(
            isEnabled: extra.isEnabled ?? false,
            monthlyLimit: extra.monthlyLimit,
            usedCredits: extra.usedCredits ?? 0,
            utilization: extra.utilization,
            currency: extra.currency
        )
    }

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - API Response Types

private struct UsageAPIResponse: Decodable {
    let fiveHour: UsageWindowResponse?
    let sevenDay: UsageWindowResponse?
    let sevenDayOauthApps: UsageWindowResponse?
    let sevenDaySonnet: UsageWindowResponse?
    let extraUsage: ExtraUsageResponse?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }
}

private struct UsageWindowResponse: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

private struct ExtraUsageResponse: Decodable {
    let isEnabled: Bool?
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
        case currency
    }
}

import Foundation
import Security

public protocol KeychainReading: Sendable {
    func readClaudeCredentials() throws -> ClaudeCredentials
}

public struct KeychainReader: KeychainReading, Sendable {
    public init() {}

    public func readClaudeCredentials() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw ClawBarError.claudeCredentialsNotFound
        }

        return try parseCredentials(data)
    }

    private func parseCredentials(_ data: Data) throws -> ClaudeCredentials {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String,
              let expiresAtMs = oauth["expiresAt"] as? Double
        else {
            throw ClawBarError.claudeParseError("Unexpected credential format")
        }

        let expiresAt = Date(timeIntervalSince1970: expiresAtMs / 1000)
        let subscriptionType = oauth["subscriptionType"] as? String
        let rateLimitTier = oauth["rateLimitTier"] as? String

        return ClaudeCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            subscriptionType: subscriptionType,
            rateLimitTier: rateLimitTier
        )
    }
}

import Foundation

public enum ClawBarError: LocalizedError, Sendable {
    // Claude
    case claudeCredentialsNotFound
    case claudeTokenExpired
    case claudeTokenRefreshFailed(String)
    case claudeAPIError(statusCode: Int, message: String)
    case claudeParseError(String)

    // OpenClaw
    case openClawNotRunning
    case openClawAuthFailed(String)
    case openClawNotPaired
    case openClawConfigNotFound

    // General
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .claudeCredentialsNotFound:
            "Claude Code credentials not found in Keychain"
        case .claudeTokenExpired:
            "Claude OAuth token expired — re-authenticate in Claude Code"
        case .claudeTokenRefreshFailed(let msg):
            "Token refresh failed: \(msg)"
        case .claudeAPIError(let code, let msg):
            "Claude API error (\(code)): \(msg)"
        case .claudeParseError(let msg):
            "Failed to parse Claude credentials: \(msg)"
        case .openClawNotRunning:
            "OpenClaw is not running"
        case .openClawAuthFailed(let msg):
            "OpenClaw auth failed: \(msg)"
        case .openClawNotPaired:
            "Device not paired with OpenClaw"
        case .openClawConfigNotFound:
            "OpenClaw config not found"
        case .networkError(let msg):
            "Network error: \(msg)"
        }
    }
}

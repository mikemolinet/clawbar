import Foundation

public enum ConnectionStatus: Sendable, Equatable {
    case disconnected
    case connecting
    case waitingForApproval
    case connected
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var displayText: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .waitingForApproval: "Waiting for approval..."
        case .connected: "Connected"
        case .error(let msg): "Error: \(msg)"
        }
    }
}

public enum ClaudeConnectionStatus: Sendable, Equatable {
    case unknown
    case available
    case credentialsNotFound
    case tokenExpired
    case error(String)

    public var displayText: String {
        switch self {
        case .unknown: "Checking..."
        case .available: "Connected"
        case .credentialsNotFound: "Claude Code not found"
        case .tokenExpired: "Re-authenticate in Claude Code"
        case .error(let msg): "Error: \(msg)"
        }
    }
}

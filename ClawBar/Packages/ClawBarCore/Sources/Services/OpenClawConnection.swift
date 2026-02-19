import CryptoKit
import Foundation

public actor OpenClawConnection {
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var identity: DeviceIdentity?
    private var port: Int
    private var gatewayToken: String?
    private var backoff: TimeInterval = 1.0
    private var reconnectTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var sessionPollTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var isRunning = false
    private var isConnected = false
    private var requestCounter = 0
    private let onUpdate: @Sendable (OpenClawEvent) async -> Void

    public enum OpenClawEvent: Sendable {
        case connected
        case disconnected
        case waitingForApproval
        case authFailed(String)
        case sessionsUpdate([OpenClawContext])
        case tokenUsageUpdate(TokenUsageData)
        case compactionStarted
        case compactionEnded
    }

    public init(port: Int = 18789, gatewayToken: String? = nil, onUpdate: @escaping @Sendable (OpenClawEvent) async -> Void) {
        self.port = port
        self.gatewayToken = gatewayToken
        self.onUpdate = onUpdate
    }

    public func updateConfig(port: Int, gatewayToken: String?) {
        let changed = port != self.port || gatewayToken != self.gatewayToken
        self.port = port
        self.gatewayToken = gatewayToken
        if changed && isRunning {
            Task { await reconnect() }
        }
    }

    public func start() async {
        isRunning = true
        await connect()
    }

    public func stop() {
        isRunning = false
        isConnected = false
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        sessionPollTask?.cancel()
        sessionPollTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    // MARK: - Connection

    private func connect() async {
        guard isRunning else { return }

        do {
            identity = try DeviceIdentityManager.loadOrCreate()
        } catch {
            await onUpdate(.authFailed("Failed to create device identity: \(error.localizedDescription)"))
            return
        }

        let url = URL(string: "ws://localhost:\(port)/ws")!
        var request = URLRequest(url: url)
        request.setValue("http://localhost:\(port)", forHTTPHeaderField: "Origin")
        urlSession?.invalidateAndCancel()
        let session = URLSession(configuration: .default)
        urlSession = session
        let ws = session.webSocketTask(with: request)
        webSocket = ws
        ws.resume()

        receiveTask = Task {
            await self.receiveLoop()
        }
    }

    private func receiveLoop() async {
        guard let ws = webSocket else { return }

        while isRunning && !Task.isCancelled {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    await handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                guard isRunning else { return }
                isConnected = false
                await onUpdate(.disconnected)
                scheduleReconnect()
                return
            }
        }
    }

    // MARK: - Message Handling

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let type = json["type"] as? String

        if type == "event" {
            let event = json["event"] as? String

            if event == "connect.challenge" {
                let payload = json["payload"] as? [String: Any]
                let nonce = payload?["nonce"] as? String ?? ""
                await handleChallenge(nonce: nonce)
            }
            // Compaction events
            if let eventData = json["data"] as? [String: Any],
               let stream = eventData["stream"] as? String,
               stream == "compaction" {
                let phase = eventData["phase"] as? String
                if phase == "start" {
                    await onUpdate(.compactionStarted)
                } else if phase == "end" {
                    await onUpdate(.compactionEnded)
                }
            }
        } else if type == "res" {
            let ok = json["ok"] as? Bool ?? false
            let payload = json["payload"] as? [String: Any]

            if let helloType = payload?["type"] as? String, helloType == "hello-ok" {
                // Connect response
                if ok {
                    backoff = 1.0
                    isConnected = true
                    await onUpdate(.connected)
                    startSessionPolling()
                } else {
                    let errorMsg = (json["error"] as? [String: Any])?["message"] as? String ?? "Connection rejected"
                    await onUpdate(.authFailed(errorMsg))
                    scheduleReconnect()
                }
            } else if ok, let sessions = payload?["sessions"] as? [[String: Any]] {
                // sessions.list response
                handleSessionsResponse(sessions)
            } else if ok, let dailyArr = payload?["daily"] as? [[String: Any]] {
                // usage.cost response — token counts across all agents
                handleTokenUsageResponse(dailyArr)
            }
        }
    }

    // MARK: - Challenge Response

    private func handleChallenge(nonce: String) async {
        guard let identity, let ws = webSocket else { return }

        let timestamp = Int64(Date.now.timeIntervalSince1970 * 1000)
        let signingMessage = identity.buildSigningMessage(
            nonce: nonce,
            timestamp: timestamp,
            token: gatewayToken
        )

        guard let signature = try? identity.sign(signingMessage) else {
            await onUpdate(.authFailed("Failed to sign challenge"))
            return
        }

        var connectParams: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "openclaw-macos",
                "version": "1.0.0",
                "platform": "macOS",
                "mode": "webchat",
            ] as [String: Any],
            "role": "operator",
            "scopes": ["operator.admin", "operator.approvals", "operator.pairing"],
            "device": [
                "id": identity.deviceId,
                "publicKey": identity.publicKeyBase64,
                "signature": signature,
                "signedAt": timestamp,
                "nonce": nonce,
            ] as [String: Any],
            "caps": [] as [String],
        ]

        if let token = gatewayToken {
            connectParams["auth"] = ["token": token] as [String: Any]
        }

        let request: [String: Any] = [
            "type": "req",
            "id": nextRequestId(),
            "method": "connect",
            "params": connectParams,
        ]

        await send(request)
    }

    // MARK: - Session Polling

    private func startSessionPolling() {
        sessionPollTask?.cancel()
        sessionPollTask = Task {
            while self.isRunning, !Task.isCancelled {
                await self.requestSessionsList()
                try? await Task.sleep(for: .seconds(15), tolerance: .seconds(2))
            }
        }
        startPingLoop()
    }

    private var tokenPollCounter = 0

    private func requestSessionsList() async {
        let request: [String: Any] = [
            "type": "req",
            "id": nextRequestId(),
            "method": "sessions.list",
            "params": [:] as [String: Any],
        ]
        await send(request)

        // Fetch token usage less frequently (every 6th poll = ~30s)
        tokenPollCounter += 1
        if tokenPollCounter % 6 == 1 {
            let costRequest: [String: Any] = [
                "type": "req",
                "id": nextRequestId(),
                "method": "usage.cost",
                "params": [:] as [String: Any],
            ]
            await send(costRequest)
        }
    }

    private func handleSessionsResponse(_ sessions: [[String: Any]]) {
        var contexts: [OpenClawContext] = []

        for session in sessions {
            let kind = session["kind"] as? String ?? ""
            guard kind == "direct" else { continue }

            let key = session["key"] as? String ?? ""
            if key.contains("subagent") || key.contains("cron:") { continue }

            guard let totalTokens = session["totalTokens"] as? Int,
                  let contextTokens = session["contextTokens"] as? Int,
                  contextTokens > 0, totalTokens > 0
            else { continue }

            let sessionName = extractSessionName(from: key)
            let compactionCount = session["compactionCount"] as? Int ?? 0

            contexts.append(OpenClawContext(
                sessionName: sessionName,
                totalTokens: totalTokens,
                contextWindow: contextTokens,
                compactionCount: compactionCount,
                isCompacting: false
            ))
        }

        // Sort by percent used descending (highest usage first)
        contexts.sort { $0.percentUsed > $1.percentUsed }

        Task {
            await onUpdate(.sessionsUpdate(contexts))
        }
    }

    private func handleTokenUsageResponse(_ dailyArr: [[String: Any]]) {
        let usage = dailyArr.compactMap { day -> DailyTokenUsage? in
            guard let date = day["date"] as? String else { return nil }
            return DailyTokenUsage(
                date: date,
                input: day["input"] as? Int ?? 0,
                output: day["output"] as? Int ?? 0,
                cacheRead: day["cacheRead"] as? Int ?? 0,
                cacheWrite: day["cacheWrite"] as? Int ?? 0,
                totalTokens: day["totalTokens"] as? Int ?? 0
            )
        }
        Task {
            await onUpdate(.tokenUsageUpdate(TokenUsageData(daily: usage)))
        }
    }

    // handleSessionsUsageResponse removed — usage.cost now aggregates all agents server-side

    private func extractSessionName(from key: String) -> String {
        let parts = key.split(separator: ":")
        if parts.count >= 3 {
            return String(parts[2])
        } else if parts.count >= 2 {
            return String(parts[1])
        }
        return key
    }

    // MARK: - WebSocket Keepalive

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task {
            while self.isRunning, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30), tolerance: .seconds(5))
                guard self.isRunning, !Task.isCancelled, let ws = self.webSocket else { continue }
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        ws.sendPing { error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                } catch {
                    guard self.isRunning else { return }
                    self.isConnected = false
                    await self.onUpdate(.disconnected)
                    self.scheduleReconnect()
                    return
                }
            }
        }
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard isRunning else { return }
        reconnectTask?.cancel()
        let delay = backoff * Double.random(in: 0.8...1.2)
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, isRunning else { return }
            backoff = min(backoff * 2, 30)
            await connect()
        }
    }

    private func reconnect() async {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        receiveTask?.cancel()
        sessionPollTask?.cancel()
        pingTask?.cancel()
        isConnected = false
        backoff = 1.0
        await connect()
    }

    // MARK: - Helpers

    private func send(_ dict: [String: Any]) async {
        guard let ws = webSocket,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8)
        else { return }

        try? await ws.send(.string(string))
    }

    private func nextRequestId() -> String {
        requestCounter += 1
        return "clawbar-\(requestCounter)"
    }
}

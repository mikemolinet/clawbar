import Foundation

@MainActor
public final class AppCoordinator {
    public let state: AppState
    private let claudePoller: ClaudeUsageProviding
    private let notificationManager = NotificationManager()
    private var pollTask: Task<Void, Never>?
    private var openClawConnection: OpenClawConnection?
    private var configWatcherSource: DispatchSourceFileSystemObject?
    private let pollInterval: TimeInterval = 60

    public init(
        state: AppState,
        claudePoller: ClaudeUsageProviding = ClaudeUsagePoller()
    ) {
        self.state = state
        self.claudePoller = claudePoller
    }

    public func start() {
        startClaudePolling()
        startOpenClawConnection()
        watchConfigFile()
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        Task {
            await openClawConnection?.stop()
        }
        configWatcherSource?.cancel()
        configWatcherSource = nil
    }

    // MARK: - Claude Polling

    private func startClaudePolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollClaude()
                try? await Task.sleep(for: .seconds(self.pollInterval), tolerance: .seconds(5))
            }
        }
    }

    private func pollClaude() async {
        do {
            let usage = try await claudePoller.fetchUsage()
            state.claudeUsage = usage
            state.claudeStatus = .available
            state.lastClaudeUpdate = .now
            notificationManager.checkClaudeUsage(usage)
        } catch let error as ClawBarError {
            switch error {
            case .claudeCredentialsNotFound:
                state.claudeStatus = .credentialsNotFound
            case .claudeTokenExpired:
                state.claudeStatus = .tokenExpired
            default:
                state.claudeStatus = .error(error.localizedDescription)
            }
        } catch {
            state.claudeStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - OpenClaw Connection

    private func startOpenClawConnection() {
        let config = ConfigReader.readConfig()
        state.openClawStatus = .connecting

        let connection = OpenClawConnection(port: config.port, gatewayToken: config.gatewayToken) { [weak self] event in
            await MainActor.run {
                self?.handleOpenClawEvent(event)
            }
        }
        openClawConnection = connection

        Task {
            await connection.start()
        }
    }

    private func handleOpenClawEvent(_ event: OpenClawConnection.OpenClawEvent) {
        switch event {
        case .connected:
            state.openClawStatus = .connected
        case .disconnected:
            state.openClawStatus = .disconnected
        case .waitingForApproval:
            state.openClawStatus = .waitingForApproval
        case .authFailed(let msg):
            state.openClawStatus = .error(msg)
        case .sessionsUpdate(let sessions):
            state.openClawSessions = sessions
            state.openClawStatus = .connected
            state.lastOpenClawUpdate = .now
            notificationManager.checkOpenClawSessions(sessions)
        case .tokenUsageUpdate(let tokenUsage):
            state.tokenUsage = tokenUsage
        case .compactionStarted:
            break // Will be reflected in next sessions poll
        case .compactionEnded:
            break // Will be reflected in next sessions poll
        }
    }

    // MARK: - Config File Watching

    private func watchConfigFile() {
        let configPath = NSString("~/.openclaw/openclaw.json").expandingTildeInPath
        guard let fd = open(configPath, O_EVTONLY) as Int32?,
              fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let newConfig = ConfigReader.readConfig()
            Task {
                await self.openClawConnection?.updateConfig(port: newConfig.port, gatewayToken: newConfig.gatewayToken)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        configWatcherSource = source
    }

    /// Force an immediate refresh (e.g., on wake from sleep)
    public func refreshNow() {
        Task {
            await pollClaude()
        }
        // OpenClaw reconnects automatically via WS
    }
}

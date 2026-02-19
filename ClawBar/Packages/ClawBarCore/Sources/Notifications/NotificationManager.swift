import Foundation
import UserNotifications

@MainActor
public final class NotificationManager {
    private var lastClaudeSessionPercent: Double?
    private var lastClaudeWeeklyPercent: Double?
    private var lastSessionPercents: [String: Double] = [:]  // per-session tracking
    private var cooldowns: [String: Date] = [:]
    private let cooldownInterval: TimeInterval = 900 // 15 minutes
    public var soundsEnabled: Bool = true
    public var contextApproachingEnabled: Bool = true
    public var contextCompactedEnabled: Bool = true
    public var claudeSessionEnabled: Bool = true

    // Notification thread IDs for grouping
    private static let claudeThread = "claude-usage"
    private static let openClawThread = "openclaw-context"

    public init() {
        requestPermission()
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Update Checks

    public func checkClaudeUsage(_ usage: ClaudeUsage) {
        let sessionPercent = usage.session?.percentUsed ?? 0
        let weeklyPercent = usage.weekly?.percentUsed ?? 0

        if claudeSessionEnabled {
            // Session depleted
            if sessionPercent >= 100, (lastClaudeSessionPercent ?? 0) < 100 {
                let resetText = TimeFormatting.relativeReset(usage.session?.resetsAt) ?? "soon"
                notify(
                    id: "claude-session-depleted",
                    title: "Claude session limit reached",
                    body: "\(resetText)",
                    thread: Self.claudeThread,
                    sound: true
                )
            }

            // Session restored
            if sessionPercent < 100, (lastClaudeSessionPercent ?? 0) >= 100 {
                notify(
                    id: "claude-session-restored",
                    title: "Claude session available again",
                    body: "Session quota has reset",
                    thread: Self.claudeThread,
                    sound: true
                )
            }

            // Session high (90%)
            if sessionPercent >= 90, (lastClaudeSessionPercent ?? 0) < 90 {
                notify(
                    id: "claude-session-high",
                    title: "Claude session at \(Int(sessionPercent))%",
                    body: "Approaching session limit",
                    thread: Self.claudeThread
                )
            }

            // Weekly high (80%)
            if weeklyPercent >= 80, (lastClaudeWeeklyPercent ?? 0) < 80 {
                notify(
                    id: "claude-weekly-high",
                    title: "Claude weekly usage at \(Int(weeklyPercent))%",
                    body: "Approaching weekly limit",
                    thread: Self.claudeThread
                )
            }
        }

        lastClaudeSessionPercent = sessionPercent
        lastClaudeWeeklyPercent = weeklyPercent
    }

    public func checkOpenClawSessions(_ sessions: [OpenClawContext]) {
        for session in sessions {
            let name = session.sessionName
            let percent = session.percentUsed
            let lastPercent = lastSessionPercents[name] ?? 0

            // Compaction detected — large sudden drop for THIS session
            if contextCompactedEnabled, lastPercent >= 70, percent < 30 {
                notify(
                    id: "openclaw-compacted-\(name)",
                    title: "\(name) — context compacted",
                    body: "Dropped from \(Int(lastPercent))% → \(Int(percent))% (\(session.formattedTokens))",
                    thread: Self.openClawThread
                )
            }
            // Context critical (85%) — about to compact at 90%
            else if contextApproachingEnabled, percent >= 85, lastPercent < 85 {
                notify(
                    id: "openclaw-critical-\(name)",
                    title: "\(name) — compaction imminent",
                    body: "Context at \(Int(percent))% (\(session.formattedTokens))",
                    thread: Self.openClawThread,
                    sound: true
                )
            }
            // Context high (75%) — compaction coming
            else if contextApproachingEnabled, percent >= 75, lastPercent < 75 {
                notify(
                    id: "openclaw-high-\(name)",
                    title: "\(name) — compaction at 90%",
                    body: "Context at \(Int(percent))% (\(session.formattedTokens))",
                    thread: Self.openClawThread
                )
            }

            lastSessionPercents[name] = percent
        }

        // Clean up sessions that disappeared
        let activeNames = Set(sessions.map(\.sessionName))
        lastSessionPercents = lastSessionPercents.filter { activeNames.contains($0.key) }
    }

    // MARK: - Send Notification

    private func notify(id: String, title: String, body: String, thread: String, sound: Bool = false) {
        // Cooldown check
        if let lastFired = cooldowns[id], Date.now.timeIntervalSince(lastFired) < cooldownInterval {
            return
        }
        cooldowns[id] = .now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.threadIdentifier = thread
        if sound, soundsEnabled {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "\(id)-\(Int(Date.now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

import Foundation
import UserNotifications

@MainActor
public final class NotificationManager {
    private var lastClaudeSessionPercent: Double?
    private var lastClaudeWeeklyPercent: Double?
    private var lastOpenClawMaxPercent: Double?
    private var cooldowns: [String: Date] = [:]
    private let cooldownInterval: TimeInterval = 900 // 15 minutes

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

        lastClaudeSessionPercent = sessionPercent
        lastClaudeWeeklyPercent = weeklyPercent
    }

    public func checkOpenClawSessions(_ sessions: [OpenClawContext]) {
        guard let maxPercent = sessions.map(\.percentUsed).max() else { return }

        // Context critical (95%)
        if maxPercent >= 95, (lastOpenClawMaxPercent ?? 0) < 95 {
            let session = sessions.first { $0.percentUsed >= 95 }
            notify(
                id: "openclaw-context-critical",
                title: "Context at \(Int(maxPercent))% — compaction imminent",
                body: session.map { "\($0.sessionName): \($0.formattedTokens)" } ?? "",
                thread: Self.openClawThread,
                sound: true
            )
        }
        // Context high (80%)
        else if maxPercent >= 80, (lastOpenClawMaxPercent ?? 0) < 80 {
            let session = sessions.first { $0.percentUsed >= 80 }
            notify(
                id: "openclaw-context-high",
                title: "Context at \(Int(maxPercent))% — compaction soon",
                body: session.map { "\($0.sessionName): \($0.formattedTokens)" } ?? "",
                thread: Self.openClawThread
            )
        }

        lastOpenClawMaxPercent = maxPercent
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
        if sound {
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

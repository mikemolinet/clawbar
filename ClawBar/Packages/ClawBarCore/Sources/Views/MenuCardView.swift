import SwiftUI

public struct MenuCardView: View {
    @Bindable var state: AppState
    var onShowAllSessions: (() -> Void)?

    public init(state: AppState, onShowAllSessions: (() -> Void)? = nil) {
        self.state = state
        self.onShowAllSessions = onShowAllSessions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OpenClawCard(
                sessions: state.openClawSessions,
                status: state.openClawStatus,
                showUsed: state.showUsed,
                lastUpdate: state.lastOpenClawUpdate,
                onShowAll: onShowAllSessions
            )

            Divider()
                .padding(.horizontal, 14)

            ClaudeUsageCard(
                usage: state.claudeUsage,
                status: state.claudeStatus,
                showUsed: state.showUsed,
                lastUpdate: state.lastClaudeUpdate
            )

            if state.tokenUsage != nil || state.openClawStatus.isConnected {
                Divider()
                    .padding(.horizontal, 14)

                TokenUsageCard(tokenUsage: state.tokenUsage)
            }
        }
    }
}

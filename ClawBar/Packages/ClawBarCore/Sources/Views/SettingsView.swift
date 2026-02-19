import ServiceManagement
import SwiftUI

public struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Bindable var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }

            connectionsTab
                .tabItem { Label("Connections", systemImage: "network") }
        }
        .frame(width: 360, height: 360)
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue // revert
                        }
                    }
            }

            Section("Display") {
                Picker("Progress bars show", selection: $state.showUsed) {
                    Text("% used").tag(true)
                    Text("% remaining").tag(false)
                }
                .pickerStyle(.segmented)
            }

        }
        .formStyle(.grouped)
        .padding()
    }

    private var notificationsTab: some View {
        Form {
            Section("Context Window") {
                Toggle("Approaching compaction", isOn: $state.notifyContextApproaching)
                Text("Alerts at 75% and 85% context usage")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Toggle("Compaction completed", isOn: $state.notifyContextCompacted)
                Text("When context is compacted and drops")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Claude Limits") {
                Toggle("Session & weekly warnings", isOn: $state.notifyClaudeSession)
                Text("Session at 90%, weekly at 80%, depleted, and restored")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Sound") {
                Toggle("Notification sounds", isOn: $state.soundsEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var connectionsTab: some View {
        Form {
            Section("OpenClaw") {
                LabeledContent("Status", value: state.openClawStatus.displayText)
                LabeledContent("Sessions", value: "\(state.openClawSessions.count) active")
            }

            Section {
                LabeledContent("Status", value: state.claudeStatus.displayText)
                if let usage = state.claudeUsage {
                    if let session = usage.session {
                        LabeledContent("Session", value: String(format: "%.0f%% used", session.percentUsed))
                    }
                    if let weekly = usage.weekly {
                        LabeledContent("Weekly", value: String(format: "%.0f%% used", weekly.percentUsed))
                    }
                }
                if state.claudeStatus == .tokenExpired || state.claudeStatus == .credentialsNotFound {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("To fix this, open Terminal and run:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("claude auth login")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Text("Claude")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

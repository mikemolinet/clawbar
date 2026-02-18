# ClawBar

A macOS menu bar app for monitoring [OpenClaw](https://github.com/openclaw/openclaw) context usage and [Claude](https://claude.ai) rate limits at a glance.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![Zero Dependencies](https://img.shields.io/badge/dependencies-0-green)

## What It Does

**Dual progress bar in your menu bar** — top bar shows OpenClaw context window usage, bottom bar shows Claude session utilization.

### OpenClaw Context Monitoring
- Real-time context window usage for all active agent sessions
- Per-session breakdown with token counts
- 90% compaction threshold marker on progress bars
- Compaction detection notifications (before and after)

### Claude Usage Tracking
- Session (5h) and weekly (7d) utilization with progress bars
- Reset countdown timers
- Overage tracking (if enabled)

### Notifications
- **75%** context: "Compaction at 90%" warning
- **85%** context: "Compaction imminent" (with sound)
- **Post-compaction**: Detects the drop, shows before/after percentages
- **90%** Claude session: Approaching limit
- **100%** Claude session: Depleted (with sound) + restored alert
- **80%** Claude weekly: Approaching limit
- All notifications are per-session with 15-minute cooldowns
- Sounds can be toggled in Settings

### Token Usage
- Today and last 30 days input/output token breakdown

## Requirements

- **macOS 14 (Sonoma)** or later
- One or both of:
  - **[OpenClaw](https://github.com/openclaw/openclaw)** running locally (for context monitoring)
  - **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** installed (for Claude usage tracking)

ClawBar works with either or both — sections gracefully show status messages when a service isn't available.

## Install

### From DMG
1. Download `ClawBar.dmg` from [Releases](../../releases)
2. Open the DMG and drag ClawBar to Applications
3. Launch ClawBar — it appears in your menu bar
4. Since it's not code-signed, you may need to right-click → Open the first time (or allow it in System Settings → Privacy & Security)

### From Source
```bash
# Requires Xcode 16+ and XcodeGen
brew install xcodegen
git clone https://github.com/mikemolinet/clawbar.git
cd clawbar
xcodegen generate
xcodebuild -scheme ClawBar -configuration Release build SYMROOT=build
open build/Release/ClawBar.app
```

## How It Works

### OpenClaw Connection
- Connects to local OpenClaw gateway via WebSocket
- Ed25519 device authentication (keypair stored in Keychain)
- First launch: ClawBar appears as a pending device in OpenClaw — approve it to connect
- Polls `sessions.list` every 5s for real-time context data
- Auto-reconnects on disconnect, watches config file for changes

### Claude Usage
- Reads OAuth token from the `Claude Code-credentials` Keychain entry (created by Claude Code)
- Polls `api.anthropic.com/api/oauth/usage` every 60s
- No API key needed — uses your existing Claude Code authentication

## Settings

Open via the menu bar dropdown → **Settings...** (⌘,)

- **Launch at login** — start ClawBar automatically
- **Progress bar display** — show "% used" or "% remaining"
- **Notification sounds** — toggle alert sounds on/off
- **Connections tab** — see status of OpenClaw and Claude connections

## Architecture

Pure Swift, zero external dependencies. Apple frameworks only.

```
ClawBar/
├── ClawBar/                    # Xcode app wrapper (entitlements, Info.plist)
├── Packages/ClawBarCore/       # SPM package with all logic
│   └── Sources/
│       ├── App/                # App entry point
│       ├── MenuBar/            # NSStatusItem, icon rendering
│       ├── Models/             # Data types
│       ├── Notifications/      # UNUserNotification management
│       ├── Services/           # WS connection, REST poller, Keychain, config
│       ├── State/              # @Observable AppState + AppCoordinator
│       └── Views/              # SwiftUI views (cards, settings, all-sessions)
└── project.yml                 # XcodeGen spec
```

## License

MIT

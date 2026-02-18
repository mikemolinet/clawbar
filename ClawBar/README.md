<p align="center">
  <h1 align="center">🦞 ClawBar</h1>
  <p align="center">
    Menu bar companion for <a href="https://github.com/openclaw/openclaw">OpenClaw</a> and <a href="https://claude.ai">Claude</a>
    <br />
    Monitor context windows, usage limits, and token consumption — all from your menu bar.
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/Swift-6-orange?style=flat-square" />
  <img src="https://img.shields.io/badge/dependencies-0-green?style=flat-square" />
</p>

---

## What It Does

ClawBar lives in your menu bar with a **dual progress bar icon** — the top bar shows your OpenClaw context usage, the bottom shows your Claude session utilization. Click it to see the full picture.

### 🦞 OpenClaw Context
- **Real-time context window usage** for every active agent session
- Per-session token counts and compaction history
- **90% compaction threshold marker** on progress bars so you know when compaction will trigger
- Supports multiple concurrent sessions (main, engineering, scheduling, etc.)

### 🔶 Claude Usage
- **Session (5h)** and **weekly (7d)** utilization with progress bars
- Reset countdown timers
- Overage tracking if you have it enabled

### 🔔 Smart Notifications
All notifications are **per-session** — if engineering hits 75%, you'll still get notified when main hits 75% too.

| Event | Alert | Sound |
|-------|-------|-------|
| Context at 75% | "Compaction at 90%" | — |
| Context at 85% | "Compaction imminent" | 🔊 |
| Context compacted | Shows before → after % | — |
| Claude session at 90% | "Approaching limit" | — |
| Claude session depleted | "Limit reached" + reset time | 🔊 |
| Claude session restored | "Available again" | 🔊 |
| Claude weekly at 80% | "Approaching weekly limit" | — |

15-minute cooldown per alert type per session. Sounds can be toggled off in Settings.

### 📊 Token Usage
- Today and last 30 days with input/output breakdown

---

## Install

### Option 1: Download (Recommended)

1. Download **ClawBar.dmg** from the [latest release](../../releases/latest)
2. Open the DMG and drag **ClawBar** to your **Applications** folder
3. Launch ClawBar

> **First launch:** Since ClawBar isn't code-signed with an Apple Developer certificate, macOS will block it.
> Go to **System Settings → Privacy & Security**, scroll down, and click **"Open Anyway"** next to the ClawBar message.
> You only need to do this once.

### Option 2: Build from Source

```bash
# Install XcodeGen (one-time)
brew install xcodegen

# Clone and build
git clone https://github.com/mikemolinet/clawbar.git
cd clawbar
xcodegen generate
xcodebuild -scheme ClawBar -configuration Release build SYMROOT=build

# Run it
open build/Release/ClawBar.app
```

Requires **Xcode 16+** and **macOS 14 (Sonoma)** or later.

---

## Setup

ClawBar works with **OpenClaw**, **Claude Code**, or both. Each section shows a helpful status message when a service isn't available.

### OpenClaw (Context Monitoring)

**Requirement:** [OpenClaw](https://github.com/openclaw/openclaw) running locally.

1. Launch ClawBar — it automatically finds your OpenClaw gateway
2. On first connect, **ClawBar** will appear as a pending device in OpenClaw
3. Approve it: run `openclaw` and approve the "ClawBar" device, or approve it in the web dashboard
4. That's it — context data starts flowing immediately

ClawBar reads your gateway config from `~/.openclaw/openclaw.json` and auto-reconnects if the gateway restarts.

### Claude Code (Usage Tracking)

**Requirement:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated.

No setup needed — ClawBar reads the OAuth token from your Keychain automatically (the `Claude Code-credentials` entry created when you authenticate Claude Code). If you haven't authenticated yet, just run `claude` in your terminal and sign in.

---

## Settings

Open from the dropdown menu → **Settings...** (or ⌘,)

| Setting | What it does |
|---------|-------------|
| **Launch at login** | Start ClawBar automatically when you log in |
| **Progress bars show** | Toggle between "% used" and "% remaining" |
| **Notification sounds** | Turn alert sounds on or off |

The **Connections** tab shows live status for both OpenClaw and Claude.

---

## Architecture

Zero external dependencies. Pure Swift using only Apple frameworks.

```
Packages/ClawBarCore/Sources/
├── App/                # SwiftUI app entry point
├── MenuBar/            # NSStatusItem + dual-bar icon renderer
├── Models/             # Data types (context, usage, connection status)
├── Notifications/      # macOS notification management with cooldowns
├── Services/           # WebSocket connection, REST poller, Keychain reader
├── State/              # @Observable AppState + AppCoordinator
└── Views/              # SwiftUI cards, settings window, all-sessions panel
```

- **OpenClaw connection:** WebSocket to local gateway with Ed25519 device authentication via CryptoKit
- **Claude polling:** REST calls to `api.anthropic.com` using your existing OAuth token
- **State management:** Single `AppState` (@Observable) flows to all views via `AppCoordinator`

---

## FAQ

**Q: Do I need both OpenClaw and Claude Code?**
No. ClawBar works with either one or both. Sections gracefully show status messages when a service isn't available.

**Q: What's the 90% mark on the progress bar?**
OpenClaw compacts (summarizes) your conversation context when it reaches ~90% capacity. The marker shows you where that threshold is so the drop from 90% → ~10% isn't surprising.

**Q: Will ClawBar work with Claude.ai (browser)?**
It tracks usage for your Claude account overall, so yes — the session and weekly limits shown apply to both Claude Code and claude.ai usage.

**Q: How do I reset the device pairing?**
Delete the `com.vector.clawbar.device-identity` entry from Keychain Access and relaunch ClawBar.

---

## License

MIT

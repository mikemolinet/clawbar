# ClawBar — Build Spec v2

**Platform:** macOS 14+ (Sonoma)
**Language:** Swift 6 / SwiftUI + AppKit hybrid
**Build:** Xcode project wrapper + SPM core package

---

## Overview

Lightweight macOS menu bar app showing:
1. **OpenClaw context window usage** — real-time % used, compaction alerts
2. **Claude usage limits** — session (5h) and weekly (7d) utilization, reset countdowns, overage costs

Design inspired by [CodexBar](https://github.com/steipete/CodexBar). Ref implementation cloned at `/tmp/CodexBar/`.

---

## Data Sources

### 1. OpenClaw Context (WebSocket — real-time push)

**Connection:** `ws://localhost:{port}/ws`
**Port detection:** Read `~/.openclaw/openclaw.json` → `webchat.port` (default 18789)
**Auth:** Ed25519 device auth (CryptoKit `Curve25519.Signing`)

**Protocol:**
1. Connect to WS → receive `connect.challenge` with nonce
2. Sign: `v2|{deviceId}|openclaw-macos|webchat|operator|operator.admin,operator.approvals,operator.pairing|{timestamp}|{token}|{nonce}`
3. Send `connect` request with device ID, public key, signature
4. First launch: user approves device in OpenClaw dashboard (one-time)
5. Receive real-time session events with `contextWeight`, `totalTokens`, `compactionStatus`

**Key data:** context % used, context window size, compaction count, compaction in-progress, session/agent name

**Reconnection:** Exponential backoff (1s → 2s → 4s → max 30s) with jitter (±20%). Reset on success. Gate on `NWPathMonitor` (don't retry when offline). Ping every 30s to detect dead connections. Pause on sleep, reconnect on wake.

**Config file watching:** `DispatchSource.makeFileSystemObjectSource` on `~/.openclaw/openclaw.json` for port changes → immediate reconnect.

### 2. Claude Usage (REST — poll every 60s)

**Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`
**Auth:** Bearer token from `Claude Code-credentials` macOS Keychain entry
**Headers:** `anthropic-beta: oauth-2025-04-20`

**Response:**
```json
{
  "five_hour": { "utilization": 70.0, "resets_at": "ISO-8601" },
  "seven_day": { "utilization": 6.0, "resets_at": "ISO-8601" },
  "extra_usage": {
    "is_enabled": true,
    "monthly_limit": 200000,
    "used_credits": 12.50,
    "currency": "USD"
  }
}
```

**Token refresh:** Coalescing `TokenManager` actor — if multiple requests get 401, only one refresh executes. Read fresh from Keychain before each request (Claude Code CLI may also refresh). Handle parse failures gracefully (format may change).

**Key data:** Session % used + reset countdown, weekly % used + reset countdown, overage $ spent / $ limit, plan tier

**Pause polling on sleep, immediate poll on wake.**

---

## UI Design

### Menu Bar Icon

**Monochrome template icon** (`isTemplate = true`) — adapts to light/dark mode, accent colors, and accessibility settings. No colored icons in the menu bar.

**Design:** Dual-bar meter (CodexBar pattern):
- Top bar: OpenClaw context % (fills left-to-right)
- Bottom bar: Claude session % (fills left-to-right)
- 18×18pt rendered at 2× for Retina
- Pixel-grid snapping for crisp rendering

**States:**
- Normal: bars fill proportionally
- Loading (no data yet): animated loading pattern (CodexBar knight-rider style)
- Disconnected/error: dimmed icon
- One source unavailable: show the available bar, other bar empty/absent

**Icon caching:** Quantize percentages into buckets. Cache rendered `NSImage` in LRU cache (64 entries). Only redraw on bucket change, not every token update.

**No text mode in v1.** Icon-only.

### Dropdown Menu

Uses `NSHostingView` embedded in `NSMenuItem` entries (CodexBar pattern). **Separate NSMenuItems per section** to get proper hover/highlight behavior.

Each section implements highlight-aware styling via `@Environment(\.menuItemHighlighted)`.

```
┌──────────────────────────────────────┐
│  🦞 OpenClaw Context    ·  3s ago   │  ← header item (name + timestamp)
│  Session: main                       │
│  ████████████░░░░░░░░  58% used     │  ← progress bar with pace marker
│  116k / 200k tokens · 2 compactions │
├──────────────────────────────────────┤
│  ◆ Claude Pro/Max         ·  1m ago │  ← header item
│                                      │
│  Session (5h)                        │
│  ██████████████░░░░░░  70% used     │  ← bar + pace indicator
│  Resets in 1h 23m                    │
│                                      │
│  Weekly (7d)                         │
│  █░░░░░░░░░░░░░░░░░░░  6% used     │
│  Resets Feb 24                       │
│                                      │
│  Overage: $0.00 / $200,000          │
├──────────────────────────────────────┤
│  Settings...                    ⌘,   │  ← standard NSMenuItem
│  Quit ClawBar                   ⌘Q   │  ← standard NSMenuItem
└──────────────────────────────────────┘
```

**Progress bars:** Capsule style, single accent color per source (OpenClaw brand color, Anthropic coral). No red/green/yellow gradients. Fill level communicates urgency. Accessible: `accessibilityLabel` + `accessibilityValue` on every bar.

**Used vs remaining toggle:** User can flip between "58% used" and "42% remaining" in settings.

### Degraded States (independent data sources)

| OpenClaw | Claude | Dropdown shows |
|----------|--------|----------------|
| ✅ Connected | ✅ Available | Both sections |
| ✅ Connected | ❌ Not found | OpenClaw section + "Install Claude Code to see usage" |
| ❌ Not running | ✅ Available | Claude section + "Connect to OpenClaw" card |
| ❌ Not running | ❌ Not found | Full onboarding flow |

Error states show inline messages in the dropdown — **never modal dialogs**.

### First-Run / Onboarding

When no data sources are connected, dropdown shows an onboarding card:

**OpenClaw pairing flow:**
1. Auto-detect port from `~/.openclaw/openclaw.json`
2. Show connection status: "OpenClaw detected on port 18789"
3. "Pair Device" button → initiates Ed25519 handshake
4. Show "Waiting for approval..." with spinner + cancel button
5. Instruction: "Approve 'ClawBar' in your OpenClaw dashboard"
6. On approval: transition to connected state with data

**Claude credentials:**
- Auto-detected from Keychain on launch
- If not found: "Install Claude Code and sign in to see usage"
- Re-check on each poll cycle (user may install/auth Claude Code later)

### Notifications

macOS native via `UNUserNotificationCenter`. Grouped by `threadIdentifier` (openclaw / claude).

| Event | Default | Message |
|-------|---------|---------|
| Context high | 80% | "OpenClaw context at 80% — compaction soon" |
| Context critical | 95% | "Context at 95% — compaction imminent" |
| Compaction occurred | 1st only | "Context compacted" (suppress after 1st per session) |
| Claude session depleted | 100% | "Claude session limit reached — resets in Xh Xm" |
| Claude session restored | on event | "Claude session available again" ← **most important, enabled by default** |
| Claude weekly high | 80% | "Claude weekly usage at 80%" |

**Cooldown:** After firing a threshold notification, suppress same type for 15 minutes OR until usage drops below threshold and rises again. Prevents oscillation spam.

**All thresholds configurable. Per-type toggles. Master toggle.**

---

## Architecture

### Project Structure

```
ClawBar/
├── ClawBar.xcodeproj/                  ← signing, entitlements, assets, app target
├── ClawBar/                            ← app target resources
│   ├── Assets.xcassets
│   ├── Info.plist                      ← LSUIElement=true
│   └── ClawBar.entitlements            ← network.client, hardened runtime
│
├── Packages/
│   └── ClawBarCore/                    ← SPM package with ALL logic
│       ├── Package.swift
│       └── Sources/
│           ├── App/
│           │   ├── ClawBarApp.swift         ← @main, app lifecycle
│           │   └── AppDelegate.swift        ← NSStatusItem lifecycle
│           │
│           ├── MenuBar/
│           │   ├── StatusItemController.swift ← icon + menu management
│           │   ├── IconRenderer.swift         ← dual-bar drawing, caching
│           │   └── LoadingAnimation.swift     ← pre-data animation
│           │
│           ├── Views/
│           │   ├── MenuCardView.swift         ← dropdown card container
│           │   ├── OpenClawCard.swift         ← OpenClaw section
│           │   ├── ClaudeUsageCard.swift      ← Claude section
│           │   ├── OnboardingCard.swift       ← first-run pairing UI
│           │   ├── ContextProgressBar.swift   ← capsule bar + pace marker
│           │   └── SettingsView.swift         ← preferences window
│           │
│           ├── State/
│           │   ├── AppState.swift             ← @Observable, @MainActor, single source of truth
│           │   ├── AppCoordinator.swift       ← bridges services → state
│           │   └── AppSettings.swift          ← UserDefaults-backed prefs
│           │
│           ├── Services/
│           │   ├── OpenClawConnection.swift   ← WS client, reconnect, Ed25519 auth
│           │   ├── ClaudeUsagePoller.swift     ← REST polling
│           │   ├── TokenManager.swift          ← coalescing OAuth refresh
│           │   ├── KeychainReader.swift        ← protocol-based, read Claude creds
│           │   └── ConfigReader.swift          ← read openclaw.json, watch for changes
│           │
│           ├── Models/
│           │   ├── OpenClawContext.swift       ← Sendable struct
│           │   ├── ClaudeUsage.swift           ← Sendable struct
│           │   └── ConnectionStatus.swift      ← enum
│           │
│           ├── Notifications/
│           │   └── NotificationManager.swift   ← thresholds, cooldowns, grouping
│           │
│           └── Utilities/
│               ├── DeviceIdentity.swift        ← Ed25519 keypair gen/Keychain store
│               ├── TimeFormatting.swift         ← "resets in 1h 23m"
│               └── Errors.swift                ← AppError enum
│
└── README.md
```

### Data Flow

```
OpenClawConnection ──AsyncStream──→ AppCoordinator ──→ AppState ──→ Views
ClaudeUsagePoller  ──AsyncStream──→ AppCoordinator ──→ AppState ──→ Views
                                                   ↘ NotificationManager
                                                   ↘ IconRenderer
```

Services produce data. `AppCoordinator` bridges to `@MainActor`. `AppState` holds truth. Views observe.

### State Management

```swift
@MainActor @Observable
final class AppState {
    var openClawContext: OpenClawContext?
    var claudeUsage: ClaudeUsage?
    var connectionStatus: ConnectionStatus = .disconnected
    var claudeStatus: ClaudeConnectionStatus = .unknown
    var lastOpenClawUpdate: Date?
    var lastClaudeUpdate: Date?
    var error: AppError?
}
```

Services: `OpenClawConnection` is an `actor` (mutable connection/backoff state). `ClaudeUsagePoller` is a plain class with async methods. `KeychainReader` and `ConfigReader` are structs with static methods behind protocols (for testability).

### Error Handling

```swift
enum AppError: LocalizedError {
    case openClawNotRunning
    case openClawAuthFailed(String)
    case openClawNotPaired
    case claudeCredentialsNotFound
    case claudeTokenExpired
    case claudeTokenRefreshFailed(Error)
    case claudeAPIError(statusCode: Int, message: String)
    case configNotFound
    case configParseError(Error)
}
```

Errors display inline in dropdown card. Icon dims on error. Only notify on state transitions (connected→disconnected), not every failed poll.

### Security

- **Ed25519 private key:** Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Never export raw bytes to variables unnecessarily.
- **OAuth tokens:** Use `Data` not `String` where possible (can be zeroed). Read fresh from Keychain each poll. Don't cache longer than needed.
- **`ws://` localhost:** Accepted risk (standard for local dev tools). Validate handshake protocol to avoid connecting to rogue listener.
- **Unsandboxed** (required for cross-app Keychain + `~/.openclaw/` access). Hardened Runtime enabled.
- **Notarization** required for distribution.
- **UserDefaults:** Non-sensitive data only (port, display prefs, thresholds). No tokens/keys/emails.

### Performance Targets

- **Memory:** < 30 MB resident
- **CPU:** < 0.1% idle
- **Timer coalescing:** Use `Task.sleep` with tolerance for polling
- **Sleep/wake:** `NSWorkspace.screensDidSleepNotification` → pause all polling/WS. Resume on wake.
- **Icon cache:** LRU with bucket quantization — don't redraw on every event
- **Lazy dropdown:** Create SwiftUI view hierarchy on menu open, release on close

---

## Settings Window

SwiftUI `Settings` scene. Minimal tabs:

**General:**
- Launch at login (`SMAppService.mainApp`)
- Used vs remaining display toggle

**OpenClaw:**
- Port (auto-detected, editable)
- Connection status indicator
- Re-pair / disconnect device

**Claude:**
- Account email (read-only)
- Plan tier (read-only)
- Credential status

**Notifications:**
- Master toggle
- Per-event toggles with threshold sliders

---

## Dependencies

**Zero external dependencies.** Apple frameworks only:
- CryptoKit (Ed25519)
- Network (NWPathMonitor)
- SwiftUI + AppKit (UI)
- UserNotifications (alerts)
- ServiceManagement (launch at login)

WebSocket via `URLSessionWebSocketTask`.

---

## Build & Distribution

```bash
# Build
xcodebuild -scheme ClawBar -configuration Release archive \
  -archivePath build/ClawBar.xcarchive

# Export
xcodebuild -exportArchive \
  -archivePath build/ClawBar.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/

# Notarize
xcrun notarytool submit build/ClawBar.app.zip \
  --apple-id ... --team-id ... --password ...
```

**v1:** Build locally, copy to `/Applications`.
**Future:** Homebrew cask, GitHub releases.

---

## v2 Ideas

- [ ] Multiple OpenClaw session monitoring
- [ ] Keyboard shortcut to show/hide menu
- [ ] macOS Notification Center widget
- [ ] Historical cost tracking charts
- [ ] Sparkle auto-updates
- [ ] Homebrew distribution
- [ ] Click to open OpenClaw webchat
- [ ] Mini chat input from menu bar

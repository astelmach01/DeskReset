# DeskReset

A native macOS menu bar app for eye breaks, movement breaks, and deep-work pauses.

## Features

- Menu bar countdown for the next break
- Eye breaks, defaulting to 20 seconds every 20 minutes
- Movement breaks, defaulting to 5 minutes every 60 minutes
- Full-screen break overlay with Done, Snooze, and Skip
- Strict mode that disables skip/snooze during breaks
- Optional overlay on every connected display
- Heads-up notifications before a break starts
- Meeting guard that defers due breaks during common meeting apps, browser meetings, and Slack huddles
- First-run onboarding
- Rotating eye and movement routines with concrete steps
- Native macOS notifications
- Quiet hours
- Deep-work pause presets: 30, 60, and 90 minutes
- Configurable snooze duration
- Active-time scheduling: timers pause while the computer is idle
- Idle-aware reset: longer away-from-keyboard breaks count naturally
- Optional Smart Detection using local Apple Vision face presence
- Local stats for completed, movement, snoozed, skipped, and mindful time
- Launch-at-login toggle when running as the bundled `.app`
- Local-only settings stored in `UserDefaults`
- Loopback-only HTTP API on `127.0.0.1:17777`
- `deskresetctl` command-line client for scripts and headless control

## Build

```zsh
cd ~/DeskReset
swift run DeskResetCoreChecks
./scripts/build-app.sh
open dist/DeskReset.app
dist/bin/deskresetctl status
```

## Development

```zsh
swift build
swift run DeskResetCoreChecks
swift run DeskReset
```

The app is intentionally local-first: no network calls, no analytics, and no account.

## Local API

The app starts a loopback-only JSON API by default.

```zsh
curl http://127.0.0.1:17777/v1/status
curl http://127.0.0.1:17777/v1/settings
curl -X POST http://127.0.0.1:17777/v1/breaks/start/micro
curl -X POST http://127.0.0.1:17777/v1/breaks/start/movement
curl -X POST http://127.0.0.1:17777/v1/breaks/snooze?minutes=10
curl -X POST http://127.0.0.1:17777/v1/focus?minutes=90
curl -X POST http://127.0.0.1:17777/v1/reminders/resume
curl -X PATCH http://127.0.0.1:17777/v1/settings \\
  -H 'Content-Type: application/json' \\
  -d '{"strictMode":true,"snoozeMinutes":10,"idleResetMinutes":5,"headsUpSeconds":60,"meetingDetectionEnabled":true,"smartDetectionEnabled":false,"smartDetectionAwaySeconds":20}'
```

Equivalent CLI:

```zsh
dist/bin/deskresetctl status
dist/bin/deskresetctl start movement
dist/bin/deskresetctl focus 90
dist/bin/deskresetctl patch-settings '{"strictMode":false}'
```

# TinyBridge-UI

Native macOS menu-bar manager for TinyBridge micro-VMs running on Apple
Silicon through Apple's Virtualization.framework.

TinyBridge-UI is a **companion control plane**, not a replacement for TinyBridge's
VM engine. It talks to TinyBridge's `tinybridged` daemon over its existing
JSON-RPC-over-Unix-socket control plane — no daemon changes, no second
hypervisor, no Electron.

## What it does

- **Menu-bar control center** — VM inventory, start/stop, port-forwarding
  status, open main window, preferences, quit. Compact popover; no polling.
- **Main management window** — dashboard, virtual-machines table with live
  state badges and start/stop controls, port forwarding, configuration
  inspection + validation, diagnostics, preferences.
- **Lifecycle management** — start/stop with real async state reconciliation
  (Stopped → Starting → Running → Stopping → Stopped). A start-call success is
  never mistaken for "running"; state comes from a reconciled backend read.
- **Resilient reconnection** — daemon disconnect/reconnect handled safely;
  timeouts are reconciled, not declared failures.
- **Resource monitoring** — host-observed vs. guest-reported metrics are
  distinguished; unavailable values render as `—`, never fabricated.
- **Port forwarding** — validation with conflict detection and loopback-first
  bindings (explicitly unsupported by the current daemon; surfaced honestly).
- **Configuration studio** — vCPU/memory/disk validation against host capacity;
  edits are validated locally and marked "would apply if supported" since the
  daemon does not yet expose config-write RPC.
- **Diagnostics** — `environment.doctor` output with sensitive data (keys,
  tokens, IPs) redacted before display or export.

## What it does NOT do (by design)

- No Electron, embedded browser, Tauri, or second VM engine.
- No guest OS bundled or managed.
- No unauthenticated remote management (local socket only).
- No `sudo` or privileged helper required.
- No fabricated metrics, snapshots, or guest telemetry (no in-guest agent yet).

## Requirements

- macOS 14.0+ on Apple Silicon or Intel
- Swift 5.10+ (Command Line Tools sufficient)
- TinyBridge core installed and `tinybridged` running (for real VMs)

## Build & run

```bash
git clone <this-repo> TinyBridge-UI
cd TinyBridge-UI
swift build          # debug
swift run            # run the menu-bar app
```

Release:

```bash
swift build -c release
```

Point at a custom control socket:

```bash
TINYBRIDGE_SOCKET=/path/to/tinybridge.sock swift run
```

## Tests

XCTest requires Xcode (not installed here). An assertion-based harness runs
with plain Command Line Tools:

```bash
swift run TinyBridgeUITests
```

Exit code 0 = all tests passed.

## Demo mode (no daemon required)

Preferences → Backend → "Demo (in-process)" runs an in-process mock backend so
you can evaluate the UI without a running TinyBridge daemon. It never claims
capabilities the real backend lacks.

## Documentation

| Doc | Contents |
|---|---|
| `docs/architecture.md` | Module layout, design decisions, concurrency model |
| `docs/design-skill-audit.md` | Design skills/references discovered and imported |
| `docs/design-system.md` | Typography, color, iconography, layout, accessibility |
| `docs/ipc-protocol.md` | Wire contract with TinyBridge's daemon |
| `docs/security.md` | Privilege model, socket handling, redaction, validation |
| `docs/testing.md` | Test strategy, harness, mock backend |
| `docs/development.md` | Build, run, package, contribute |

## Architecture summary

```
TinyBridge-UI (SwiftUI)  ── JSON-RPC 2.0  ──  tinybridged (Rust daemon)
       │                                               │
   MenuBar + MainWindow                           tinybridge-vmhost
   (no VM engine)                                   (Virtualization.framework)
```

The UI and TinyBridge core are architecturally separate. The UI never touches
Virtualization.framework.

## License

Apache License 2.0. See the TinyBridge core repository's LICENSE for the
underlying engine; this UI is a separate companion project.

# Development — TinyBridge-UI

## Prerequisites

- macOS 14.0+ (SwiftUI `MenuBarExtra`, `Window` scenes)
- Swift 5.10+ (Swift 6.3.3 confirmed working)
- Command Line Tools: `xcode-select --install` (Xcode GUI not required)
- TinyBridge core (`tinybridged` daemon) running to manage real VMs:
  `~/Library/Application Support/TinyBridge/tinybridge.sock` must exist and be
  served by `tinybridged`. See the TinyBridge repository for building/running
  the daemon.

## Project layout

```
TinyBridge-UI/
├── Package.swift                  # SwiftPM manifest (macOS 14)
├── Sources/
│   ├── TinyBridgeClient/          # IPC transport + typed protocol models
│   │   ├── Protocol/              # JSONRPC, JSONValue, ClientError
│   │   ├── Models/                # VMState, Environment
│   │   ├── Requests/              # StartRequest, StopRequest, StatusRequest
│   │   ├── IPC/                   # UnixSocketTransport, TinyBridgeClient
│   │   └── Backend/               # Backend, BackendCapabilities, MockBackend
│   ├── VMConfiguration/           # VM config models + validation
│   │   ├── Models/VMConfiguration.swift
│   │   └── Validation/
│   │       ├── ResourceValidator.swift
│   │       └── PortValidator.swift
│   ├── VMObservability/           # Metrics history + diagnostic redaction
│   │   ├── History/RingBuffer.swift
│   │   ├── Metrics/MetricSample.swift, MetricsHistory.swift
│   │   └── Diagnostics/Redactor.swift
│   └── TinyBridgeUI/              # SwiftUI application
│       ├── App/TinyBridgeUIApp.swift
│       ├── MenuBar/MenuBarView.swift
│       ├── Components/            # StateBadge, StatePresentation, EmptyStateView
│       ├── Windows/               # MainWindow + per-section views
│       └── ViewModels/            # AppViewModel, OperationEvent
├── Tests/
│   └── TinyBridgeUITests/main.swift   # assertion-based test harness
├── docs/
│   ├── architecture.md
│   ├── design-skill-audit.md
│   ├── design-system.md
│   ├── ipc-protocol.md
│   ├── security.md
│   └── testing.md
└── README.md
```

## Build

```bash
cd TinyBridge-UI
swift build
```

Build the release binary:

```bash
swift build -c release
```

The executable is at
`.build/release/TinyBridgeUI`.

## Run

From source (menu-bar app; a `TinyBridge` item appears in the menu bar):

```bash
swift run
```

Or run the release build:

```bash
swift run -c release
```

To point at a non-default control socket:

```bash
TINYBRIDGE_SOCKET=/path/to/tinybridge.sock swift run
```

## Run tests

XCTest requires Xcode; this environment uses an assertion harness instead:

```bash
swift run TinyBridgeUITests
```

Exit code 0 = all tests pass.

## Offline / demo mode

The app supports an in-process demo backend (no daemon required) via
Preferences → Backend → "Demo (in-process)". This is useful for evaluating the
UI without a running TinyBridge daemon. The demo backend never claims
capabilities the real backend lacks.

## Packaging (macOS .app)

For distribution, wrap the SwiftPM executable in a `.app` bundle with an
`Info.plist` (`CFBundleIdentifier`, `LSUIElement` if menu-bar-only, icon set,
entitlements). Codesign and notarize per Apple requirements. No special
entitlements are needed for the UI itself.

CI should run `swift build` and `swift run TinyBridgeUITests` and fail on any
compilation error or test failure.

## Adding a new backend method

1. Add the method name to `RPCMethod` in `TinyBridgeClient/Protocol/JSONRPC.swift`.
2. Add request params + response decoding to `TinyBridgeClient` as needed.
3. Add a capability flag to `BackendCapabilities` if the daemon supports it.
4. Wire a UI action in `AppViewModel` and update `BackendCapabilities.live`.

## Conventions

- Follow the `apple-macos-design` skill (`docs/design-system.md`): system
  typography, SF Symbols, semantic colors, symbol+text+color for state,
  unknown ≠ zero, no fabricated metrics.
- Blocking I/O (socket connect/send/recv) stays off the main actor inside
  `UnixSocketTransport`.
- Never treat a timeout as proof of failure; reconcile against the backend.
- Add tests with each meaningful feature; run the harness before committing.

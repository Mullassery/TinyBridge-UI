# TinyBridge-UI — Systems Design Audit

Audit date: 2026-10-27
Repository: `TinyBridge-UI`
Revision observed: working tree clean; latest commit dated 2026-10-25
Version: 0.1.0 (Preferences → About)
License: Apache-2.0
Platform: macOS 14+, Swift 5.10+

## Overview

TinyBridge-UI is a native SwiftUI menu-bar and main-window client for the
TinyBridge micro-VM daemon (`tinybridged`). It is a companion control plane, not
a VM engine: it speaks the daemon's existing newline-delimited JSON-RPC 2.0
protocol over a Unix-domain socket and never links Virtualization.framework or
spawns a VM itself.

The package contains four SwiftPM modules, a custom executable test harness,
documentation, and one CI workflow. There are no third-party Swift dependencies.
The app is delivered as a bare SwiftPM executable; there is no `.app` bundle,
`Info.plist`, code-signing, or notarization step.

## Architecture

```text
TinyBridgeUI (SwiftUI)
  ├── MenuBarExtra(.window) ── MenuBarView
  ├── Window ───────────────── MainWindow / section views
  └── Settings ─────────────── PreferencesView
             │
             ▼
      AppViewModel (@MainActor)
      backend protocol + reconciliation state
             │
             ▼
  TinyBridgeClient ── JSON-RPC 2.0 over Unix socket
      │                    one connection per request
      │                    serial utility DispatchQueue
      ▼
  tinybridged (Rust daemon)
```

Module boundaries:

- `TinyBridgeClient`: JSON-RPC envelopes, request parameters, transport, live
  client, backend protocol, mock backend.
- `VMConfiguration`: pure resource/port/shared-directory models and validators.
- `VMObservability`: bounded metric ring buffers, metric history, redactor.
- `TinyBridgeUI`: SwiftUI scenes, views, `AppViewModel`, event presentation.
- `TinyBridgeUITests`: assertion-based executable harness, not XCTest.

Key design decisions documented in `docs/architecture.md`:

1. The daemon is the source of truth; a successful `environment.up` response is
   not treated as proof that a VM is running.
2. Start/stop operations are serialized per VM through `pendingOperations`.
3. A client timeout is reconciled against the backend rather than declared a
   failure.
4. Unsupported daemon capabilities are shown as unsupported, not fabricated.
5. All blocking socket work runs off the main actor.

## Entry Points

- `swift run` / `.build/{debug,release}/TinyBridgeUI`: the menu-bar executable.
- `MenuBarExtra` popover: inventory, single-VM start/stop, open main window,
  Preferences, Quit, dismissable error.
- Main `Window`: Dashboard, Virtual Machines, Port Forwarding, Configuration,
  Diagnostics, Preferences.
- `Settings` scene: backend selection and auto-refresh toggle.
- `swift run TinyBridgeUITests`: assertion harness.
- No URL scheme, login item, launch agent, XPC service, or privileged helper.

## Dependencies

- Apple frameworks only: SwiftUI, Foundation, AppKit, Darwin.
- No external Swift packages, no bundled binaries, no network SDKs.
- Build requirement: Swift 5.10+ and macOS 14+.
- TinyBridge core is a runtime dependency for live operation, not a build
  dependency.

## Module Structure

- `Sources/TinyBridgeClient/Protocol/` — `JSONRPCRequest`, `JSONRPCResponse`,
  error codes, `JSONValue`, client error classification.
- `Sources/TinyBridgeClient/IPC/` — `UnixSocketTransport` and
  `TinyBridgeClient`.
- `Sources/TinyBridgeClient/Models/` — `EnvironmentSummary`,
  `VMLifecycleState`.
- `Sources/TinyBridgeClient/Requests/` — typed `StartRequest`, `StopRequest`,
  `StatusRequest` parameter serialization.
- `Sources/TinyBridgeClient/Backend/` — `TinyBridgeBackend`,
  `BackendCapabilities`, `DiagnosticReport`, `MockBackend`.
- `Sources/VMConfiguration/` — resource/port models, host resources, validators.
- `Sources/VMObservability/` — fixed-capacity ring buffer, metric history,
  diagnostic redactor.
- `Sources/TinyBridgeUI/` — app scenes, menu bar, main window, section views,
  `AppViewModel`, operation events.
- `Tests/TinyBridgeUITests/main.swift` — 334-line custom assertion harness.

## Data, State, APIs, and Contracts

### Transport and protocol

- AF_UNIX stream socket; path defaults to
  `~/Library/Application Support/TinyBridge/tinybridge.sock`, overridable with
  `TINYBRIDGE_SOCKET` in `TinyBridgeClient.init`.
- One connection per request; write JSON plus `\n`, read one newline-terminated
  response, close.
- Requests carry `jsonrpc: "2.0"`, a monotonically increasing `UInt64` id,
  method, and `JSONValue` params.
- Default timeout 30 s; `environment.up` 120 s; `environment.down` 60 s.
- Methods exposed by the client: `environment.list`, `environment.status`,
  `environment.up`, `environment.down`, `environment.doctor`. Method constants
  also define shell, repair, GUI, and DDS methods that the UI does not use.
- RPC errors are mapped to semantic kinds by code and, because the daemon
  collapses most failures to `-32603`, by message text.
- `EnvironmentSummary.status` is the daemon's lowercased Rust `Debug` string
  (for example `running { uptime_secs: 100 }`); the client parses it into
  `VMLifecycleState` and the UI never displays the raw status.

### Presentation state

- `AppViewModel` is `@MainActor` and owns environments, connection state,
  capabilities, pending operations, the last error, the 200-entry event log,
  backend kind, and the displayed socket path.
- `refresh()` loads capabilities then inventory. `reconcileUntilSettled()` polls
  every 600 ms for at most 20 attempts while any VM is transitional or any
  operation remains pending.
- `start`/`stop` serialise per VM, log the accepted/timeout outcome, then
  reconcile. A timeout is not converted into a failed state.
- `MockBackend` is an actor with deterministic boot/stop behavior, scripted
  errors, and offline mode; it models the same lifecycle as the daemon.

### Configuration and observability

- Resource validation ranges: 1–64 vCPU, 1–256 GB memory, 1–4096 GB disk.
  Memory above host physical memory is an error; CPU overcommit and low memory
  headroom are warnings.
- Port validation: 1–65535, privileged-port warning, loopback default,
  public-bind warning, duplicate host address+port+protocol detection.
- Metrics are deliberately unavailable. `MetricKind.availableSource` returns
  `nil` for every metric because the daemon exposes no usage RPC. History is
  bounded at 120 samples per metric.
- The redactor has rules for PEM private keys, bearer/authorization headers,
  secret assignments, AWS access key IDs, 32+ hex strings, IPv4, home paths, and
  email addresses.
- No application data is persisted. The socket path is the only saved reference.

## Security Observations

### Positive controls

- The app opens no network listener and has no remote management endpoint.
- The socket is local and the app runs as the invoking user; no `sudo`,
  privileged helper, or Virtualization entitlement is requested.
- Requests are typed values, not shell strings; there is no command
  interpolation.
- Unsupported daemon capabilities are explicitly disabled rather than faked.
- Resource and port inputs are validated before presentation; public port
  bindings and privileged ports produce warnings.
- The code avoids treating a timeout as a failed VM operation, reducing
  destructive retry behavior.
- No third-party dependencies, keeping the supply chain small.
- CI builds debug and release and runs the full assertion harness on macOS 15.

### Risk areas

1. **The app never performs an initial refresh, and the auto-refresh preference
   is inert.** `autoRefresh` is declared at
   `Sources/TinyBridgeUI/ViewModels/AppViewModel.swift:52` and toggled at
   `Windows/PreferencesView.swift:36`, but no code reads it. There is no
   `.task`, `.onAppear`, or timer that calls `refresh()` on launch; every call
   site is a button or menu command. The app therefore starts in `unknown`
   state with an empty inventory until the user refreshes. This also contradicts
   the README's "no polling" statement and the verification report's reconnect
   claim.
2. **Response reads are unbounded and the timeout is per-recv, not a total
   deadline.** `readLine` appends into an ever-growing `Data` with no maximum
   (`UnixSocketTransport.swift:135-158`). `SO_RCVTIMEO` is configured once
   (`:74-82`), so a peer that trickles one byte within each timeout window can
   keep the call alive indefinitely. A malicious or broken local daemon can
   exhaust memory or stall the client. A single serial queue
   (`TinyBridgeClient.swift:22`) means one stuck 120-second `environment.up`
   also queues every other request behind it.
3. **Sending on a socket whose peer has closed can raise `SIGPIPE` and
   terminate the UI.** The transport uses `Darwin.send` (`:118-123`) but never
   sets `SO_NOSIGPIPE` and the package installs no `SIGPIPE` handler. A daemon
   restart or close between connect and send can therefore crash the app
   instead of returning an error.
4. **JSON-RPC responses are not correlated with requests or version-checked.**
   `TinyBridgeClient.call` decodes the envelope and checks only for `error`
   (`TinyBridgeClient.swift:143-158`). It does not compare `response.id` with
   the request id, validate `jsonrpc == "2.0"`, or reject a response with
   neither `result` nor `error`; it returns `.null`. With one connection per
   request this is mostly a contract-hardening gap, but a desynchronized or
   malicious daemon is not detected.
5. **Diagnostic redaction is implemented but never applied.** `doctor` returns
   `DiagnosticReport(raw:)` directly (`TinyBridgeClient.swift:89-94`), and
   `DiagnosticsView` renders `report.raw` and parsed lines without calling the
   redactor (`Windows/DiagnosticsView.swift:44`, `:59-69`). The only
   `Redactor()` construction in the repository is in the test harness. The
   README, architecture, security, and verification docs all claim redaction
   happens before display or export. The redactor also misses IPv6 addresses
   and long base64 blobs despite the broad "IPs" and "keys" wording.
6. **No distributable `.app` artifact, bundle metadata, signing, or
   notarization exists.** `Package.swift` produces an executable target only;
   there is no `.app`, `Info.plist`, entitlement file, or Xcode project. The
   app relies on `AppDelegate` calling `setActivationPolicy(.regular)` when run
   as a bare executable (`App/TinyBridgeUIApp.swift:4-11`). The limitation is
   documented in `docs/verification-report.md:109-110` and
   `docs/development.md:105-110`, but there is no release pipeline for a
   Gatekeeper-acceptable product.
7. **The menu-bar Preferences button targets a selector that SwiftUI does not
   expose.** `MenuBarView` sends `showPreferencesWindow:` (`MenuBarView.swift:57-62`),
   while the app declares a SwiftUI `Settings` scene
   (`TinyBridgeUIApp.swift:45-50`). On macOS 14 the Settings window is opened
   through `SettingsLink` or the `showSettingsWindow:` action; the menu-bar
   button is likely a no-op even though Preferences remains reachable from the
   sidebar.
8. **The displayed socket path can be wrong after switching backends.**
   `useLiveBackend()` constructs a client that honors `TINYBRIDGE_SOCKET`, then
   overwrites the displayed path with `defaultSocketPath()`
   (`AppViewModel.swift:100-104`). The UI can show the default path while the
   actual client connects to the environment override.
9. **Port-forwarding validation is not wired into its view.** The view seeds
   placeholder mappings and declares `issues`, but never calls
   `PortValidator` and never populates `issues` (`Windows/PortForwardingView.swift:6-10`,
   `:47-55`). It is explicitly unsupported by the daemon, but the documentation
   presents conflict detection and public-bind warnings as working behavior.
10. **Socket ownership and peer credentials are trusted, not verified.** The
    security model relies on the daemon owning and restricting the socket
    (`docs/security.md:8-15`). The client does not check the socket owner/mode
    or use `getpeereid`/`LOCAL_PEERCRED`. This is consistent with same-user
    trust assumptions, but a replaced socket path is not detected.
11. **Test and documentation coverage overstates the implementation.** The
    harness tests pure models, request encoding, error classification, the mock
    backend, and a few redactor cases, but does not exercise the real transport,
    response-id correlation, redaction in `DiagnosticsView`, or any UI. CI runs
    only on macOS 15. `docs/testing.md:37-39` claims protocol-version
    compatibility while the client never validates the response version;
    `docs/verification-report.md:83-84` claims reconnect handling while there
    is no automatic reconnect.

## Tests / CI

- Custom assertion harness, not XCTest: `swift run TinyBridgeUITests`, 334
  lines and 98 `check`-style assertions (44 boolean checks).
- Covered: lifecycle status parsing, JSON-RPC encoding/decoding, environment
  summaries including null IP/uptime, start/stop params, error classification,
  `JSONValue`, default socket path, resource/port validation, ring buffer,
  metrics history, redactor cases, mock lifecycle/doctor.
- Not covered: real `UnixSocketTransport`, framing limits, timeouts and slow
  peers, `SIGPIPE`, malformed JSON-RPC correlation, live daemon integration,
  `AppViewModel` behavior, menu bar, settings, or any SwiftUI view.
- CI: one `macos-15` job running `swift build`, `swift build -c release`, and
  `swift run TinyBridgeUITests`; 30-minute timeout.
- No coverage reporting, sanitizer run, or packaging/signing job.

## Findings

| Severity | Finding | Evidence | Impact | Root Cause Hypothesis | Recommendation |
|----------|---------|----------|--------|----------------------|---------------|
| Medium | No initial refresh and inert auto-refresh leave the app disconnected/empty until manual refresh | `AppViewModel.swift:52`, `:109`; `PreferencesView.swift:36`; no launch `.task`/`.onAppear`; `TinyBridgeUIApp.swift:17-50` | Core inventory and connection state are absent on launch; the preference lies | Auto-refresh was modeled as UI state but never connected to a timer or lifecycle hook | Call `refresh()` from the app/menu-bar task, implement the timer when enabled, or remove the toggle and document manual refresh |
| Medium | Unbounded response buffering plus per-recv timeout allows memory exhaustion or indefinite stalls; one serial queue blocks all IPC | `UnixSocketTransport.swift:74-82`, `:135-158`; `TinyBridgeClient.swift:22`, `:124-135` | A broken or malicious local daemon can exhaust the UI process or hold every request behind a 120 s call | Transport copied the daemon's simple newline protocol without a hard frame cap or total deadline; one queue serializes all methods | Enforce a maximum response size, compute a monotonic total deadline, support cancellation, and avoid head-of-line blocking for status/doctor |
| Medium | Missing `SO_NOSIGPIPE` can terminate the UI when the daemon closes during send | `UnixSocketTransport.swift:113-133`; no signal handler or `SO_NOSIGPIPE` in repository | App crashes on daemon restart/close races instead of surfacing a transport error | Darwin `send` was used without suppressing `SIGPIPE` | Set `SO_NOSIGPIPE` on the socket and handle `EPIPE`/`EINTR`; add a regression test with a closed peer |
| Low | JSON-RPC response id and version are not validated | `TinyBridgeClient.swift:143-158`; `JSONRPC.swift:23-28` | Desynchronized or malformed responses are accepted; missing result/error becomes `.null` | Client assumes the one-connection-per-request daemon always returns the matching envelope | Compare ids, require `jsonrpc == "2.0"`, reject envelopes with neither result nor error, and test malformed cases |
| Low | Diagnostic redaction is never applied and misses IPv6/base64 | `DiagnosticsView.swift:44`, `:59-69`, `:72-74`; `TinyBridgeClient.swift:89-94`; `Redactor.swift:52`; only test call site | Sensitive material can be displayed raw; current doctor output is benign, so impact is latent until daemon output grows | Redactor was built as a library but not wired into the doctor path; docs describe the intended behavior | Run redaction in the client or view before display/export, add IPv6/base64/no-secret tests, and align docs |
| Low | No `.app` bundle, Info.plist, signing, or notarization | `Package.swift`; `docs/development.md:105-110`; `docs/verification-report.md:109-110`; `AppDelegate` `TinyBridgeUIApp.swift:4-11` | The product cannot be distributed through normal macOS channels and has no stable app identity | MVP was run directly from SwiftPM | Add packaging/signing/notarization CI and document the support matrix |
| Low | Menu-bar Preferences button uses a non-SwiftUI selector | `MenuBarView.swift:57-62`; `TinyBridgeUIApp.swift:45-50` | The button is likely a no-op; Preferences is still reachable from the main sidebar | Ported an older AppKit selector instead of using `SettingsLink`/`showSettingsWindow:` | Use `SettingsLink` or the correct action and add a UI test |
| Low | Displayed socket path ignores `TINYBRIDGE_SOCKET` after switching from demo | `AppViewModel.swift:100-104`; `TinyBridgeClient.swift:31-46` | Users see the wrong path while the client connects elsewhere | The UI recomputes the default instead of reading the client's resolved path | Read `client.socketPath` after construction and surface it |
| Low | Port-forwarding view never runs its validator | `PortForwardingView.swift:6-10`, `:24-55`; `PortValidator.validateAll` unused by the view | Documentation implies validation/conflict detection that the placeholder UI does not perform | View was built as a future-capability preview | Call `validateAll` on edits or label the table explicitly as static preview data |
| Low | Socket ownership and peer credentials are not verified | `docs/security.md:8-15`; `UnixSocketTransport.swift:61-69` | A replaced socket path is trusted if filesystem permissions allow it | Security model delegates entirely to the daemon and same-user filesystem assumptions | Verify socket owner/mode and peer uid where available; document the residual risk |
| Low | Tests, CI, and docs overstate coverage and behavior | `Tests/TinyBridgeUITests/main.swift`; `docs/testing.md:37-39`; `docs/verification-report.md:83-84`; `README.md` | Transport, UI, launch refresh, and redaction regressions can ship undetected | Harness was optimized for Command Line Tools and pure logic | Add transport tests with `socketpair`, view-model tests, and a macOS packaging job; correct docs |

## Strengths

- Clear module boundary between UI, IPC, configuration, and observability.
- Honest capability model: unsupported daemon features are disabled, not faked.
- Backend-authoritative lifecycle with explicit reconciliation and per-VM
  serialization.
- Typed protocol models and typed error taxonomy instead of ad-hoc dictionaries.
- Local-only, no third-party dependencies, no privileged helper.
- Pure validators and deterministic mock backend make most logic testable.
- Documentation is unusually detailed and generally accurate about daemon
  limitations, even where implementation has drifted.

## Limitations

- No XCTest or automated UI coverage.
- No real-daemon integration test in CI.
- No app bundle or release pipeline.
- No telemetry source exists; metrics are intentionally unavailable.
- The redactor is a library capability, not an enforced boundary today.
- The transport is a minimal blocking implementation with no hard frame or
  total-time budget.

## Prioritized Recommendations

1. **Medium**: Refresh on launch and implement or remove the auto-refresh
   preference; add a view-model test for both paths.
2. **Medium**: Bound response size, enforce a total deadline, set
   `SO_NOSIGPIPE`, and add transport tests against a socketpair/closed peer.
3. **Medium**: Decide whether to keep a single serial IPC queue; at minimum
   prevent a 120-second `up` from blocking inventory/doctor.
4. **Low**: Wire `Redactor` into the doctor display path and expand IPv6/base64
   coverage before claiming redaction in docs.
5. **Low**: Package a signed `.app`, add `SettingsLink`, fix the displayed socket
   path, validate response ids/version, and correct the port-forwarding preview
   and documentation drift.

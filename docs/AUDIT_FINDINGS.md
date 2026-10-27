# TinyBridge-UI — Audit Findings

**Audit Date:** 2026-10-27
**Scope:** SwiftUI app, typed IPC client, socket transport, VM configuration
validators, observability/redaction, test harness, CI, and documentation
**Method:** read-only source/docs/CI inspection; tests were not run to avoid
generated artifacts

## Summary

TinyBridge-UI is a small, well-separated companion control plane. The UI owns
presentation and reconciliation; `TinyBridgeClient` owns typed JSON-RPC; the
daemon owns VM execution. The app has no network listener, no third-party
dependencies, no privileged helper, and an honest capability model that disables
features the daemon does not implement. The lifecycle design correctly treats
the backend as the source of truth and reconciles after timeouts.

The main gaps are runtime robustness and a few incomplete UX/docs paths. The app
does not refresh on launch, the auto-refresh preference is inert, and the
transport has no response-size or total-time bound. Missing `SO_NOSIGPIPE` can
crash the app when the daemon closes during a send. Diagnostic redaction exists
but is not applied to live doctor output, despite documentation claiming it is.

See the detailed report at:
[../.audit/reports/TinyBridge-UI/audit.md](../.audit/reports/TinyBridge-UI/audit.md)

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 3 |
| Low | 8 |

## Findings

### 1. Medium — No initial refresh; auto-refresh preference is inert

**Evidence**

- `Sources/TinyBridgeUI/ViewModels/AppViewModel.swift:52` declares
  `@Published var autoRefresh = true`, but no code records or reads it.
- `Sources/TinyBridgeUI/Windows/PreferencesView.swift:36` exposes it as
  "Refresh VM list automatically".
- `refresh()` is defined at `AppViewModel.swift:109`, but every call site is a
  button or menu command (`TinyBridgeUIApp.swift:38-41`,
  `DashboardView.swift:42`, `VirtualMachinesView.swift:14`). There is no
  `.task`, `.onAppear`, or timer that refreshes on launch.
- `README.md` says the popover has "no polling"; `docs/verification-report.md`
  says reconnect is handled by retrying `list()`.

**Impact**

The app starts in `unknown` connection state with an empty inventory. A user
who opens the menu bar or main window sees "Not connected" and "No VMs" until
they manually refresh, even when the daemon is running. The Preferences toggle
has no effect, and the docs describe behavior the code does not implement.

**Root cause hypothesis**

Auto-refresh was modeled as view state but never connected to the view-model
lifecycle or a timer. The MVP relied on manual refresh.

**Recommendation**

- Call `refresh()` from a launch/lifecycle task, and implement a timer when
  `autoRefresh` is enabled (or remove the preference).
- Add `AppViewModel` tests for launch refresh, timer enable/disable, and
  disconnected startup.
- Correct the README/verification claim or implement reconnect behavior.

### 2. Medium — Response reads are unbounded and the timeout is not a total deadline

**Evidence**

- `Sources/TinyBridgeClient/IPC/UnixSocketTransport.swift:135-158` appends every
  `recv` chunk into a growing `Data` with no maximum frame size.
- `UnixSocketTransport.swift:74-82` sets `SO_RCVTIMEO`/`SO_SNDTIMEO` once per
  socket. The timeout is per blocking `recv`, not a budget for the whole
  response, so a peer can trickle bytes indefinitely.
- `Sources/TinyBridgeClient/IPC/TinyBridgeClient.swift:22` uses one serial
  `DispatchQueue` for all calls; `environment.up` uses a 120-second timeout
  (`TinyBridgeClient.swift:61-68`).

**Impact**

A malicious or malfunctioning local daemon can make the UI allocate unbounded
memory or hold a call open past its intended 30/60/120-second deadline. Because
all requests share one serial queue, a slow `up` blocks status, refresh, and
doctor behind it. The UI remains drawing, but control-plane actions stop
responding.

**Root cause hypothesis**

The transport mirrors the daemon's simple newline protocol without adding a
hard frame cap or a monotonic total deadline. One serial queue was chosen to
keep socket I/O off the main actor, without separating long lifecycle calls
from short reads.

**Recommendation**

- Enforce a maximum response size and reject oversized frames as malformed.
- Compute one deadline per call and pass the remaining time to each operation.
- Add cancellation and avoid head-of-line blocking for inventory/status/doctor.
- Add tests using a socketpair that never sends `\n`, sends a huge line, and
  trickles bytes.

### 3. Medium — Missing `SO_NOSIGPIPE` can terminate the UI on a daemon close

**Evidence**

- `Sources/TinyBridgeClient/IPC/UnixSocketTransport.swift:61-69` creates and
  connects the socket.
- `UnixSocketTransport.swift:113-133` writes with `Darwin.send` but never sets
  `SO_NOSIGPIPE`; there is no `signal(SIGPIPE, ...)` handler in the repository.
- The daemon can close between `connect` and `send` during restart or shutdown.

**Impact**

On Darwin, writing to a socket whose peer has closed can raise `SIGPIPE`, whose
default action terminates the process. The app can crash on a normal daemon
restart instead of reporting a transport error.

**Root cause hypothesis**

The minimal transport handles `send` errors but not the process-level
`SIGPIPE` side effect.

**Recommendation**

- Set `SO_NOSIGPIPE` on the socket and handle `EPIPE`/`EINTR`.
- Add a regression test with a peer that closes before the client sends.
- Consider a process-wide `SIGPIPE` ignore only as defense in depth, not as the
  sole fix.

### 4. Low — JSON-RPC response id and version are not validated

**Evidence**

- `Sources/TinyBridgeClient/Protocol/JSONRPC.swift:23-28` includes `jsonrpc` and
  `id` in the response model.
- `Sources/TinyBridgeClient/IPC/TinyBridgeClient.swift:143-158` decodes the
  response, checks only `response.error`, and returns
  `response.result ?? .null`.
- No check compares `response.id` with the request id or requires
  `response.jsonrpc == "2.0"`.

**Impact**

A desynchronized or malformed response is accepted as the answer to the current
request. A response with neither `result` nor `error` becomes `.null`, which can
surface as an empty successful payload. The one-connection-per-request model
limits practical exposure, but the contract is not enforced.

**Root cause hypothesis**

The client trusts the daemon to always return a matching JSON-RPC 2.0 envelope.

**Recommendation**

- Require `response.id == id`, `response.jsonrpc == "2.0"`, and exactly one of
  `result`/`error`.
- Add malformed-envelope tests.

### 5. Low — Diagnostic redaction is implemented but never applied; IPv6/base64 are missed

**Evidence**

- `Sources/TinyBridgeClient/IPC/TinyBridgeClient.swift:89-94` returns
  `DiagnosticReport(raw: validation)` directly from the daemon.
- `Sources/TinyBridgeUI/Windows/DiagnosticsView.swift:44` renders `report.raw`;
  `:59-69` renders parsed lines; `:72-74` claims the redactor would strip
  sensitive material before export.
- The only `Redactor()` construction in the repository is
  `Tests/TinyBridgeUITests/main.swift:234`.
- `Sources/VMObservability/Diagnostics/Redactor.swift:20-44` covers PEM keys,
  bearer/auth headers, secret assignments, AWS IDs, 32+ hex, IPv4, home paths,
  and emails, but not IPv6 or long base64.
- `README.md`, `docs/architecture.md:65-66`, `docs/security.md:39-41`, and
  `docs/verification-report.md` claim redaction before display/export.

**Impact**

Current `environment.doctor` output is only VM/SSH/DDS/shell check lines, so the
bug is latent. If doctor output grows to include paths, configuration, IPs, or
tokens, the UI will display it raw. The docs currently promise a protection that
is not wired in.

**Root cause hypothesis**

The redactor was implemented as a reusable library and tested, but the doctor
display path was never connected to it.

**Recommendation**

- Apply `Redactor` in `TinyBridgeClient.runDoctor` or before rendering in
  `DiagnosticsView`, and ensure the parsed lines are redacted as well.
- Add IPv6 and long-base64 rules and tests that drive the actual doctor view
  path.
- Align the README/docs with what is enforced.

### 6. Low — No `.app` bundle, Info.plist, signing, or notarization

**Evidence**

- `Package.swift` declares an executable product only.
- No `.app`, `Info.plist`, `.entitlements`, `.xcodeproj`, or `.xcworkspace`
  exists in the repository.
- `Sources/TinyBridgeUI/App/TinyBridgeUIApp.swift:4-11` calls
  `setActivationPolicy(.regular)` for bare-executable launches.
- `docs/development.md:105-110` and `docs/verification-report.md:109-110`
  document packaging/signing/notarization as future work.

**Impact**

The app runs from SwiftPM but cannot be distributed through normal macOS
channels, has no stable bundle identity, and is subject to Gatekeeper/quarantine
behavior as an unsigned executable. This is a known MVP limitation, not an
undocumented defect.

**Root cause hypothesis**

The project prioritized a runnable SwiftPM MVP over a release artifact.

**Recommendation**

- Add `.app` packaging with `Info.plist` (`CFBundleIdentifier`, version,
  `LSUIElement` decision, icon), codesigning, notarization, and a CI release job.
- Document the supported distribution path and Gatekeeper expectations.

### 7. Low — Menu-bar Preferences button uses a non-SwiftUI selector

**Evidence**

- `Sources/TinyBridgeUI/MenuBar/MenuBarView.swift:57-62` sends
  `Selector(("showPreferencesWindow:"))`.
- The app declares a SwiftUI `Settings` scene at
  `Sources/TinyBridgeUI/App/TinyBridgeUIApp.swift:45-50`.
- On macOS 14, SwiftUI settings are opened through `SettingsLink` or the
  `showSettingsWindow:` action; `showPreferencesWindow:` is the older AppKit
  preference-window selector.

**Impact**

The menu-bar "Preferences…" button is likely a no-op. Preferences is still
reachable from the main window's sidebar, so the app is not unusable, but the
menu-bar control does not do what it says.

**Root cause hypothesis**

An older AppKit selector was used instead of the SwiftUI settings action.

**Recommendation**

- Use `SettingsLink` (macOS 14+) or `showSettingsWindow:` and add a smoke test.

### 8. Low — Displayed socket path is wrong after switching back to the live backend

**Evidence**

- `Sources/TinyBridgeClient/IPC/TinyBridgeClient.swift:31-39` resolves
  `TINYBRIDGE_SOCKET` before falling back to the default path.
- `Sources/TinyBridgeUI/ViewModels/AppViewModel.swift:100-104` constructs a new
  client and then sets `backendSocketPath = TinyBridgeClient.defaultSocketPath()`
  instead of reading `client.socketPath`.

**Impact**

A user running with a custom `TINYBRIDGE_SOCKET` sees the default path in the
Dashboard, Diagnostics, and Preferences while the app actually connects to the
custom socket. This makes connection troubleshooting misleading.

**Root cause hypothesis**

The display path is recomputed instead of being derived from the resolved client.

**Recommendation**

- Set `backendSocketPath` from the concrete client's `socketPath` after every
  backend swap.

### 9. Low — Port-forwarding view never runs its validator

**Evidence**

- `Sources/TinyBridgeUI/Windows/PortForwardingView.swift:6-10` seeds placeholder
  mappings.
- `PortForwardingView.swift:24-55` renders the table and an `issues` state, but
  never calls `PortValidator.validateAll` or assigns `issues`.
- `docs/verification-report.md:33-35` says the view includes validation
  warnings and duplicate-port detection.

**Impact**

The view is explicitly marked unsupported by the daemon, so this is not a
current data-loss path. However, the documentation overstates the demo: users
cannot see validation behavior or conflict detection because nothing invokes
the validator.

**Root cause hypothesis**

The view was built as a future-capability preview and never wired to the pure
validators.

**Recommendation**

- Call `PortValidator.validateAll` when mappings change and render the result,
  or label the table as static illustrative data and remove the validation
  claims.

### 10. Low — Socket ownership and peer credentials are not verified

**Evidence**

- `docs/security.md:8-15` states the daemon owns the socket and the UI trusts
  filesystem permissions.
- `Sources/TinyBridgeClient/IPC/UnixSocketTransport.swift:61-69` connects to the
  path without checking the socket owner/mode or the peer uid.

**Impact**

A process that can replace or impersonate the socket path is trusted. This is
consistent with same-user trust, but the app does not detect a misconfigured or
replaced socket.

**Root cause hypothesis**

Security was delegated entirely to the daemon and filesystem permissions.

**Recommendation**

- Verify the socket owner/mode and use `getpeereid`/`LOCAL_PEERCRED` when
  available; document the residual same-user risk.

### 11. Low — Tests, CI, and docs overstate coverage and behavior

**Evidence**

- `Tests/TinyBridgeUITests/main.swift` covers pure models, request encoding,
  error classification, redactor cases, and `MockBackend`; it does not test the
  real transport, response-id correlation, view-model launch behavior, or UI.
- `.github/workflows/ci.yml` runs one macOS-15 job with debug/release builds and
  the harness; no coverage, sanitizer, UI, or packaging job.
- `docs/testing.md:37-39` claims protocol-version compatibility while the client
  does not validate the response version.
- `docs/verification-report.md:83-84` claims reconnect handling while there is no
  automatic reconnect/refresh.
- `README.md` says "no polling" while `AppViewModel` exposes auto-refresh and
  reconciliation polls every 600 ms.

**Impact**

Transport and UI regressions can ship undetected, and operators may rely on
documented behavior that does not exist.

**Root cause hypothesis**

The custom harness was optimized for Command Line Tools and pure logic; docs
describe intended rather than enforced behavior.

**Recommendation**

- Add socketpair-based transport tests, view-model tests for launch/refresh, and
  a redaction display test.
- Add a macOS packaging/signing job when the `.app` path exists.
- Correct README, testing, and verification claims to match code.

## Positive Observations

- Clean separation between UI, client, configuration, and observability modules.
- Backend-authoritative lifecycle with explicit reconciliation and per-VM
  serialization.
- Honest capability model: unsupported daemon features are disabled and
  explained rather than faked.
- Typed request/response models and a useful error taxonomy.
- No network listener, no third-party dependencies, and no privileged helper.
- Pure validators and a deterministic mock backend make most logic testable.
- CI builds both debug and release and runs the assertion harness.

## Verification Notes

- Tests were not executed during this audit; the repository was inspected
  read-only to avoid generating `.build` artifacts.
- The working tree was clean at the observed revision.
- The findings above are based on source and documentation inspection. The
  `SIGPIPE` and no-launch-refresh findings should be confirmed with a small
  runtime test before merging fixes.

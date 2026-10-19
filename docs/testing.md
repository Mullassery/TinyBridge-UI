# Testing — TinyBridge-UI

## Testing approach

XCTest requires Xcode, which is not installed in this development environment
(only Command Line Tools). Tests therefore run as a plain Swift assertion
harness via `swift run TinyBridgeUITests` rather than `swift test`. When Xcode
is available, the same assertions can be migrated to `XCTestCase` subclasses
without changing the logic.

## Test harness

`Tests/TinyBridgeUITests/main.swift` runs assertion-based checks against:

- `TinyBridgeClient` — JSON-RPC request/response encoding/decoding,
  `EnvironmentSummary` decoding (including the daemon's real Debug-derived
  `status` strings), `StartRequest`/`StopRequest` param serialization,
  error-code classification (including recovery from the daemon's generic
  `-32603` via message text), `JSONValue` round-trips, socket-path default.
- `VMConfiguration` — `ResourceValidator` (vCPU/memory/disk ranges, host
  capacity warnings), `PortValidator` (port range, privileged ports, loopback
  default, public-bind warnings, duplicate-binding conflict detection).
- `VMObservability` — `RingBuffer` (fixed capacity, overwrite-oldest),
  `MetricsHistory` (valued vs. nil samples, `hasData`), `Redactor` (private
  keys, bearer tokens, IPs, home paths, emails).
- `MockBackend` — full async lifecycle: list → start → running after boot
  delay → stop → duplicate-start rejection (`alreadyRunning`) → stop-non-running
  rejection (`notRunning`) → doctor.

## Coverage goals

Tests cover the critical state, protocol, and error-handling paths required by
the definition of done:

- VM state transitions (Stopped → Starting → Running → Stopped), including
  parsing the daemon's real wire format.
- Request/response decoding for every RPC method the UI calls.
- Protocol version compatibility (hardcoded `"2.0"`).
- Configuration validation (resources, ports, conflicts).
- Metrics normalization (nil vs. valued, bounded history).
- Event ordering (ring buffer overwrite semantics).
- Error mapping (transport vs. RPC, retryable vs. non-retryable).
- Redaction of sensitive data in diagnostics.

## Running tests

```bash
# Build + run the assertion harness
cd TinyBridge-UI
swift run TinyBridgeUITests
```

Exit code 0 = all passed. A non-zero exit means failures (printed as `FAIL …`).

## Mock backend

`TinyBridgeClient.MockBackend` is a deterministic in-process backend that
models the daemon's lifecycle (Stopped → Starting → Running → Stopped → Stopped)
with configurable boot duration and per-call latency. It never claims
capabilities the real backend lacks (`BackendCapabilities.mock`). It is used
both by the test harness and for offline previews.

## UI testing

UI tests require a running macOS app and are not automated in this release.
The menu bar, main window, and sections are structured so each view depends on
`AppViewModel` (an `@EnvironmentObject`), which can be swapped to `MockBackend`
for offline verification. When Xcode is available, add `XCTest`-based UI tests
that drive `MenuBarView`, `VirtualMachinesView`, and `DiagnosticsView` against
`MockBackend`.

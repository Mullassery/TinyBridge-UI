# Architecture — TinyBridge-UI

TinyBridge-UI is a native macOS menu-bar management application for TinyBridge
micro-VMs. It is a **companion control plane**, not a replacement for TinyBridge's
VM engine. The UI owns presentation and management; TinyBridge core owns VM
execution and Virtualization.framework integration.

## Architectural boundary

```
┌─────────────────────────────────────────────────────────────┐
│                      TinyBridge-UI (this app)               │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   AppView   │  │  ViewModels  │  │   TinyBridge     │   │
│  │  (SwiftUI)  │  │  (SwiftUI)   │  │   Client         │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘   │
│         │                │                   │              │
│         ▼                ▼                   ▼              │
│   MenuBar + MainWindow   State      JSON-RPC over Unix socket│
│   reconciliation         logic                    │         │
└─────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
                    ┌──────────────────────────────┐
                    │   tinybridged (daemon, Rust) │
                    │  ~/.local/share/TinyBridge/  │
                    │    tinybridge.sock           │
                    └──────────────────────────────┘
```

The app talks **only** to `tinybridged` over its existing JSON-RPC 2.0
Unix-domain socket. It never spawns a VM, never calls Virtualization.framework,
and never runs a second control plane.

## Modules

| Module | Responsibility | Depends on |
|---|---|---|
| `TinyBridgeClient` | Typed IPC transport, JSON-RPC 2.0 models, live + mock backends | Foundation, Darwin |
| `VMConfiguration` | VM resource, port-mapping, shared-dir models + validation | Foundation |
| `VMObservability` | Bounded metric ring buffers, diagnostic redaction | Foundation |
| `TinyBridgeUI` | SwiftUI app, menu bar, main window, sections, view models | All three above |

## Key design decisions enforced in code

1. **Backend is source of truth.** `AppViewModel` never marks a VM "running"
   because `start()` returned success — only a reconciled `list()`/`status()`
   read does that. `VMLifecycleState.isRunning` is the single predicate.

2. **Operations serialized per VM.** `pendingOperations` guards against a
   second start/stop for the same VM while one is in flight.

3. **Timeout ≠ failure.** A client-side timeout is logged as a warning and the
   VM is reconciled against the daemon, never declared failed outright.

4. **No fabricated metrics.** `MetricKind.availableSource` returns `nil` for
   every metric because the daemon exposes no usage metrics over RPC. The UI
   renders these as "—" (unknown), never as `0`.

5. **Unsupported = shown as disabled-with-reason.** Port forwarding, config
   editing, snapshots, guest metrics, and the GUI window RPC are not implemented
   by the daemon; the UI surfaces them as explicitly unsupported rather than
   faking them.

6. **Diagnostics redacted.** The `Redactor` strips private keys, bearer tokens,
   IPs, home paths, and emails before diagnostic text is shown or exported.

## Concurrency model

- All blocking socket I/O runs on a dedicated serial `DispatchQueue` (utility
  QoS) inside `UnixSocketTransport`, never on the SwiftUI main actor.
- `TinyBridgeClient` is an `@unchecked Sendable` class wrapping a serial queue;
  `call(_:params:timeout:)` uses `withCheckedThrowingContinuation` to bridge the
  blocking transport into async.
- `AppViewModel` is `@MainActor`. All UI-facing state updates happen there.
- `MockBackend` is an `actor` used by tests for deterministic async lifecycle.

## What the app does NOT do (by design)

- No Electron / embedded browser / Tauri.
- No second VM lifecycle engine or hypervisor.
- No unauthenticated network management endpoint (socket is local, `0600`-ish
  permissions expected from the daemon).
- No `sudo` / privileged helper required routinely.
- No guest OS bundled or managed.

## Integration contract

The client mirrors `crates/tinybridge-core/src/ipc.rs` exactly:
- JSON-RPC 2.0, newline-delimited, over Unix socket at
  `~/Library/Application Support/TinyBridge/tinybridge.sock`
  (overridable via `TINYBRIDGE_SOCKET`).
- One connection per request (same as the TinyBridge CLI).
- Methods: `environment.up`, `environment.down`, `environment.status`,
  `environment.list`, `environment.shell`, `environment.doctor`,
  `environment.repair`, plus `dds.*`.

See [`docs/ipc-protocol.md`](ipc-protocol.md) for the full wire contract.

# Security — TinyBridge-UI

TinyBridge-UI applies least privilege and treats the local control socket as a
privileged management surface.

## Threat model & assumptions

- The TinyBridge daemon (`tinybridged`) runs on the same macOS host and owns
  VM execution. It is codesigned with the `com.apple.security.virtualization`
  entitlement and listens on a Unix socket with restrictive permissions.
- The UI is a **client only** — it never escalates privileges, never spawns a
  VM, and never calls Virtualization.framework.
- The management surface is **local only**. No network port is opened by the
  app. There is no remote management interface and no authentication beyond
  socket filesystem permissions (owned by the daemon).

## Socket & transport

- Default socket path:
  `~/Library/Application Support/TinyBridge/tinybridge.sock`
  (overridable via `TINYBRIDGE_SOCKET`).
- The app connects as a normal user; it does not create, chmod, or chown the
  socket. Socket permissions are the daemon's responsibility.
- All IPC is JSON-RPC over a connected Unix stream. No shell-string
  interpolation is ever used; requests are built as typed structs and encoded
  with `JSONEncoder`.

## Privileges & entitlements

- No routine `root` requirement. The app runs as the invoking user.
- No privileged helper tool. None is needed because the app is a client of the
  already-privileged daemon.
- Entitlements: only those required for a normal GUI app (none beyond the
  default). `com.apple.security.virtualization` is **not** requested — the UI
  does not virtualize. Do **not** add entitlements speculatively.

## Data handling

- **Diagnostics redaction.** `VMObservability.Redactor` strips, before display
  or export: PEM private keys, bearer/authorization tokens, AWS key IDs, long
  hex blobs, IPv4 addresses, home-directory usernames, and email addresses.
  The app never logs credentials, tokens, or private keys.
- No secrets are stored by the app. The only persisted reference is the socket
  path (a filesystem path, not a credential).
- Shared-directory (VirtioFS) paths are validated by the daemon, not the UI.
  The UI models them for future capability only and does not transmit them.

## Input validation

- Resource counts (vCPU, memory, disk) are range-checked against sane bounds
  and host capacity before being presented as editable.
- Ports are range-checked (1–65535); privileged ports (<1024) warn. Loopback
  host binding is the default; binding to `0.0.0.0`/`::`/`*` produces a warning
  that the service is exposed beyond the local Mac. Duplicate host
  address+port+protocol bindings are rejected.
- All user input is validated **before** being sent to the daemon; invalid
  input never reaches the wire.

## Error handling

- A UI timeout is **never** treated as proof that a VM operation failed; the VM
  is reconciled against the daemon. Destructive operations are not
  automatically retried.
- Destructive actions (force-stop) require explicit user confirmation.

## What the app does NOT do

- No unauthenticated network management endpoint.
- No arbitrary command execution through IPC.
- No disabling of Gatekeeper, SIP, TCC, or other macOS protections.
- No bundled guest OS or container runtime.

## Dependencies

- Third-party dependencies: none beyond Apple frameworks (SwiftUI, Foundation,
  AppKit). The package has zero external Swift dependencies, keeping the supply
  chain trivial to audit.

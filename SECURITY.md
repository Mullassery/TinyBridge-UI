# Security Policy

## Supported versions

TinyBridge-UI is alpha software. Only the latest release and the `main` branch
receive fixes.

## Reporting a vulnerability

Please do not open a public issue for a security vulnerability. Use GitHub's
[private vulnerability reporting](https://github.com/Mullassery/TinyBridge-UI/security/advisories/new)
for this repository. If that is unavailable, open an issue titled
"Security contact request" with no vulnerability details.

There is no guaranteed response time or SLA.

## Security model

- **Local socket only.** TinyBridge-UI talks to the `tinybridged` daemon over a
  local Unix socket. It does not expose a network listener.
- **No privileged helper.** The app does not require `sudo` or install a
  privileged helper.
- **Sensitive output is redacted.** Diagnostics redact keys, tokens, and IP
  addresses before display or export.
- **The daemon remains the trust boundary.** TinyBridge-UI is a control plane;
  VM isolation, entitlement handling, and asset integrity are enforced by the
  TinyBridge core. Review that project's security policy before exposing VMs to
  untrusted workloads.
- **No in-guest agent.** Guest telemetry that is not available is shown as
  unavailable, not estimated.

## Scope

The SwiftUI app, IPC client, and local configuration handling are in scope. The
TinyBridge daemon, Virtualization.framework, guest OS, and host macOS are out of
scope.

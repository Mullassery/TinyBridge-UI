# Competitive intelligence

## OSS gap analysis — 2026-10-24

**What matters most here:** the daemon RPCs the UI is missing. Configuration edits and port forwarding are validated but cannot be applied because `tinybridged` exposes no write or forwarding RPC. Closing those two gaps turns TinyBridge-UI from a careful read-only inspector into a control plane that matches UTM and Lima on the workflows users actually perform.

Scope: TinyBridge-UI compared with the OSS desktop managers a macOS developer would realistically evaluate for local Linux VMs or container-backed development. TinyBridge-UI is a companion control plane for `tinybridged`, not a hypervisor, so the comparison separates "VM host with a GUI" from "GUI over an external engine".

### Comparable OSS projects

| Project | GitHub | License | Last activity | Why it is the comparison |
| --- | --- | --- | --- | --- |
| UTM | https://github.com/utmapp/UTM | Apache-2.0 | pushed 2026-10-20 (~36.5k stars) | Native macOS/iOS VM host with a full GUI and Virtualization.framework support |
| Lima | https://github.com/lima-vm/lima | Apache-2.0 | pushed 2026-10-24 (~22.2k stars) | The closest engine peer to TinyBridge; CLI-only, with mounts and port forwarding |
| Rancher Desktop | https://github.com/rancher-sandbox/rancher-desktop | Apache-2.0 | pushed 2026-10-24 (~7.4k stars) | Desktop GUI for local Kubernetes and container management on macOS/Windows/Linux |
| Podman Desktop | https://github.com/containers/podman-desktop | Apache-2.0 | not verified in this pass | Desktop GUI for containers and Kubernetes, the closest "menu-bar control plane" analogy |

Nuance: Rancher Desktop and Podman Desktop manage containers and Kubernetes, not general-purpose Linux VMs, and both are Electron applications. They are included because they compete for the same "local development control plane" attention, not because they are feature-for-feature substitutes. OrbStack is a strong commercial reference but is not OSS and is excluded from the table.

### Capability comparison

| Capability | Ours | UTM | Lima | Rancher Desktop | Podman Desktop | Gap |
| --- | --- | --- | --- | --- | --- | --- |
| Native macOS menu-bar UI | Yes | Partial | No | Partial | Partial | Ours is menu-bar first; the others are window/tray apps |
| No Electron or embedded browser | Yes | Yes | Yes | No | No | Ours and UTM/Lima are native |
| Ships its own VM engine | No | Yes | Yes | Partial | Partial | Ours requires TinyBridge core |
| VM inventory and start/stop | Yes | Yes | Yes | Partial | Partial | Ours covers the core lifecycle |
| Port-forwarding management | Partial | Yes | Yes | Partial | Partial | Ours validates but the daemon does not expose forwarding |
| Configuration editing | Partial | Yes | Yes | Partial | Partial | Ours validates locally but cannot write config |
| Guest CPU/memory/disk metrics | No | Yes | Partial | Partial | Partial | Real gap |
| Snapshot management | No | Yes | Unverified | No | No | Real gap |
| Console or shell access | No | Yes | Yes | Partial | Partial | Ours hands off to the core CLI |
| Log viewer | No | Partial | Yes | Yes | Yes | Real gap |
| Diagnostics with redaction | Yes | Partial | Partial | Partial | Partial | Ours is unusually careful here |
| Container/Kubernetes workflows | No | No | Partial | Yes | Yes | Deliberately out of scope |
| Prebuilt signed app and auto-update | No | Yes | Yes | Yes | Yes | Real gap |
| Cross-platform desktop | No | Partial | Partial | Yes | Yes | Deliberately out of scope |
| Local-only, no privileged helper | Yes | Yes | Partial | No | No | Ours is a differentiator |

### Gaps that matter (ranked)

1. **No guest agent, therefore no real guest metrics.** The UI distinguishes host-observed from guest-reported values and renders unavailable values as an em dash, which is honest, but it means CPU, memory, and disk data inside the VM are absent. UTM can query guest state; Rancher and Podman Desktop surface container/VM resource usage. A small in-guest agent would convert "honest but empty" into actionable monitoring. Effort L.
2. **Configuration studio cannot apply changes.** Edits are validated locally and labelled "would apply if supported" because the daemon has no config-write RPC. UTM and Lima let users change CPU/memory/disk and restart. This is the most visible "the UI knows what you want but cannot do it" gap. Effort M, mostly in the core daemon.
3. **Port forwarding is validate-only.** The README states loopback-first bindings are explicitly unsupported by the current daemon. Lima and UTM offer working forwarding, which is table stakes for "run a web server in the guest, open it on the host". Effort M.
4. **Lifecycle surface stops at start/stop.** There is no snapshot browser, console/shell pane, log viewer, or file-sharing browser, even though the core CLI exposes snapshots, shell, and VirtioFS. UTM exposes snapshots and a console; Rancher and Podman Desktop expose logs and terminals. Effort M per surface, and the core already has the primitives.
5. **No signed/notarized distribution or auto-update.** Installation is `swift build` plus `swift run`. UTM, Rancher Desktop, and Podman Desktop ship downloadable apps with update paths. For a menu-bar utility, a signed `.app`/DMG and an update channel are adoption prerequisites. Effort M.
6. **No standalone value without TinyBridge core and a running daemon.** The architecture is deliberately a companion, but a new user who installs only the UI sees a shell with demo mode. UTM and Lima are self-contained. Bundling or guiding the core install would reduce first-run failure. Effort S-M.
7. **macOS 14+ only and no multi-host management.** This is a defensible scope choice; remote management is explicitly rejected for security. It is listed so the limitation is documented rather than discovered.

### Where we are differentiated

- **Native SwiftUI, no Electron/Tauri/embedded browser**, with a compact menu-bar popover and a separate main window.
- **Reconciled lifecycle state:** a successful start call is never treated as "running"; state comes from a backend read, and timeouts are reconciled rather than declared failures.
- **Honest telemetry:** unavailable metrics render as an em dash, never fabricated; diagnostics redact keys, tokens, and IPs before display or export.
- **Least privilege by design:** local Unix socket only, no sudo, no privileged helper, no unauthenticated remote management.

### Disposition

- **Build:** daemon config-write RPC and a real Apply path (P1, M); port-forwarding RPC and UI (P1, M); snapshot, console, and log surfaces over existing core commands (P2, M each); signed/notarized app with auto-update (P1, M); in-guest metrics agent (P2, L).
- **Integrate/reuse:** drive `snapshot`, `shell`, and `forward` through the existing JSON-RPC control plane rather than duplicating logic; reuse the core's `doctor` output and redaction policy; adopt a standard macOS update framework instead of building one.
- **Defer/reject:** Electron/Tauri, a second hypervisor, container/Kubernetes management (Rancher Desktop and Podman Desktop own that), and remote multi-host management. The companion-control-plane boundary is the product's security story and should stay.

### Sources

- https://github.com/utmapp/UTM (Apache-2.0, pushed 2026-10-20, accessed 2026-10-24)
- https://github.com/lima-vm/lima (Apache-2.0, pushed 2026-10-24, accessed 2026-10-24)
- https://github.com/rancher-sandbox/rancher-desktop (Apache-2.0, pushed 2026-10-24, accessed 2026-10-24)
- https://github.com/containers/podman-desktop (Apache-2.0, access date 2026-10-24; last activity not verified in this pass)
- Repo files inspected: `README.md`, `docs/architecture.md`, `docs/ipc-protocol.md`, `docs/security.md`, `docs/testing.md`

# IPC Protocol — TinyBridge-UI

TinyBridge-UI speaks the **exact** JSON-RPC 2.0 protocol that TinyBridge's
`tinybridged` daemon already serves over a Unix-domain socket. No daemon
changes are required.

## Transport

- **Frame:** newline-delimited (`\n` terminated) JSON.
- **Socket:** `~/Library/Application Support/TinyBridge/tinybridge.sock`
  (Rust: `dirs::data_dir()/TinyBridge/tinybridge.sock`). Override via the
  `TINYBRIDGE_SOCKET` environment variable.
- **Connection model:** one connection per request/response, then close — the
  same model as the TinyBridge CLI (`crates/tinybridge-cli/src/client.rs`).
- **Timeout:** 30 s default per request; 120 s for `environment.up` (boot).

## JSON-RPC envelope

The client mirrors `tinybridge_core::JsonRpcRequest` / `JsonRpcResponse`:

Request:
```json
{"jsonrpc":"2.0","id":1,"method":"environment.list","params":{}}
```

Response (success):
```json
{"jsonrpc":"2.0","id":1,"result":{"environments":[...]}}
```

Response (error):
```json
{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"..."}}
```

## Methods used

| Method | Params | Result | Notes |
|---|---|---|---|
| `environment.list` | `{}` | `{environments:[EnvironmentSummary]}` | Full inventory |
| `environment.status` | `{name?}` | `{environments:[EnvironmentSummary]}` | Single or all |
| `environment.up` | `{name, env_yaml_path?, wait, cpu?, memory?, disk?, gpu?, gpu_memory?}` | `{id,name,status,ip_address}` | Start VM. The current daemon accepts `cpu`/`memory`/`disk`/`gpu`/`gpu_memory` on the wire but ignores them — the UI marks these as "would apply if supported". |
| `environment.down` | `{name, force?}` | `{name,status}` | Stop VM |
| `environment.doctor` | `{name?}` | `{validation: <string>}` | Diagnostics |
| `environment.shell` | `{name,...}` | `{shell_id, socket_path}` | Declared unsupported by the UI |
| `environment.repair` | `{name}` | `{}` | Declared unsupported by the UI |
| `dds.*` | various | various | Declared unsupported by the UI |

Notably absent from the daemon's dispatch (`crates/tinybridge-daemon/src/server.rs`):
port-forwarding CRUD, config read/write, snapshots, a metrics stream, and
`environment.gui.show` (defined as a constant but unhandled → "Unknown method").
The UI treats all of these as explicitly unsupported.

## EnvironmentSummary (wire shape)

Mirrors `tinybridge_core::EnvironmentSummary`:

```json
{
  "id": "<uuid>",
  "name": "<string>",
  "status": "<string>",
  "ip_address": "<string> | null",
  "uptime_secs": <number> | null
}
```

**Important:** `status` is the daemon's Rust `Debug`-derived string, lowercased,
e.g. `"running { uptime_secs: 100 }"`, `"starting { progress_pct: 42 }"`,
`"stopped"`, `"error { message: \"...\" }"`. The client parses this into
`VMLifecycleState` rather than displaying the raw string. Never treat a
successful `up` response as proof the VM is running.

## Error codes

Standard JSON-RPC plus TinyBridge app codes:

| Code | Name | Meaning |
|---|---|---|
| -32700 | parse error | Invalid JSON |
| -32600 | invalid request | |
| -32601 | method not found | |
| -32602 | invalid params | |
| -32603 | internal error | Generic; the daemon funnels most failures here with the real message attached |
| -32001 | environment not found | |
| -32002 | already running | |
| -32003 | not running | |
| -32004 | VM boot failed | |
| -32005 | shell error | |

Because the daemon collapses most errors onto `-32603`, the client also
inspects the error message text to recover the real kind (e.g. "not found"
→ `environmentNotFound`).

## Client error model

`TinyBridgeClientError` separates **transport** failures ("daemon is offline")
from **RPC** errors ("daemon understood and refused"). Transport errors are
retryable; most RPC errors are not. A client-side timeout is never treated as
proof of failure — the VM is reconciled against the daemon afterward.

## Capabilities honesty

`BackendCapabilities` reflects what the daemon genuinely supports:

- lifecycle control: yes
- inventory: yes
- diagnostics: yes
- repair: yes
- shell: yes (daemon), not wired in UI
- dds: yes (daemon), not wired in UI
- guest metrics: **no**
- config editing: **no**
- port forwarding: **no**
- snapshots: **no**
- event stream: **no** (the UI reconciles by polling `environment.list`)

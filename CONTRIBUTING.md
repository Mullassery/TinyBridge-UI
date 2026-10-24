# Contributing to TinyBridge-UI

Thanks for contributing. This is an alpha companion app; review times vary and
there is no merge SLA.

## Before you start

- Read [`README.md`](README.md) and the docs under [`docs/`](docs/) for the
  current IPC contract and UI behavior.
- This app is a control plane for the TinyBridge daemon. Changes that require a
  new daemon RPC should be discussed in the TinyBridge repository first.
- Security issues go through [`SECURITY.md`](SECURITY.md), not public issues.

## Development setup

Requires macOS 14+, Swift 5.10+ (Command Line Tools are sufficient), and a
running `tinybridged` for real VM state.

```bash
swift build
swift test
swift run
```

## Checks before a pull request

```bash
swift build
swift test
```

CI runs the same build and test commands. New behavior needs a test where the
logic is testable without a live daemon; otherwise describe the manual check.

## Pull requests

- Keep changes focused and paste the command you ran.
- Do not fabricate metrics or state; unavailable data must be shown as
  unavailable.
- Never commit daemon sockets, VM images, credentials, or evidence dumps.

## License

Contributions are accepted under the Apache License 2.0.

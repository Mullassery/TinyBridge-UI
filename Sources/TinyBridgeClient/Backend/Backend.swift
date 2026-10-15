import Foundation

/// What a TinyBridge backend actually supports.
///
/// Every flag here is set from the daemon's real RPC surface
/// (`crates/tinybridge-daemon/src/server.rs`). Things the daemon does **not**
/// implement (port forwarding CRUD, config editing, snapshots, a metrics
/// stream, the GUI window method) are `false`, and the UI renders them as
/// explicitly unsupported rather than faking them.
public struct BackendCapabilities: Sendable, Equatable {
    public var lifecycleControl: Bool
    public var inventory: Bool
    public var diagnostics: Bool
    public var repair: Bool
    public var shell: Bool
    public var dds: Bool
    /// The daemon's `environment.up` currently reads only `name` and
    /// `env_yaml_path`; resource overrides (cpu/memory/disk/gpu) are accepted
    /// on the wire but ignored. Reflects that reality.
    public var resourceOverridesAtStart: Bool
    /// No RPC returns CPU/memory/disk/network usage. Guest telemetry would
    /// require an in-guest agent that does not exist yet.
    public var guestMetrics: Bool
    public var configEditing: Bool
    public var portForwarding: Bool
    public var snapshots: Bool
    /// `environment.gui.show` is defined as a constant but not handled by the
    /// daemon's dispatch match, so it currently returns "Unknown method".
    public var guiWindow: Bool
    /// No event/subscription RPC exists; the UI reconciles by polling
    /// `environment.list`.
    public var eventStream: Bool

    public static let live = BackendCapabilities(
        lifecycleControl: true,
        inventory: true,
        diagnostics: true,
        repair: true,
        shell: true,
        dds: true,
        resourceOverridesAtStart: false,
        guestMetrics: false,
        configEditing: false,
        portForwarding: false,
        snapshots: false,
        guiWindow: false,
        eventStream: false
    )

    public static let mock = BackendCapabilities(
        lifecycleControl: true,
        inventory: true,
        diagnostics: true,
        repair: true,
        shell: false,
        dds: false,
        resourceOverridesAtStart: false,
        guestMetrics: false,
        configEditing: false,
        portForwarding: false,
        snapshots: false,
        guiWindow: false,
        eventStream: false
    )
}

/// Result of `environment.doctor`. The daemon returns
/// `{ "validation": "<multiline string>" }`.
public struct DiagnosticReport: Sendable, Equatable {
    public var raw: String
    /// Lines parsed out of the raw string, for a structured list in the UI.
    public var lines: [String]

    public init(raw: String) {
        self.raw = raw
        self.lines = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public static let unavailable = DiagnosticReport(
        raw: "Diagnostics are not available from this backend."
    )
}

/// The boundary the UI depends on. Implemented by `TinyBridgeClient` (live)
/// and `MockBackend` (tests/offline). Keeping the UI behind this protocol is
/// what lets every view be tested without a running VM.
public protocol TinyBridgeBackend: Sendable {
    func listEnvironments() async throws -> [EnvironmentSummary]
    func status(name: String?) async throws -> [EnvironmentSummary]
    func start(_ request: StartRequest) async throws -> StartResponse
    func stop(_ request: StopRequest) async throws -> StopResponse
    func runDoctor(name: String?) async throws -> DiagnosticReport
    func capabilities() async -> BackendCapabilities
}

public extension TinyBridgeBackend {
    /// Convenience used by the UI for both "refresh" and post-operation
    /// reconciliation.
    func refresh() async throws -> [EnvironmentSummary] {
        try await listEnvironments()
    }
}

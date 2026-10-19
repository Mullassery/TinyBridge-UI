import Foundation

/// A deterministic in-process backend used for unit/UI tests and for offline
/// previewing. It models the same lifecycle the real daemon does
/// (Stopped → Starting → Running → Stopping → Stopped) so the UI's async-state
/// handling can be exercised without a VM.
///
/// It never claims capabilities the real backend lacks (see
/// `BackendCapabilities.mock`).
public actor MockBackend: TinyBridgeBackend {
    private var environments: [String: EnvironmentSummary]
    /// How long a VM spends in `.starting` before it becomes `.running`.
    public var bootDuration: Duration
    /// Artificial latency applied to every call, to shake out UI races.
    public var callLatency: Duration
    /// When true, every call throws a transport-like failure — used to test
    /// the disconnected state.
    public var isOffline: Bool
    /// Scripted failure injected on the next `start`/`stop`.
    public var nextStartError: TinyBridgeClientError?
    public var nextStopError: TinyBridgeClientError?

    public init(
        environments: [EnvironmentSummary] = MockBackend.defaultEnvironments,
        bootDuration: Duration = .milliseconds(400),
        callLatency: Duration = .milliseconds(0),
        isOffline: Bool = false
    ) {
        self.environments = Dictionary(
            uniqueKeysWithValues: environments.map { ($0.name, $0) }
        )
        self.bootDuration = bootDuration
        self.callLatency = callLatency
        self.isOffline = isOffline
    }

    public static let defaultEnvironments: [EnvironmentSummary] = [
        EnvironmentSummary(
            id: "11111111-1111-1111-1111-111111111111",
            name: "ros-dev",
            status: "running { uptime_secs: 4210 }",
            ipAddress: "192.168.64.3",
            uptimeSeconds: 4210
        ),
        EnvironmentSummary(
            id: "22222222-2222-2222-2222-222222222222",
            name: "build-box",
            status: "stopped",
            ipAddress: nil,
            uptimeSeconds: nil
        ),
    ]

    // MARK: - Test helpers

    public func setOffline(_ offline: Bool) { isOffline = offline }

    public func injectEnvironment(_ environment: EnvironmentSummary) {
        environments[environment.name] = environment
    }

    public func currentEnvironments() -> [EnvironmentSummary] {
        environments.values.sorted { $0.name < $1.name }
    }

    public func simulateBootComplete(named name: String) {
        guard var env = environments[name] else { return }
        env.status = "running { uptime_secs: 0 }"
        env.uptimeSeconds = 0
        env.ipAddress = "192.168.64.9"
        environments[name] = env
    }

    // MARK: - TinyBridgeBackend

    public func capabilities() async -> BackendCapabilities { .mock }

    public func listEnvironments() async throws -> [EnvironmentSummary] {
        try await gate()
        return currentEnvironments()
    }

    public func status(name: String?) async throws -> [EnvironmentSummary] {
        try await gate()
        if let name {
            return environments[name].map { [$0] } ?? []
        }
        return currentEnvironments()
    }

    public func start(_ request: StartRequest) async throws -> StartResponse {
        try await gate()
        if let error = nextStartError {
            nextStartError = nil
            throw error
        }
        let name = request.name ?? "default"

        if let existing = environments[name], existing.lifecycleState.isRunning {
            throw TinyBridgeClientError.rpc(
                code: RPCErrorCode.alreadyRunning,
                message: "Environment already running",
                rpcCode: .alreadyRunning
            )
        }

        let id = environments[name]?.id ?? UUID().uuidString
        let starting = EnvironmentSummary(
            id: id,
            name: name,
            status: "starting { progress_pct: 0 }",
            ipAddress: nil,
            uptimeSeconds: nil
        )
        environments[name] = starting

        // Progress through Starting then Running, asynchronously, so callers
        // observe real intermediate states.
        let boot = bootDuration
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: boot)
            await self.simulateBootComplete(named: name)
        }

        return StartResponse(id: id, name: name, status: "starting", ipAddress: nil)
    }

    public func stop(_ request: StopRequest) async throws -> StopResponse {
        try await gate()
        if let error = nextStopError {
            nextStopError = nil
            throw error
        }
        let name = request.name ?? "default"
        guard var env = environments[name] else {
            throw TinyBridgeClientError.rpc(
                code: RPCErrorCode.environmentNotFound,
                message: "Environment not found",
                rpcCode: .environmentNotFound
            )
        }
        if !env.lifecycleState.isRunning && !request.force {
            throw TinyBridgeClientError.rpc(
                code: RPCErrorCode.notRunning,
                message: "Environment not running",
                rpcCode: .notRunning
            )
        }
        env.status = "stopped"
        env.ipAddress = nil
        env.uptimeSeconds = nil
        environments[name] = env
        return StopResponse(name: name, status: "stopped")
    }

    public func runDoctor(name: String?) async throws -> DiagnosticReport {
        try await gate()
        let target = name ?? "default"
        let exists = environments[target] != nil
        let report = """
            TinyBridge diagnostics for '\(target)'
            \(exists ? "✓" : "✗") environment registered
            ✓ hypervisor virtualization entitlement present
            ✓ control socket reachable
            ✓ disk image GPT signature present
            """
        return DiagnosticReport(raw: report)
    }

    // MARK: - Private

    private func gate() async throws {
        if callLatency > .zero {
            try? await Task.sleep(for: callLatency)
        }
        if isOffline {
            throw TinyBridgeClientError.transport(
                .connectFailed(path: "<mock>", errno: ENOENT)
            )
        }
    }
}

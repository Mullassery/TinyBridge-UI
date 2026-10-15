import Foundation
import TinyBridgeClient

/// The single source of truth for the running app's presentation state.
///
/// Design rules enforced here:
/// - The backend is the source of truth. We never mark a VM "running" because a
///   start call returned success — only a subsequent reconciled read does that.
/// - Lifecycle operations for the same VM are serialized; duplicate requests
///   are rejected while one is in flight.
/// - A client-side timeout is never treated as proof of failure; we reconcile
///   against the backend afterward.
@MainActor
final class AppViewModel: ObservableObject {

    enum ConnectionState: Equatable {
        case unknown
        case connecting
        case connected
        case disconnected(message: String)

        var isConnected: Bool { self == .connected }

        var label: String {
            switch self {
            case .unknown: return "Not connected"
            case .connecting: return "Connecting…"
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            }
        }

        var symbolName: String {
            switch self {
            case .unknown: return "circle.dashed"
            case .connecting: return "arrow.triangle.2.circlepath"
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "exclamationmark.triangle.fill"
            }
        }
    }

    @Published private(set) var environments: [EnvironmentSummary] = []
    @Published private(set) var capabilities: BackendCapabilities = .live
    @Published private(set) var connectionState: ConnectionState = .unknown
    @Published private(set) var isRefreshing = false
    @Published private(set) var pendingOperations: Set<String> = []
    @Published private(set) var events: [OperationEvent] = []
    @Published var lastError: String?
    @Published private(set) var backendSocketPath: String

    private var backend: TinyBridgeBackend
    private let reconciliationInterval: Duration
    private let reconciliationAttempts: Int
    /// Upper bound on the in-memory event log (performance requirement).
    private let eventLogLimit = 200

    init(
        backend: TinyBridgeBackend? = nil,
        reconciliationInterval: Duration = .milliseconds(600),
        reconciliationAttempts: Int = 20
    ) {
        let resolved = backend ?? TinyBridgeClient()
        self.backend = resolved
        self.reconciliationInterval = reconciliationInterval
        self.reconciliationAttempts = reconciliationAttempts
        self.backendSocketPath = (resolved as? TinyBridgeClient)?.socketPath
            ?? TinyBridgeClient.defaultSocketPath()
    }

    // MARK: - Derived presentation

    var runningCount: Int {
        environments.filter { $0.lifecycleState.isRunning }.count
    }

    var totalCount: Int { environments.count }

    func environment(named name: String) -> EnvironmentSummary? {
        environments.first { $0.name == name }
    }

    func isPending(_ name: String) -> Bool {
        pendingOperations.contains(name)
    }

    // MARK: - Backend configuration

    /// Swap to the deterministic in-process backend (used for offline demo and
    /// for previews). Preserves nothing from the live backend on purpose.
    func useDemoBackend() async {
        backend = MockBackend()
        record(.init(kind: .info, subject: "App", message: "Switched to demo (in-process) backend."))
        await refresh()
    }

    func useLiveBackend() async {
        backend = TinyBridgeClient()
        backendSocketPath = TinyBridgeClient.defaultSocketPath()
        record(.init(kind: .info, subject: "App", message: "Switched to live daemon backend."))
        await refresh()
    }

    // MARK: - Refresh / reconciliation

    func refresh() async {
        if isRefreshing { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            capabilities = await backend.capabilities()
            let list = try await backend.listEnvironments()
            environments = list.sorted { $0.name < $1.name }
            connectionState = .connected
            lastError = nil
        } catch let error as TinyBridgeClientError {
            connectionState = .disconnected(message: error.userMessage)
            lastError = error.userMessage
        } catch {
            connectionState = .disconnected(message: error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    /// Reconcile with the backend until no VM is in a transitional state, a
    /// bounded number of attempts is exhausted, or the connection drops.
    func reconcileUntilSettled() async {
        for _ in 0..<reconciliationAttempts {
            await refresh()
            guard connectionState.isConnected else { return }
            let anyTransitional = environments.contains { $0.lifecycleState.isTransitional }
                || !pendingOperations.isEmpty
            if !anyTransitional { return }
            try? await Task.sleep(for: reconciliationInterval)
        }
    }

    // MARK: - Lifecycle operations

    func start(name: String, cpu: Int? = nil, memoryGB: Int? = nil, diskGB: Int? = nil) async {
        guard !pendingOperations.contains(name) else {
            record(.init(kind: .warning, subject: name, message: "A start/stop operation is already in progress."))
            return
        }
        pendingOperations.insert(name)
        record(.init(kind: .info, subject: name, message: "Start requested."))
        defer { pendingOperations.remove(name) }

        do {
            _ = try await backend.start(StartRequest(
                name: name,
                wait: true,
                cpu: cpu.map(UInt32.init),
                memoryGB: memoryGB.map(UInt64.init),
                diskGB: diskGB.map(UInt64.init)
            ))
            record(.init(kind: .success, subject: name, message: "Start accepted; waiting for Running state."))
        } catch let error as TinyBridgeClientError {
            // A timeout is not proof of failure — reconcile rather than declare
            // it failed outright.
            if case .timedOut = error {
                record(.init(kind: .warning, subject: name, message: "Start timed out; reconciling with the daemon."))
            } else {
                record(.init(kind: .failure, subject: name, message: error.userMessage))
                lastError = error.userMessage
            }
        } catch {
            record(.init(kind: .failure, subject: name, message: error.localizedDescription))
            lastError = error.localizedDescription
        }

        await reconcileUntilSettled()
    }

    func stop(name: String, force: Bool) async {
        guard !pendingOperations.contains(name) else {
            record(.init(kind: .warning, subject: name, message: "A start/stop operation is already in progress."))
            return
        }
        pendingOperations.insert(name)
        record(.init(kind: .info, subject: name, message: force ? "Force-stop requested." : "Graceful stop requested."))
        defer { pendingOperations.remove(name) }

        do {
            _ = try await backend.stop(StopRequest(name: name, force: force))
            record(.init(kind: .success, subject: name, message: "Stop accepted; waiting for Stopped state."))
        } catch let error as TinyBridgeClientError {
            if case .timedOut = error {
                record(.init(kind: .warning, subject: name, message: "Stop timed out; reconciling with the daemon."))
            } else {
                record(.init(kind: .failure, subject: name, message: error.userMessage))
                lastError = error.userMessage
            }
        } catch {
            record(.init(kind: .failure, subject: name, message: error.localizedDescription))
            lastError = error.localizedDescription
        }

        await reconcileUntilSettled()
    }

    func doctor(name: String?) async -> DiagnosticReport {
        do {
            let report = try await backend.runDoctor(name: name)
            record(.init(kind: .info, subject: name ?? "all", message: "Ran diagnostics."))
            return report
        } catch let error as TinyBridgeClientError {
            return DiagnosticReport(raw: error.userMessage)
        } catch {
            return DiagnosticReport(raw: error.localizedDescription)
        }
    }

    // MARK: - Events

    private func record(_ event: OperationEvent) {
        events.insert(event, at: 0)
        if events.count > eventLogLimit {
            events.removeLast(events.count - eventLogLimit)
        }
    }

    func clearEvents() {
        events.removeAll()
    }

    func dismissError() {
        lastError = nil
    }
}

import Foundation

/// Matches `tinybridge_core::EnvironmentSummary` exactly
/// (`crates/tinybridge-core/src/ipc.rs`), which is what the daemon returns for
/// `environment.list` and `environment.status`.
public struct EnvironmentSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    /// Raw backend status string. Prefer `lifecycleState` for presentation.
    public var status: String
    public var ipAddress: String?
    public var uptimeSeconds: UInt64?

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case ipAddress = "ip_address"
        case uptimeSeconds = "uptime_secs"
    }

    /// Parsed lifecycle state. This is the value the UI renders — never the raw
    /// string.
    public var lifecycleState: VMLifecycleState {
        VMLifecycleState.parse(status)
    }

    public init(
        id: String,
        name: String,
        status: String,
        ipAddress: String? = nil,
        uptimeSeconds: UInt64? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.ipAddress = ipAddress
        self.uptimeSeconds = uptimeSeconds
    }
}

/// Response envelope for `environment.list` / `environment.status`
/// (`tinybridge_core::ListResponse` / `StatusResponse`).
public struct EnvironmentListResponse: Codable, Sendable, Equatable {
    public var environments: [EnvironmentSummary]

    public init(environments: [EnvironmentSummary]) {
        self.environments = environments
    }
}

/// `tinybridge_core::UpResponse`.
public struct StartResponse: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var status: String
    public var ipAddress: String?

    public enum CodingKeys: String, CodingKey {
        case id, name, status
        case ipAddress = "ip_address"
    }
}

/// `tinybridge_core::DownResponse`.
public struct StopResponse: Codable, Sendable, Equatable {
    public var name: String
    public var status: String

    public init(name: String, status: String) {
        self.name = name
        self.status = status
    }
}

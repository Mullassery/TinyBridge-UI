import Foundation

/// Resource allocation for a VM. Values are validated before being shown as
/// editable; the TinyBridge daemon currently ignores start-time overrides, so
/// these are treated as *desired configuration* and surfaced honestly as such.
public struct ResourceConfiguration: Sendable, Equatable {
    public var cpuCount: Int
    public var memoryGB: Int
    public var diskGB: Int

    public init(cpuCount: Int, memoryGB: Int, diskGB: Int) {
        self.cpuCount = cpuCount
        self.memoryGB = memoryGB
        self.diskGB = diskGB
    }

    /// TinyBridge's documented defaults (`TinyBridgeConfig::default`).
    public static let tinyBridgeDefault = ResourceConfiguration(
        cpuCount: 2, memoryGB: 4, diskGB: 20
    )
}

/// Transport protocol for a port mapping.
public enum PortProtocol: String, Sendable, CaseIterable, Codable, Equatable {
    case tcp
    case udp

    public var label: String { rawValue.uppercased() }
}

/// How the VM's network is attached.
///
/// TinyBridge is NAT-only by default (see `SECURITY.md`). Bridged mode is not
/// exposed by the backend and is therefore not offered as a selectable change —
/// only documented.
public enum NetworkMode: String, Sendable, Codable, Equatable {
    case nat
    case bridged

    public var displayName: String {
        switch self {
        case .nat: return "NAT"
        case .bridged: return "Bridged"
        }
    }

    public var isSupportedByBackend: Bool {
        self == .nat
    }
}

/// A single host→guest port-forwarding rule.
///
/// The default host binding is loopback, so a rule never widens exposure
/// beyond the local Mac unless the user explicitly changes the host address.
public struct PortMapping: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var hostAddress: String
    public var hostPort: Int
    public var guestAddress: String
    public var guestPort: Int
    public var proto: PortProtocol
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        hostAddress: String = PortMapping.loopback,
        hostPort: Int,
        guestAddress: String = PortMapping.loopback,
        guestPort: Int,
        proto: PortProtocol = .tcp,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.hostAddress = hostAddress
        self.hostPort = hostPort
        self.guestAddress = guestAddress
        self.guestPort = guestPort
        self.proto = proto
        self.isEnabled = isEnabled
    }

    public static let loopback = "127.0.0.1"

    /// True when the rule binds to all interfaces rather than loopback.
    public var bindsBeyondLoopback: Bool {
        let addr = hostAddress.trimmingCharacters(in: .whitespaces)
        return addr == "0.0.0.0" || addr == "::" || addr == "*" || addr.isEmpty
    }

    public var summary: String {
        "\(hostAddress):\(hostPort) → \(guestAddress):\(guestPort) (\(proto.label))"
    }
}

/// A host directory shared into the guest (VirtioFS). Not yet wired to a real
/// FFI call by the core, so this is modeled for future capability only.
public struct SharedDirectory: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var hostPath: String
    public var guestPath: String
    public var readOnly: Bool

    public init(id: UUID = UUID(), hostPath: String, guestPath: String, readOnly: Bool = true) {
        self.id = id
        self.hostPath = hostPath
        self.guestPath = guestPath
        self.readOnly = readOnly
    }
}

/// The inspectable configuration of a VM as far as the backend can report it.
public struct VMConfiguration: Sendable, Equatable {
    public var name: String
    public var resources: ResourceConfiguration
    public var networkMode: NetworkMode
    public var portMappings: [PortMapping]
    public var sharedDirectories: [SharedDirectory]

    public init(
        name: String,
        resources: ResourceConfiguration = .tinyBridgeDefault,
        networkMode: NetworkMode = .nat,
        portMappings: [PortMapping] = [],
        sharedDirectories: [SharedDirectory] = []
    ) {
        self.name = name
        self.resources = resources
        self.networkMode = networkMode
        self.portMappings = portMappings
        self.sharedDirectories = sharedDirectories
    }
}

import Foundation

/// Parameters for `environment.up`. Mirrors `tinybridge_core::UpParams` plus
/// the resource overrides the CLI sends (`cpu`, `memory`, `disk`, `gpu`,
/// `gpu_memory`) — see `crates/tinybridge-cli/src/client.rs::up`.
public struct StartRequest: Sendable, Equatable {
    public var name: String?
    public var envYAMLPath: String?
    public var wait: Bool
    public var cpu: UInt32?
    public var memoryGB: UInt64?
    public var diskGB: UInt64?
    public var gpu: Bool?
    public var gpuMemoryGB: UInt32?

    public init(
        name: String? = nil,
        envYAMLPath: String? = nil,
        wait: Bool = true,
        cpu: UInt32? = nil,
        memoryGB: UInt64? = nil,
        diskGB: UInt64? = nil,
        gpu: Bool? = nil,
        gpuMemoryGB: UInt32? = nil
    ) {
        self.name = name
        self.envYAMLPath = envYAMLPath
        self.wait = wait
        self.cpu = cpu
        self.memoryGB = memoryGB
        self.diskGB = diskGB
        self.gpu = gpu
        self.gpuMemoryGB = gpuMemoryGB
    }

    public var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["wait": .bool(wait)]
        if let name { object["name"] = .string(name) }
        if let envYAMLPath { object["env_yaml_path"] = .string(envYAMLPath) }
        if let cpu { object["cpu"] = .integer(Int(cpu)) }
        if let memoryGB { object["memory"] = .integer(Int(memoryGB)) }
        if let diskGB { object["disk"] = .integer(Int(diskGB)) }
        if let gpu { object["gpu"] = .bool(gpu) }
        if let gpuMemoryGB { object["gpu_memory"] = .integer(Int(gpuMemoryGB)) }
        return .object(object)
    }
}

/// Parameters for `environment.down`.
public struct StopRequest: Sendable, Equatable {
    public var name: String?
    public var force: Bool

    public init(name: String? = nil, force: Bool = false) {
        self.name = name
        self.force = force
    }

    public var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["force": .bool(force)]
        if let name { object["name"] = .string(name) }
        return .object(object)
    }
}

/// Parameters for `environment.status`.
public struct StatusRequest: Sendable, Equatable {
    public var name: String?

    public init(name: String? = nil) {
        self.name = name
    }

    public var jsonValue: JSONValue {
        if let name { return .object(["name": .string(name)]) }
        return .object([:])
    }
}

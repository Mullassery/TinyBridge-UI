import Foundation

/// JSON-RPC 2.0 request, matching `crates/tinybridge-core/src/ipc.rs::JsonRpcRequest`.
///
/// TinyBridge's daemon speaks newline-delimited JSON-RPC 2.0 over a
/// Unix-domain socket. The `id` field is a monotonically increasing integer.
public struct JSONRPCRequest: Codable, Sendable, Equatable {
    public var jsonrpc: String
    public var id: UInt64
    public var method: String
    public var params: JSONValue

    public init(id: UInt64, method: String, params: JSONValue = .object([:])) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 response. Exactly one of `result`/`error` is present on a
/// well-formed response.
public struct JSONRPCResponse: Codable, Sendable, Equatable {
    public var jsonrpc: String
    public var id: UInt64
    public var result: JSONValue?
    public var error: JSONRPCError?
}

/// JSON-RPC 2.0 error object.
public struct JSONRPCError: Codable, Sendable, Equatable, Error {
    public var code: Int
    public var message: String
    public var data: JSONValue?
}

/// Error codes used by TinyBridge, mirroring `ipc::error_codes`.
public enum RPCErrorCode {
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603

    public static let environmentNotFound = -32001
    public static let alreadyRunning = -32002
    public static let notRunning = -32003
    public static let vmBootFailed = -32004
    public static let shellError = -32005
}

/// Method names, mirroring `ipc::methods`. Using these literals from one place
/// keeps a typo from silently becoming a "method not found" at runtime.
public enum RPCMethod {
    public static let environmentUp = "environment.up"
    public static let environmentDown = "environment.down"
    public static let environmentStatus = "environment.status"
    public static let environmentList = "environment.list"
    public static let environmentShell = "environment.shell"
    public static let environmentGUIShow = "environment.gui.show"
    public static let environmentGUIHide = "environment.gui.hide"
    public static let environmentDoctor = "environment.doctor"
    public static let environmentRepair = "environment.repair"

    public static let ddsStatus = "dds.status"
    public static let ddsList = "dds.list"
    public static let ddsEnable = "dds.enable"
    public static let ddsDisable = "dds.disable"
}

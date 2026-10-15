import Foundation

/// Errors the rest of the app sees from the client layer. They carry enough
/// structure for the UI to choose between "daemon is offline, offer reconnect"
/// and "the daemon understood us and refused".
public enum TinyBridgeClientError: Error, Equatable {
    case transport(TransportError)
    /// The backend returned a JSON-RPC error object.
    case rpc(code: Int, message: String, rpcCode: TinyBridgeRPCErrorKind)
    /// The response JSON did not match the expected shape.
    case decoding(String)
    /// The request was malformed before it was ever sent.
    case invalidRequest(String)
    /// The operation exceeded the client-side deadline.
    case timedOut(method: String)

    public var userMessage: String {
        switch self {
        case .transport(let t): return t.userMessage
        case .rpc(_, let message, let kind): return kind.userMessage(fallback: message)
        case .decoding(let detail):
            return "Unexpected response from the daemon: \(detail)"
        case .invalidRequest(let detail):
            return "Invalid request: \(detail)"
        case .timedOut(let method):
            return "\(method) timed out. The VM operation may still be completing — refresh to reconcile."
        }
    }

    /// Whether retrying the same operation could plausibly succeed.
    public var isRetryable: Bool {
        switch self {
        case .transport: return true
        case .timedOut: return true
        case .rpc(_, _, let kind): return kind == .internal
        case .decoding, .invalidRequest: return false
        }
    }
}

/// Classification of backend errors that is robust to the daemon collapsing
/// most failures onto `INTERNAL_ERROR` (-32603): we also inspect the message
/// text, because `server.rs` returns every manager error as INTERNAL_ERROR
/// with the underlying string attached.
public enum TinyBridgeRPCErrorKind: String, Sendable, Equatable {
    case environmentNotFound
    case alreadyRunning
    case notRunning
    case bootFailed
    case shellError
    case internalError

    public func userMessage(fallback: String) -> String {
        switch self {
        case .environmentNotFound: return "No such VM. It may have been removed."
        case .alreadyRunning: return "That VM is already running."
        case .notRunning: return "That VM is not running."
        case .bootFailed: return "The VM failed to boot. Check Diagnostics for details."
        case .shellError: return "The shell session could not be created."
        case .internalError: return fallback.isEmpty ? "The daemon reported an internal error." : fallback
        }
    }

    /// Map a JSON-RPC error code + message to a kind.
    public static func classify(code: Int, message: String) -> TinyBridgeRPCErrorKind {
        switch code {
        case RPCErrorCode.environmentNotFound: return .environmentNotFound
        case RPCErrorCode.alreadyRunning: return .alreadyRunning
        case RPCErrorCode.notRunning: return .notRunning
        case RPCErrorCode.vmBootFailed: return .bootFailed
        case RPCErrorCode.shellError: return .shellError
        default: break
        }

        // The daemon currently funnels everything through INTERNAL_ERROR with
        // the original message, so fall back to message inspection.
        let lower = message.lowercased()
        if lower.contains("not found") { return .environmentNotFound }
        if lower.contains("already running") { return .alreadyRunning }
        if lower.contains("not running") { return .notRunning }
        if lower.contains("failed to start") || lower.contains("boot") { return .bootFailed }
        if lower.contains("shell") { return .shellError }
        return .internalError
    }
}

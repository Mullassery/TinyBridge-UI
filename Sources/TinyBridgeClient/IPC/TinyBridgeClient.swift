import Foundation

/// Monotonic JSON-RPC request-id generator.
private actor RequestIDGenerator {
    private var next: UInt64 = 1
    func take() -> UInt64 {
        let id = next
        next &+= 1
        return id
    }
}

/// The live TinyBridge control-plane client.
///
/// Speaks the exact JSON-RPC-over-Unix-socket protocol the daemon serves.
/// Blocking socket I/O runs on a dedicated serial queue, never on the main
/// actor, so the UI stays responsive during a slow `environment.up`.
public final class TinyBridgeClient: TinyBridgeBackend, @unchecked Sendable {
    private let transport: UnixSocketTransport
    private let defaultTimeout: TimeInterval
    private let idGenerator = RequestIDGenerator()
    private let queue = DispatchQueue(label: "com.tinybridge.ui.ipc", qos: .utility)

    /// - Parameters:
    ///   - socketPath: override for the control socket. Defaults to
    ///     `TINYBRIDGE_SOCKET` if set, otherwise
    ///     `~/Library/Application Support/TinyBridge/tinybridge.sock`, which is
    ///     `dirs::data_dir()/TinyBridge/tinybridge.sock` on macOS — the same
    ///     path `tinybridge_core::TinyBridgeConfig::socket_path()` resolves.
    ///   - timeout: per-request socket timeout in seconds.
    public init(socketPath: String? = nil, timeout: TimeInterval = 30) {
        let resolved = socketPath
            ?? ProcessInfo.processInfo.environment["TINYBRIDGE_SOCKET"]
            ?? TinyBridgeClient.defaultSocketPath()
        self.transport = UnixSocketTransport(path: resolved)
        self.defaultTimeout = timeout
    }

    public var socketPath: String { transport.path }

    public static func defaultSocketPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support/TinyBridge/tinybridge.sock")
            .path
    }

    // MARK: - TinyBridgeBackend

    public func listEnvironments() async throws -> [EnvironmentSummary] {
        let result = try await call(RPCMethod.environmentList, params: .object([:]))
        return try decodeEnvironments(result)
    }

    public func status(name: String?) async throws -> [EnvironmentSummary] {
        let params = StatusRequest(name: name).jsonValue
        let result = try await call(RPCMethod.environmentStatus, params: params)
        return try decodeEnvironments(result)
    }

    public func start(_ request: StartRequest) async throws -> StartResponse {
        // `environment.up` can legitimately take a while (boot). Use a longer
        // deadline than the default.
        let result = try await call(
            RPCMethod.environmentUp,
            params: request.jsonValue,
            timeout: max(defaultTimeout, 120)
        )
        do {
            return try JSONDecoder().decode(StartResponse.self, from: try encodeToData(result))
        } catch {
            throw TinyBridgeClientError.decoding(String(describing: error))
        }
    }

    public func stop(_ request: StopRequest) async throws -> StopResponse {
        let result = try await call(
            RPCMethod.environmentDown,
            params: request.jsonValue,
            timeout: max(defaultTimeout, 60)
        )
        do {
            return try JSONDecoder().decode(StopResponse.self, from: try encodeToData(result))
        } catch {
            throw TinyBridgeClientError.decoding(String(describing: error))
        }
    }

    public func runDoctor(name: String?) async throws -> DiagnosticReport {
        let params = StatusRequest(name: name).jsonValue
        let result = try await call(RPCMethod.environmentDoctor, params: params)
        let validation = result["validation"].stringValue ?? ""
        return DiagnosticReport(raw: validation)
    }

    public func capabilities() async -> BackendCapabilities {
        .live
    }

    // MARK: - Core call

    public func call(
        _ method: String,
        params: JSONValue,
        timeout: TimeInterval? = nil
    ) async throws -> JSONValue {
        let id = await idGenerator.take()
        let request = JSONRPCRequest(id: id, method: method, params: params)

        let payload: Data
        do {
            var data = try JSONEncoder().encode(request)
            data.append(0x0A) // newline-delimited framing
            payload = data
        } catch {
            throw TinyBridgeClientError.invalidRequest(String(describing: error))
        }

        let effectiveTimeout = timeout ?? defaultTimeout
        let transport = self.transport

        let responseData: Data
        do {
            responseData = try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        let data = try transport.roundTrip(payload, timeout: effectiveTimeout)
                        continuation.resume(returning: data)
                    } catch let error as TransportError {
                        continuation.resume(throwing: error)
                    } catch {
                        continuation.resume(throwing: TransportError.connectionClosedBeforeResponse)
                    }
                }
            }
        } catch let error as TransportError {
            if error == .timedOut {
                throw TinyBridgeClientError.timedOut(method: method)
            }
            throw TinyBridgeClientError.transport(error)
        }

        let response: JSONRPCResponse
        do {
            response = try JSONDecoder().decode(JSONRPCResponse.self, from: responseData)
        } catch {
            let snippet = String(data: responseData.prefix(200), encoding: .utf8) ?? "<binary>"
            throw TinyBridgeClientError.transport(
                .malformedResponse(underlying: snippet.isEmpty ? String(describing: error) : snippet)
            )
        }

        if let rpcError = response.error {
            let kind = TinyBridgeRPCErrorKind.classify(code: rpcError.code, message: rpcError.message)
            throw TinyBridgeClientError.rpc(code: rpcError.code, message: rpcError.message, rpcCode: kind)
        }

        return response.result ?? .null
    }

    // MARK: - Decoding helpers

    private func decodeEnvironments(_ value: JSONValue) throws -> [EnvironmentSummary] {
        do {
            return try JSONDecoder()
                .decode(EnvironmentListResponse.self, from: try encodeToData(value))
                .environments
        } catch {
            throw TinyBridgeClientError.decoding(String(describing: error))
        }
    }

    private func encodeToData(_ value: JSONValue) throws -> Data {
        try JSONEncoder().encode(value)
    }
}

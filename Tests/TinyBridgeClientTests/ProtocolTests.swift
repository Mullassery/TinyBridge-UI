import XCTest
@testable import TinyBridgeClient

final class ProtocolTests: XCTestCase {

    func testRequestEncodesJSONRPCShape() throws {
        let request = JSONRPCRequest(id: 7, method: RPCMethod.environmentList, params: .object([:]))
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json?["id"] as? Int, 7)
        XCTAssertEqual(json?["method"] as? String, "environment.list")
    }

    func testResponseDecodesSuccess() throws {
        let json = #"{"jsonrpc":"2.0","id":1,"result":{"environments":[]}}"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: json)
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)
    }

    func testResponseDecodesError() throws {
        let json = #"{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"Environment not found"}}"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: json)
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error?.code, -32603)
        XCTAssertEqual(response.error?.message, "Environment not found")
    }

    func testEnvironmentSummaryDecodesRealWireShape() throws {
        // Mirrors the daemon's EnvironmentSummary serialization exactly, including
        // the Debug-derived status string.
        let json = """
        {"environments":[{
            "id":"abc",
            "name":"ros-dev",
            "status":"running { uptime_secs: 100 }",
            "ip_address":"192.168.64.3",
            "uptime_secs":100
        }]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(EnvironmentListResponse.self, from: json)
        XCTAssertEqual(decoded.environments.count, 1)
        let env = decoded.environments[0]
        XCTAssertEqual(env.name, "ros-dev")
        XCTAssertEqual(env.ipAddress, "192.168.64.3")
        XCTAssertEqual(env.uptimeSeconds, 100)
        XCTAssertEqual(env.lifecycleState, .running)
    }

    func testEnvironmentSummaryDecodesNullIP() throws {
        let json = #"{"environments":[{"id":"a","name":"x","status":"stopped","ip_address":null,"uptime_secs":null}]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(EnvironmentListResponse.self, from: json)
        XCTAssertNil(decoded.environments[0].ipAddress)
        XCTAssertNil(decoded.environments[0].uptimeSeconds)
    }

    func testStartRequestOmitsNilFields() {
        let request = StartRequest(name: "vm1", wait: true)
        let object = request.jsonValue.objectValue
        XCTAssertEqual(object?["name"], .string("vm1"))
        XCTAssertEqual(object?["wait"], .bool(true))
        XCTAssertNil(object?["cpu"])
        XCTAssertNil(object?["env_yaml_path"])
    }

    func testStartRequestIncludesOverridesWhenPresent() {
        let request = StartRequest(name: "vm1", wait: true, cpu: 4, memoryGB: 8)
        let object = request.jsonValue.objectValue
        XCTAssertEqual(object?["cpu"], .integer(4))
        XCTAssertEqual(object?["memory"], .integer(8))
    }

    func testErrorClassificationByMessageWhenCodeIsGenericInternal() {
        // The daemon funnels most errors through INTERNAL_ERROR; classification
        // must still recover the real meaning from the message.
        XCTAssertEqual(
            TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.internalError, message: "Environment not found"),
            .environmentNotFound
        )
        XCTAssertEqual(
            TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.internalError, message: "Environment already running"),
            .alreadyRunning
        )
        XCTAssertEqual(
            TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.internalError, message: "Environment not running"),
            .notRunning
        )
    }

    func testErrorClassificationByExplicitCode() {
        XCTAssertEqual(
            TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.vmBootFailed, message: "whatever"),
            .bootFailed
        )
    }

    func testJSONValueRoundTrip() throws {
        let value = JSONValue.object([
            "a": .integer(1),
            "b": .string("x"),
            "c": .bool(true),
            "d": .array([.integer(1), .null]),
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueSubscriptMissingKeyIsNull() {
        let value = JSONValue.object(["a": .integer(1)])
        XCTAssertEqual(value["missing"], .null)
        XCTAssertEqual(value["a"], .integer(1))
    }

    func testDefaultSocketPathMatchesDaemonConvention() {
        let path = TinyBridgeClient.defaultSocketPath()
        XCTAssertTrue(path.hasSuffix("Library/Application Support/TinyBridge/tinybridge.sock"))
    }
}

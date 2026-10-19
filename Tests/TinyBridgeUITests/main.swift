import Foundation
import TinyBridgeClient
import VMConfiguration
import VMObservability

var failures = 0

func check<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
    if actual != expected {
        print("FAIL \(file):\(line): \(message) — expected \(expected), got \(actual)")
        failures += 1
    } else {
        print("ok   \(message)")
    }
}

func checkTrue(_ value: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !value {
        print("FAIL \(file):\(line): \(message) — expected true")
        failures += 1
    } else {
        print("ok   \(message)")
    }
}

func checkFalse(_ value: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if value {
        print("FAIL \(file):\(line): \(message) — expected false")
        failures += 1
    } else {
        print("ok   \(message)")
    }
}

func runAllTests() async throws {
    // MARK: - VMLifecycleState
    do {
        print("\n=== VMLifecycleState ===")
        check(VMLifecycleState.parse("stopped"), .stopped, "parse stopped")
        check(VMLifecycleState.parse("running"), .running, "parse running")
        check(VMLifecycleState.parse("stopping"), .stopping, "parse stopping")
        check(VMLifecycleState.parse("starting"), .starting(progressPercent: nil), "parse starting")
        check(VMLifecycleState.parse("error"), .failed(message: nil), "parse error")
        check(VMLifecycleState.parse("running { uptime_secs: 4210 }"), .running, "parse debug running")
        check(VMLifecycleState.parse("starting { progress_pct: 42 }"), .starting(progressPercent: 42), "parse starting with pct")
        check(VMLifecycleState.parse("error { message: \"disk missing\" }"), .failed(message: "disk missing"), "parse error with message")
        check(VMLifecycleState.parse("quiescing"), .unknown(raw: "quiescing"), "parse unknown")

        checkTrue(VMLifecycleState.parse("running").isRunning, "running.isRunning")
        checkTrue(VMLifecycleState.parse("running { uptime_secs: 1 }").isRunning, "debug running.isRunning")
        checkFalse(VMLifecycleState.parse("starting { progress_pct: 99 }").isRunning, "starting not running")
        checkFalse(VMLifecycleState.parse("stopped").isRunning, "stopped not running")

        checkTrue(VMLifecycleState.parse("starting").isTransitional, "starting transitional")
        checkTrue(VMLifecycleState.parse("stopping").isTransitional, "stopping transitional")
        checkFalse(VMLifecycleState.parse("running").isTransitional, "running not transitional")
    }

    // MARK: - JSONRPC / EnvironmentSummary
    do {
        print("\n=== JSONRPC / EnvironmentSummary ===")
        let req = JSONRPCRequest(id: 7, method: RPCMethod.environmentList, params: .object([:]))
        let reqData = try! JSONEncoder().encode(req)
        let reqJson = try! JSONSerialization.jsonObject(with: reqData) as! [String: Any]
        check(reqJson["jsonrpc"] as? String ?? "", "2.0", "request jsonrpc")
        check(reqJson["id"] as? Int ?? -1, 7, "request id")
        check(reqJson["method"] as? String ?? "", "environment.list", "request method")

        let respJson = #"{"jsonrpc":"2.0","id":1,"result":{"environments":[]}}"#.data(using: .utf8)!
        let resp = try! JSONDecoder().decode(JSONRPCResponse.self, from: respJson)
        checkTrue(resp.result != nil, "response has result")
        checkTrue(resp.error == nil, "response no error")

        let errJson = #"{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"Environment not found"}}"#.data(using: .utf8)!
        let errResp = try! JSONDecoder().decode(JSONRPCResponse.self, from: errJson)
        checkTrue(errResp.error?.code == -32603, "error code")
        check(errResp.error?.message ?? "", "Environment not found", "error message")

        let envJson = """
        {"environments":[{"id":"abc","name":"ros-dev","status":"running { uptime_secs: 100 }","ip_address":"192.168.64.3","uptime_secs":100}]}
        """.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(EnvironmentListResponse.self, from: envJson)
        check(decoded.environments.count, 1, "env list count")
        let env = decoded.environments[0]
        check(env.name, "ros-dev", "env name")
        check(env.ipAddress ?? "", "192.168.64.3", "env ip")
        check(env.uptimeSeconds ?? 0, 100, "env uptime")
        check(env.lifecycleState, .running, "env lifecycle running")
        check(env.id, "abc", "env id")

        let nullJson = #"{"environments":[{"id":"a","name":"x","status":"stopped","ip_address":null,"uptime_secs":null}]}"#.data(using: .utf8)!
        let nullDecoded = try! JSONDecoder().decode(EnvironmentListResponse.self, from: nullJson)
        checkTrue(nullDecoded.environments[0].ipAddress == nil, "null ip")
        checkTrue(nullDecoded.environments[0].uptimeSeconds == nil, "null uptime")
    }

    // MARK: - Start/Stop requests
    do {
        print("\n=== Start/Stop Requests ===")
        let startReq = StartRequest(name: "vm1", wait: true)
        let obj = startReq.jsonValue.objectValue
        check(obj?["name"], .string("vm1"), "start name")
        check(obj?["wait"], .bool(true), "start wait")
        checkTrue(obj?["cpu"] == nil, "start no cpu")
        checkTrue(obj?["env_yaml_path"] == nil, "start no yaml")

        let startFull = StartRequest(name: "vm1", wait: true, cpu: 4, memoryGB: 8)
        let obj2 = startFull.jsonValue.objectValue
        check(obj2?["cpu"], .integer(4), "start cpu")
        check(obj2?["memory"], .integer(8), "start memory")

        let stopReq = StopRequest(name: "vm1", force: true)
        let stopObj = stopReq.jsonValue.objectValue
        check(stopObj?["name"], .string("vm1"), "stop name")
        check(stopObj?["force"], .bool(true), "stop force")

        let stopEmpty = StopRequest()
        let stopEmptyObj = stopEmpty.jsonValue.objectValue
        checkTrue(stopEmptyObj?["name"] == nil, "stop no name")
        check(stopEmptyObj?["force"], .bool(false), "stop no force")
    }

    // MARK: - Error classification
    do {
        print("\n=== Error Classification ===")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.environmentNotFound, message: "x"), .environmentNotFound, "env not found code")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.alreadyRunning, message: "x"), .alreadyRunning, "already running code")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.notRunning, message: "x"), .notRunning, "not running code")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.vmBootFailed, message: "x"), .bootFailed, "boot failed code")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.internalError, message: "Environment not found"), .environmentNotFound, "internal + not found msg")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.internalError, message: "Environment already running"), .alreadyRunning, "internal + already running msg")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.internalError, message: "Environment not running"), .notRunning, "internal + not running msg")
        check(TinyBridgeRPCErrorKind.classify(code: RPCErrorCode.internalError, message: "something else"), .internalError, "internal fallback")
    }

    // MARK: - JSONValue
    do {
        print("\n=== JSONValue ===")
        let value: JSONValue = .object(["a": .integer(1), "b": .string("x"), "c": .bool(true), "d": .array([.integer(1), .null])])
        let data = try! JSONEncoder().encode(value)
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: data)
        check(decoded, value, "JSONValue roundtrip")
        let obj = JSONValue.object(["a": .integer(1)])
        check(obj["missing"], .null, "subscript missing is null")
        check(obj["a"], .integer(1), "subscript present")
    }

    // MARK: - Socket path
    do {
        print("\n=== Socket Path ===")
        let path = TinyBridgeClient.defaultSocketPath()
        checkTrue(path.hasSuffix("Library/Application Support/TinyBridge/tinybridge.sock"), "default socket path suffix")
    }

    // MARK: - ResourceValidator
    do {
        print("\n=== ResourceValidator ===")
        let host = HostResources(physicalMemoryGB: 16, logicalCPUs: 8)
        let valid = ResourceConfiguration(cpuCount: 4, memoryGB: 8, diskGB: 50)
        let validIssues = ResourceValidator.validate(valid, host: host)
        checkTrue(ResourceValidator.isValid(validIssues), "valid config passes")

        let tooManyCpus = ResourceConfiguration(cpuCount: 100, memoryGB: 8, diskGB: 50)
        let cpuIssues = ResourceValidator.validate(tooManyCpus, host: host)
        checkFalse(ResourceValidator.isValid(cpuIssues), "too many cpus fails")
        checkTrue(cpuIssues.contains { $0.field == "cpu" }, "cpu field flagged")

        let tooMuchMem = ResourceConfiguration(cpuCount: 2, memoryGB: 200, diskGB: 50)
        let memIssues = ResourceValidator.validate(tooMuchMem, host: host)
        checkFalse(ResourceValidator.isValid(memIssues), "too much mem fails")
        checkTrue(memIssues.contains { $0.field == "memory" }, "memory field flagged")
    }

    // MARK: - PortValidator
    do {
        print("\n=== PortValidator ===")
        let good = PortMapping(hostAddress: "127.0.0.1", hostPort: 2222, guestAddress: "127.0.0.1", guestPort: 22, proto: .tcp)
        let goodIssues = PortValidator.validate(good)
        checkTrue(PortValidator.isValid(goodIssues), "good mapping valid")

        let badPort = PortMapping(hostAddress: "127.0.0.1", hostPort: 99999, guestAddress: "127.0.0.1", guestPort: 22)
        let badIssues = PortValidator.validate(badPort)
        checkFalse(PortValidator.isValid(badIssues), "bad port fails")
        checkTrue(badIssues.contains { $0.field == "hostPort" }, "hostPort flagged")

        let publicBind = PortMapping(hostAddress: "0.0.0.0", hostPort: 8080, guestAddress: "127.0.0.1", guestPort: 8080)
        let pubIssues = PortValidator.validate(publicBind)
        checkTrue(pubIssues.contains { $0.field == "hostAddress" && $0.severity == .warning }, "public bind warns")

        let mappings = [
            PortMapping(hostAddress: "127.0.0.1", hostPort: 8080, guestAddress: "127.0.0.1", guestPort: 80),
            PortMapping(hostAddress: "127.0.0.1", hostPort: 8080, guestAddress: "127.0.0.1", guestPort: 8080),
        ]
        let allIssues = PortValidator.validateAll(mappings)
        checkFalse(PortValidator.isValid(allIssues), "duplicate host port conflicts")
        checkTrue(allIssues.contains { $0.field == "hostPort" }, "conflict on hostPort")

        checkTrue(PortValidator.hasConflict(for: mappings[1], in: mappings), "has conflict")
        checkFalse(PortValidator.hasConflict(for: mappings[0], in: [mappings[0]]), "no conflict alone")
    }

    // MARK: - RingBuffer
    do {
        print("\n=== RingBuffer ===")
        var buf = RingBuffer<Int>(capacity: 3)
        buf.append(1); buf.append(2); buf.append(3)
        check(buf.elements, [1, 2, 3], "ring buffer elements order")
        check(buf.length, 3, "ring buffer length")
        check(buf.isFull, true, "ring buffer full")
        buf.append(4)
        check(buf.elements, [2, 3, 4], "ring buffer overwrites oldest")
        check(buf.length, 3, "ring buffer stays at capacity")
        check(buf.lastElement, 4, "ring buffer last element")
        buf.removeAll()
        checkTrue(buf.isEmpty, "ring buffer empty after clear")
    }

    // MARK: - MetricsHistory
    do {
        print("\n=== MetricsHistory ===")
        var history = MetricsHistory(capacity: 5)
        history.record(MetricSample(timestamp: Date(), value: 50.0, source: .hostObserved), for: .cpuUtilization)
        history.record(MetricSample(timestamp: Date(), value: nil, source: .hostObserved), for: .cpuUtilization)
        check(history.samples(for: .cpuUtilization).count, 2, "history records 2 samples")
        check(history.valuedSamples(for: .cpuUtilization).count, 1, "history 1 valued sample")
        checkTrue(history.valuedSamples(for: .cpuUtilization).first?.value == 50.0, "history valued sample is 50")
        checkTrue(history.latest(for: .cpuUtilization)?.value == nil, "history latest is the nil sample")
        checkFalse(history.hasData(for: .memoryUsed), "no data for unused metric")
    }

    // MARK: - Redactor
    do {
        print("\n=== Redactor ===")
        let redactor = Redactor()
        let withKey = "-----BEGIN PRIVATE KEY-----\nMIIEogIBAAKCAQEA...\n-----END PRIVATE KEY-----"
        let redactedKey = redactor.redact(withKey)
        checkTrue(redactedKey.contains("[REDACTED PRIVATE KEY]"), "redacts private key")
        checkFalse(redactedKey.contains("MIIEog"), "key body gone")

        let withToken = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let redactedToken = redactor.redact(withToken)
        checkTrue(redactedToken.contains("[REDACTED]"), "redacts bearer token")
        checkFalse(redactedToken.contains("eyJhbGci"), "token gone")

        let withIP = "Connected to 192.168.1.100:22"
        let redactedIP = redactor.redact(withIP)
        checkTrue(redactedIP.contains("[REDACTED_IP]"), "redacts IP")

        let withHome = "/Users/georgi/.config/file"
        let redactedHome = redactor.redact(withHome)
        checkTrue(redactedHome.contains("/Users/[USER]"), "redacts home path")
    }

    // MARK: - MockBackend lifecycle
    do {
        print("\n=== MockBackend ===")
        let backend = MockBackend(bootDuration: .milliseconds(50))
        let envs = try await backend.listEnvironments()
        check(envs.count, 2, "mock lists 2 envs")
        check(envs.first { $0.name == "ros-dev" }?.lifecycleState, .running, "ros-dev running")
        check(envs.first { $0.name == "build-box" }?.lifecycleState, .stopped, "build-box stopped")

        let started = try await backend.start(StartRequest(name: "new-vm"))
        check(started.name, "new-vm", "start returns name")
        check(started.status, "starting", "start returns starting status")

        try await Task.sleep(for: .milliseconds(200))
        let after = try await backend.status(name: "new-vm")
        checkTrue(after.first { $0.name == "new-vm" }?.lifecycleState.isRunning == true, "new-vm running after boot")

        let stopped = try await backend.stop(StopRequest(name: "new-vm"))
        check(stopped.status, "stopped", "stop returns stopped")

        // Duplicate start while running should fail (ros-dev already running).
        do {
            _ = try await backend.start(StartRequest(name: "ros-dev"))
            print("FAIL: duplicate start of running env should have thrown")
            failures += 1
        } catch let e as TinyBridgeClientError {
            if case .rpc(_, _, let kind) = e {
                check(kind, .alreadyRunning, "duplicate start is alreadyRunning")
            } else {
                print("FAIL: expected rpc error, got \(e)")
                failures += 1
            }
        }

        let again = try await backend.listEnvironments()
        check(again.count, 3, "still 3 envs after failed duplicate start")

        // Stop non-running without force fails.
        do {
            _ = try await backend.stop(StopRequest(name: "build-box"))
            print("FAIL: stopping non-running without force should have thrown")
            failures += 1
        } catch let e as TinyBridgeClientError {
            checkTrue(e.isRetryable == false, "non-retryable not-running error")
            if case .rpc(_, _, let kind) = e {
                check(kind, .notRunning, "not-running code")
            } else {
                print("FAIL: expected rpc error, got \(e)")
                failures += 1
            }
        }

        // Doctor works.
        let doc = try await backend.runDoctor(name: nil)
        checkTrue(!doc.raw.isEmpty, "doctor returns output")
    }

    // MARK: - DiagnosticReport (client)
    do {
        print("\n=== DiagnosticReport ===")
        let report = DiagnosticReport(raw: "✓ check one\n✗ check two\n✓ check three")
        check(report.lines.count, 3, "diagnostic lines count")
        check(report.raw.contains("✓"), true, "has pass marks")
    }
}

// MARK: - Entry

Task {
    try? await runAllTests()
    print("\n============================")
    if failures == 0 {
        print("ALL TESTS PASSED")
    } else {
        print("\(failures) TEST(S) FAILED")
    }
    print("============================")
    exit(failures == 0 ? 0 : 1)
}

RunLoop.current.run()

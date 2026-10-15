import XCTest
@testable import TinyBridgeClient

final class VMStateTests: XCTestCase {

    func testPlainStates() {
        XCTAssertEqual(VMLifecycleState.parse("stopped"), .stopped)
        XCTAssertEqual(VMLifecycleState.parse("running"), .running)
        XCTAssertEqual(VMLifecycleState.parse("stopping"), .stopping)
        XCTAssertEqual(VMLifecycleState.parse("starting"), .starting(progressPercent: nil))
        XCTAssertEqual(VMLifecycleState.parse("error"), .failed(message: nil))
    }

    func testDebugTaggedRunningForm() {
        // The exact shape manager.rs's to_summary produces.
        XCTAssertEqual(VMLifecycleState.parse("running { uptime_secs: 4210 }"), .running)
    }

    func testDebugTaggedStartingFormParsesProgress() {
        XCTAssertEqual(
            VMLifecycleState.parse("starting { progress_pct: 42 }"),
            .starting(progressPercent: 42)
        )
    }

    func testDebugTaggedErrorFormParsesMessage() {
        let state = VMLifecycleState.parse("error { message: \"disk image missing\" }")
        XCTAssertEqual(state, .failed(message: "disk image missing"))
    }

    func testUnknownFormIsNotSilentlyCoerced() {
        let state = VMLifecycleState.parse("quiescing")
        XCTAssertEqual(state, .unknown(raw: "quiescing"))
        XCTAssertFalse(state.isRunning)
    }

    func testOnlyRunningIsRunning() {
        XCTAssertTrue(VMLifecycleState.parse("running").isRunning)
        XCTAssertTrue(VMLifecycleState.parse("running { uptime_secs: 1 }").isRunning)
        XCTAssertFalse(VMLifecycleState.parse("starting { progress_pct: 99 }").isRunning)
        XCTAssertFalse(VMLifecycleState.parse("stopping").isRunning)
    }

    func testTransitionalStates() {
        XCTAssertTrue(VMLifecycleState.parse("starting").isTransitional)
        XCTAssertTrue(VMLifecycleState.parse("stopping").isTransitional)
        XCTAssertFalse(VMLifecycleState.parse("running").isTransitional)
    }
}

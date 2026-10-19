import Foundation

/// Explicit lifecycle state for a managed VM.
///
/// Modelled separately from any raw backend string so the UI never has to
/// interpret ad-hoc text at the view layer. TinyBridge's daemon currently
/// emits `status` as `format!("{:?}", status).to_lowercase()`
/// (see `crates/tinybridge-daemon/src/manager.rs::to_summary`), which yields
/// strings like `"running { uptime_secs: 100 }"`. `parse(_:)` accepts that
/// real shape as well as the already-plain forms used by `up`/`down`
/// responses (`"running"`, `"stopped"`).
public enum VMLifecycleState: Sendable, Equatable {
    /// The backend did not report a state we recognise.
    case unknown(raw: String)
    case stopped
    case starting(progressPercent: Int?)
    case running
    case stopping
    case failed(message: String?)

    /// True only for the state the backend actually reports as running.
    /// A `start` command returning success is **not** treated as proof of
    /// running anywhere in this app; only this state is.
    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isStopped: Bool {
        if case .stopped = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    public var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    public var isTransitional: Bool {
        switch self {
        case .starting, .stopping: return true
        default: return false
        }
    }

    /// Short human label for badges and tables.
    public var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .stopped: return "Stopped"
        case .starting: return "Starting"
        case .running: return "Running"
        case .stopping: return "Stopping"
        case .failed: return "Failed"
        }
    }

    public static func == (lhs: VMLifecycleState, rhs: VMLifecycleState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown(let a), .unknown(let b)): return a == b
        case (.stopped, .stopped): return true
        case (.starting(let a), .starting(let b)): return a == b
        case (.running, .running): return true
        case (.stopping, .stopping): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    /// Parse the backend's real `status` string.
    ///
    /// Handles both the plain forms (`"running"`, `"stopped"`, `"stopping"`)
    /// and the Rust `Debug`-derived tagged forms the daemon summary emits.
    public static func parse(_ raw: String) -> VMLifecycleState {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // Fast path: plain keyword.
        switch lower {
        case "stopped": return .stopped
        case "starting": return .starting(progressPercent: nil)
        case "running": return .running
        case "stopping": return .stopping
        case "error", "failed": return .failed(message: nil)
        default: break
        }

        // Tagged Debug form. Identify by leading keyword.
        if lower.hasPrefix("running") { return .running }
        if lower.hasPrefix("stopping") { return .stopping }
        if lower.hasPrefix("stopped") { return .stopped }

        if lower.hasPrefix("starting") {
            let pct = firstInt(after: "progress_pct", in: trimmed)
            return .starting(progressPercent: pct)
        }

        if lower.hasPrefix("error") || lower.hasPrefix("failed") {
            let msg = quotedString(after: "message", in: trimmed)
            return .failed(message: msg)
        }

        return .unknown(raw: trimmed)
    }

    private static func firstInt(after key: String, in text: String) -> Int? {
        guard let keyRange = text.range(of: key) else { return nil }
        let tail = text[keyRange.upperBound...]
        var digits = ""
        for ch in tail {
            if ch.isNumber {
                digits.append(ch)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits)
    }

    private static func quotedString(after key: String, in text: String) -> String? {
        guard let keyRange = text.range(of: key) else { return nil }
        let tail = text[keyRange.upperBound...]
        guard let open = tail.firstIndex(of: "\"") else { return nil }
        let afterOpen = tail.index(after: open)
        guard let close = tail[afterOpen...].firstIndex(of: "\"") else { return nil }
        return String(tail[afterOpen..<close])
    }
}

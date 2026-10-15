import Foundation

/// Where a metric came from. The UI must say which, because guest-reported and
/// host-observed values are not interchangeable.
public enum MetricSource: String, Sendable, Codable, Equatable {
    /// Measured on the macOS host (e.g. process CPU time of the VM host process,
    /// disk image size on the host filesystem).
    case hostObserved
    /// Reported by an agent inside the guest. Requires an in-guest agent that
    /// TinyBridge does not currently ship, so this is usually unavailable.
    case guestReported

    public var label: String {
        switch self {
        case .hostObserved: return "Host-observed"
        case .guestReported: return "Guest-reported"
        }
    }
}

/// A single time-stamped metric value. `value == nil` means "not available",
/// which is deliberately distinct from 0 — the UI renders it as "—".
public struct MetricSample: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var timestamp: Date
    public var value: Double?
    public var source: MetricSource

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        value: Double?,
        source: MetricSource
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.source = source
    }
}

/// The kinds of metric the app can chart. Each is explicitly host-observed or
/// guest-reported.
public enum MetricKind: String, Sendable, CaseIterable, Equatable {
    case cpuUtilization
    case memoryUsed
    case diskUsed
    case networkThroughput

    public var title: String {
        switch self {
        case .cpuUtilization: return "CPU"
        case .memoryUsed: return "Memory"
        case .diskUsed: return "Disk"
        case .networkThroughput: return "Network"
        }
    }

    public var unit: String {
        switch self {
        case .cpuUtilization: return "%"
        case .memoryUsed, .diskUsed: return "GB"
        case .networkThroughput: return "MB/s"
        }
    }

    /// These are the sources the current backend can actually provide. Anything
    /// not backed by real data is shown as unavailable, never charted from
    /// fabricated numbers.
    public var availableSource: MetricSource? {
        // The TinyBridge daemon exposes no usage metrics over RPC at all, so
        // nothing here is currently backed by live backend data. Host-observed
        // values could be gathered by the UI process about the vmhost child
        // process later; until then, all return nil and the UI shows them as
        // unavailable rather than inventing values.
        nil
    }
}

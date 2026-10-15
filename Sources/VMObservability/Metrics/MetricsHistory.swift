import Foundation

/// Bounded, per-metric history. Never grows past `capacity` samples per metric,
/// so a long-lived app has a hard memory ceiling for telemetry.
public struct MetricsHistory: Sendable {
    public let capacity: Int
    private var series: [MetricKind: RingBuffer<MetricSample>] = [:]

    public init(capacity: Int = 120) {
        self.capacity = capacity
        for kind in MetricKind.allCases {
            series[kind] = RingBuffer(capacity: capacity)
        }
    }

    public mutating func record(_ sample: MetricSample, for kind: MetricKind) {
        var buffer = series[kind] ?? RingBuffer(capacity: capacity)
        buffer.append(sample)
        series[kind] = buffer
    }

    public func samples(for kind: MetricKind) -> [MetricSample] {
        series[kind]?.elements ?? []
    }

    /// Only the samples that actually carry a value, for charting.
    public func valuedSamples(for kind: MetricKind) -> [MetricSample] {
        samples(for: kind).filter { $0.value != nil }
    }

    public func latest(for kind: MetricKind) -> MetricSample? {
        series[kind]?.lastElement
    }

    public func hasData(for kind: MetricKind) -> Bool {
        !(series[kind]?.isEmpty ?? true)
    }

    public mutating func clear() {
        for kind in MetricKind.allCases {
            series[kind]?.removeAll()
        }
    }
}

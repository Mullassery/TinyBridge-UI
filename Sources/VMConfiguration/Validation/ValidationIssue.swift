import Foundation
import Darwin

/// A single validation finding. `field` identifies the control the UI should
/// highlight.
public struct ValidationIssue: Identifiable, Sendable, Equatable {
    public enum Severity: Sendable, Equatable {
        case error
        case warning
    }

    public let id = UUID()
    public var field: String
    public var message: String
    public var severity: Severity

    public init(field: String, message: String, severity: Severity) {
        self.field = field
        self.message = message
        self.severity = severity
    }

    public static func error(_ field: String, _ message: String) -> ValidationIssue {
        ValidationIssue(field: field, message: message, severity: .error)
    }

    public static func warning(_ field: String, _ message: String) -> ValidationIssue {
        ValidationIssue(field: field, message: message, severity: .warning)
    }
}

/// Host facts used to sanity-check resource requests. Injected so tests are
/// deterministic and no view reads hardware directly.
public struct HostResources: Sendable, Equatable {
    public var physicalMemoryGB: Int
    public var logicalCPUs: Int

    public init(physicalMemoryGB: Int, logicalCPUs: Int) {
        self.physicalMemoryGB = physicalMemoryGB
        self.logicalCPUs = logicalCPUs
    }

    /// Read the real host values via `sysctl`/`ProcessInfo`.
    public static func current() -> HostResources {
        HostResources(
            physicalMemoryGB: Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)),
            logicalCPUs: ProcessInfo.processInfo.processorCount
        )
    }
}

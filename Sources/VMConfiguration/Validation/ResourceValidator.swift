import Foundation

/// Validation for resource allocation. Pure functions, so the same rules drive
/// both the form UI and the tests.
public enum ResourceValidator {
    public static let cpuRange = 1...64
    public static let memoryRangeGB = 1...256
    public static let diskRangeGB = 1...4096

    public static func validate(
        _ config: ResourceConfiguration,
        host: HostResources
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if !cpuRange.contains(config.cpuCount) {
            issues.append(.error(
                "cpu",
                "vCPU count must be between \(cpuRange.lowerBound) and \(cpuRange.upperBound)."
            ))
        } else if config.cpuCount > host.logicalCPUs {
            issues.append(.warning(
                "cpu",
                "\(config.cpuCount) vCPUs exceed the host's \(host.logicalCPUs) logical CPUs; the VM will be oversubscribed."
            ))
        }

        if !memoryRangeGB.contains(config.memoryGB) {
            issues.append(.error(
                "memory",
                "Memory must be between \(memoryRangeGB.lowerBound) and \(memoryRangeGB.upperBound) GB."
            ))
        } else if config.memoryGB > host.physicalMemoryGB {
            issues.append(.error(
                "memory",
                "\(config.memoryGB) GB exceeds the host's \(host.physicalMemoryGB) GB of physical memory."
            ))
        } else if config.memoryGB > max(1, host.physicalMemoryGB - 2) {
            issues.append(.warning(
                "memory",
                "Allocating \(config.memoryGB) GB leaves little headroom on a \(host.physicalMemoryGB) GB Mac."
            ))
        }

        if !diskRangeGB.contains(config.diskGB) {
            issues.append(.error(
                "disk",
                "Disk must be between \(diskRangeGB.lowerBound) and \(diskRangeGB.upperBound) GB."
            ))
        }

        return issues
    }

    public static func isValid(_ issues: [ValidationIssue]) -> Bool {
        !issues.contains { $0.severity == .error }
    }
}

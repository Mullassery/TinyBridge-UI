import Foundation

/// Validation for port-forwarding rules, including duplicate-binding detection.
///
/// The app binds to loopback by default; the validator flags any rule that
/// would expose a service beyond the local Mac so the user makes that choice
/// knowingly.
public enum PortValidator {
    public static let portRange = 1...65535

    public static func validatePort(_ port: Int, field: String) -> [ValidationIssue] {
        guard portRange.contains(port) else {
            return [.error(field, "Port must be between \(portRange.lowerBound) and \(portRange.upperBound).")]
        }
        if port < 1024 {
            return [.warning(
                field,
                "Ports below 1024 are privileged; forwarding them may require elevated permissions."
            )]
        }
        return []
    }

    public static func validate(_ mapping: PortMapping) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        issues.append(contentsOf: validatePort(mapping.hostPort, field: "hostPort"))
        issues.append(contentsOf: validatePort(mapping.guestPort, field: "guestPort"))

        let hostAddress = mapping.hostAddress.trimmingCharacters(in: .whitespaces)
        if hostAddress.isEmpty {
            issues.append(.error("hostAddress", "Host address is required. Use 127.0.0.1 for local-only access."))
        } else if mapping.bindsBeyondLoopback {
            issues.append(.warning(
                "hostAddress",
                "Binding \(hostAddress.isEmpty ? "(all interfaces)" : hostAddress) exposes this service to your entire network, not just this Mac."
            ))
        }

        let guestAddress = mapping.guestAddress.trimmingCharacters(in: .whitespaces)
        if guestAddress.isEmpty {
            issues.append(.error("guestAddress", "Guest address is required. Use 127.0.0.1 unless the guest service binds elsewhere."))
        }

        return issues
    }

    /// Validate a full set, including cross-rule conflicts.
    public static func validateAll(_ mappings: [PortMapping]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for mapping in mappings {
            issues.append(contentsOf: validate(mapping))
        }

        // Duplicate host bindings: same enabled host address + port + protocol.
        var seen: [String: UUID] = [:]
        for mapping in mappings where mapping.isEnabled {
            let key = "\(mapping.hostAddress):\(mapping.hostPort)/\(mapping.proto.rawValue)"
            if seen[key] != nil {
                issues.append(.error(
                    "hostPort",
                    "Host port \(mapping.hostPort)/\(mapping.proto.label) is already forwarded by another rule."
                ))
            } else {
                seen[key] = mapping.id
            }
        }
        return issues
    }

    public static func isValid(_ issues: [ValidationIssue]) -> Bool {
        !issues.contains { $0.severity == .error }
    }

    public static func hasConflict(for mapping: PortMapping, in mappings: [PortMapping]) -> Bool {
        mappings.contains { other in
            other.id != mapping.id
                && other.isEnabled
                && other.hostAddress == mapping.hostAddress
                && other.hostPort == mapping.hostPort
                && other.proto == mapping.proto
        }
    }
}

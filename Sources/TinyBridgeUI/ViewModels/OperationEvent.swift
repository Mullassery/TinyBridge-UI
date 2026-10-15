import Foundation

/// A single entry in the in-memory lifecycle/operation log shown in
/// Diagnostics and the main window's activity list.
struct OperationEvent: Identifiable, Equatable {
    enum Kind: Equatable {
        case info
        case success
        case warning
        case failure

        var symbolName: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .failure: return "xmark.octagon"
            }
        }
    }

    let id = UUID()
    let timestamp: Date
    var kind: Kind
    var subject: String
    var message: String

    init(timestamp: Date = Date(), kind: Kind, subject: String, message: String) {
        self.timestamp = timestamp
        self.kind = kind
        self.subject = subject
        self.message = message
    }
}

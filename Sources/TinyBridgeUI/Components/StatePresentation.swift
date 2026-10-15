import SwiftUI
import TinyBridgeClient

/// Maps a lifecycle state to a symbol, a semantic color, and a text label.
///
/// State is **always** conveyed by symbol + text, with color as a secondary
/// cue, so the UI remains usable without color perception (HIG accessibility).
struct StatePresentation {
    let symbolName: String
    let tint: Color
    let label: String

    static func of(_ state: VMLifecycleState) -> StatePresentation {
        switch state {
        case .running:
            return .init(symbolName: "circle.fill", tint: .green, label: "Running")
        case .starting(let progress):
            let suffix = progress.map { " \($0)%" } ?? ""
            return .init(symbolName: "arrow.triangle.2.circlepath", tint: .orange, label: "Starting\(suffix)")
        case .stopping:
            return .init(symbolName: "arrow.down.circle", tint: .orange, label: "Stopping")
        case .stopped:
            return .init(symbolName: "stop.circle", tint: .secondary, label: "Stopped")
        case .failed:
            return .init(symbolName: "exclamationmark.triangle.fill", tint: .red, label: "Failed")
        case .unknown:
            return .init(symbolName: "questionmark.circle", tint: .secondary, label: "Unknown")
        }
    }

    /// Accessible description combining symbol meaning and label.
    static func accessibilityDescription(for state: VMLifecycleState) -> String {
        switch state {
        case .failed(let message):
            return message.map { "Failed: \($0)" } ?? "Failed"
        case .starting(let progress):
            return progress.map { "Starting, \($0) percent" } ?? "Starting"
        default:
            return of(state).label
        }
    }
}

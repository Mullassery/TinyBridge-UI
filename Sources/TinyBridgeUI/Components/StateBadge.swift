import SwiftUI
import TinyBridgeClient

/// A compact state badge: symbol + text, with color as a secondary cue.
struct StateBadge: View {
    let state: VMLifecycleState
    var compact: Bool = false

    var body: some View {
        let presentation = StatePresentation.of(state)
        HStack(spacing: 5) {
            Image(systemName: presentation.symbolName)
                .foregroundStyle(presentation.tint)
                .font(.caption)
            Text(presentation.label)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(StatePresentation.accessibilityDescription(for: state)))
    }
}

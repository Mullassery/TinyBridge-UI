import SwiftUI
import TinyBridgeClient

struct MenuBarView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Connection strip.
            HStack(spacing: 8) {
                Image(systemName: viewModel.connectionState.symbolName)
                    .foregroundStyle(
                        viewModel.connectionState.isConnected ? .green : .secondary
                    )
                    .font(.caption)
                Text(viewModel.connectionState.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            .padding(.leading, 2)

            Divider()

            // VM inventory in the popover.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.environments) { env in
                        VMRowCompact(environment: env)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if viewModel.environments.count > 1 {
                                    openMain()
                                } else {
                                    // Single VM: toggle directly from popover.
                                    toggleSingleVM(env)
                                }
                            }
                    }
                    if viewModel.environments.isEmpty {
                        Text("No VMs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxWidth: 260)

            Divider()

            Button("Open TinyBridge") { openMain() }
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Button("Preferences…") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.plain)
                .font(.callout)

                Button("Quit TinyBridge") { quit() }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            .padding(.top, 4)
            .padding(.bottom, 8)

            if let error = viewModel.lastError, !error.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Dismiss") { viewModel.dismissError() }
                        .buttonStyle(.plain)
                        .font(.caption2)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(8)
        .frame(maxWidth: 270)
    }

    private func openMain() {
        openWindow(id: WindowID.main)
    }

    private func toggleSingleVM(_ env: EnvironmentSummary) {
        let state = env.lifecycleState
        Task {
            switch state {
            case .running:
                await viewModel.stop(name: env.name, force: false)
            case .stopped:
                await viewModel.start(name: env.name)
            case .starting, .stopping:
                break // ignore taps mid-transition
            case .failed:
                await viewModel.start(name: env.name)
            case .unknown:
                await viewModel.start(name: env.name)
            }
        }
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

struct VMRowCompact: View {
    let environment: EnvironmentSummary

    var body: some View {
        HStack(spacing: 8) {
            StateBadge(state: environment.lifecycleState, compact: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(environment.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let ip = environment.ipAddress {
                    Text(ip)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

import SwiftUI
import TinyBridgeClient

struct VirtualMachinesView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Virtual Machines")
                        .font(.title2).bold()
                    Spacer()
                    Button("Refresh") { Task { await viewModel.refresh() } }
                        .keyboardShortcut("r", modifiers: .command)
                }

                if viewModel.environments.isEmpty {
                    EmptyStateView(
                        symbol: "desktopcomputer",
                        title: "No virtual machines",
                        message: "Use `tinybridge up` on the CLI, or create one via the daemon, then refresh here."
                    )
                } else {
                Table(viewModel.environments) {
                    TableColumn("Name") { (env: EnvironmentSummary) in
                        Text(env.name).font(.subheadline).bold()
                    }
                    TableColumn("State") { (env: EnvironmentSummary) in
                        HStack(spacing: 6) {
                            StateBadge(state: env.lifecycleState)
                            if env.lifecycleState.isTransitional || viewModel.isPending(env.name) {
                                ProgressView().controlSize(.small).scaleEffect(0.8)
                            }
                        }
                    }
                    TableColumn("Address") { (env: EnvironmentSummary) in
                        Text(env.ipAddress ?? "—")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TableColumn("Uptime") { (env: EnvironmentSummary) in
                        Text(env.uptimeSeconds.map { "\($0)s" } ?? "—")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TableColumn("Actions") { (env: EnvironmentSummary) in
                        VMActionButtons(environment: env)
                    }
                }
                }
            }
            .padding()
        }
    }
}

struct VMActionButtons: View {
    let environment: EnvironmentSummary
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 4) {
            actionButton(for: environment)
            if environment.lifecycleState.isRunning {
                forceStopButton(for: environment)
            }
            doctorButton(for: environment)
        }
    }

    @ViewBuilder
    private func actionButton(for env: EnvironmentSummary) -> some View {
        let state = env.lifecycleState
        let pending = viewModel.isPending(env.name)
        let canStart = state.isStopped || state.isFailed || state.isUnknown

        Button {
            if pending { return }
            Task {
                switch state {
                case .running: await viewModel.stop(name: env.name, force: false)
                case .stopped, .failed, .unknown: await viewModel.start(name: env.name)
                case .starting, .stopping: break
                }
            }
        } label: {
            Image(systemName: canStart ? "play.fill" : "stop.fill")
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(pending ? Color.secondary : (canStart ? Color.green : Color.red))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(pending || state.isTransitional)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func forceStopButton(for env: EnvironmentSummary) -> some View {
        let pending = viewModel.isPending(env.name)

        Button {
            if pending { return }
            Task { await viewModel.stop(name: env.name, force: true) }
        } label: {
            Image(systemName: "power")
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(pending ? Color.secondary : Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(pending)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func doctorButton(for env: EnvironmentSummary) -> some View {
        let pending = viewModel.isPending(env.name)

        Button {
            if pending { return }
            Task { _ = await viewModel.doctor(name: env.name) }
        } label: {
            Image(systemName: "stethoscope")
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(pending)
        .buttonStyle(.plain)
        .help("Run diagnostics")
    }
}

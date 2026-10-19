import SwiftUI
import TinyBridgeClient

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection summary band.
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: viewModel.connectionState.symbolName)
                            .foregroundStyle(viewModel.connectionState.isConnected ? .green : .secondary)
                        Text("Backend: \(viewModel.connectionState.label)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    Text(viewModel.backendSocketPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))

                // Count cards.
                HStack(spacing: 12) {
                    CountCard(title: "VMs", value: "\(viewModel.totalCount)", symbol: "desktopcomputer")
                    CountCard(title: "Running", value: "\(viewModel.runningCount)", symbol: "circle.fill", tint: .green)
                    CountCard(title: "Stopped", value: "\(viewModel.totalCount - viewModel.runningCount)", symbol: "stop.circle", tint: .secondary)
                }

                // VM list summary.
                Text("Virtual Machines")
                    .font(.headline)
                    .padding(.top, 4)
                VMListSummary(environments: viewModel.environments)

                Button("Refresh") { Task { await viewModel.refresh() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("r", modifiers: .command)

                if let error = viewModel.lastError, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                    Button("Dismiss") { viewModel.dismissError() }
                        .font(.caption2)
                }
            }
            .padding()
        }
    }
}

struct CountCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value).font(.title).bold().foregroundStyle(.primary)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
    }
}

struct VMListSummary: View {
    let environments: [EnvironmentSummary]

    var body: some View {
        if environments.isEmpty {
            Text("No environments registered with the daemon.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            Table(environments) {
                TableColumn("Name") { env in
                    Text(env.name).font(.subheadline)
                }
                TableColumn("State") { env in
                    StateBadge(state: env.lifecycleState)
                }
                TableColumn("Address") { env in
                    Text(env.ipAddress ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TableColumn("Uptime") { env in
                    Text(env.uptimeSeconds.map { "\($0)s" } ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

import SwiftUI
import VMConfiguration

struct PortForwardingView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var mappings: [PortMapping] = [
        PortMapping(hostAddress: "127.0.0.1", hostPort: 2222, guestAddress: "127.0.0.1", guestPort: 22, proto: .tcp),
        PortMapping(hostAddress: "127.0.0.1", hostPort: 8080, guestAddress: "127.0.0.1", guestPort: 8080, proto: .tcp),
    ]
    @State private var issues: [ValidationIssue] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Port Forwarding")
                    .font(.title2).bold()
                Text("Port forwarding is not yet exposed by TinyBridge's control plane. The table below shows how validation will behave once the RPC surface supports it; rules shown are placeholders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Host-binding warning").font(.headline).padding(.top, 4)

                Table(mappings) {
                    TableColumn("Host") { (mapping: PortMapping) in
                        Text(mapping.hostAddress).font(.caption).monospaced()
                    }
                    TableColumn("Host Port") { (mapping: PortMapping) in
                        Text("\(mapping.hostPort)").font(.caption).monospaced()
                    }
                    TableColumn("Guest") { (mapping: PortMapping) in
                        Text("\(mapping.guestAddress):\(mapping.guestPort)").font(.caption).monospaced()
                    }
                    TableColumn("Proto") { (mapping: PortMapping) in
                        Text(mapping.proto.label).font(.caption)
                    }
                    TableColumn("Enabled") { (mapping: PortMapping) in
                        Image(systemName: mapping.isEnabled ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(mapping.isEnabled ? .green : .secondary)
                            .font(.caption)
                    }
                }
                .overlay(Group {
                    if mappings.isEmpty { Text("No port mappings.").font(.caption).foregroundStyle(.secondary) }
                })

                VStack(alignment: .leading, spacing: 6) {
                    if issues.contains(where: { $0.severity == .error }) {
                        Text("Invalid port configuration — fix before applying.")
                            .font(.caption).foregroundStyle(.red)
                    } else if !issues.isEmpty {
                        Text("Warnings: \(issues.count)")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                UnsupportedNotice(feature: "Port forwarding CRUD") {
                    Text("TinyBridge's daemon currently exposes environment lifecycle, status, and diagnostics over its socket, but not port-mapping CRUD. This view is ready to wire up once the backend adds the RPC.")
                }
            }
            .padding()
        }
    }
}

struct UnsupportedNotice<Content: View>: View {
    let feature: String
    @ViewBuilder let detail: Content

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(feature) is unsupported")
                    .font(.subheadline).bold()
                detail
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }
}

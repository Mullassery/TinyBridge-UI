import SwiftUI
import VMConfiguration

struct ConfigurationView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var resources = ResourceConfiguration.tinyBridgeDefault
    @State private var issues: [ValidationIssue] = []
    @State private var hostResources = HostResources.current()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("VM Configuration")
                    .font(.title2).bold()

                UnsupportedNotice(feature: "Configuration editing") {
                    Text("TinyBridge's daemon does not yet expose configuration-read/write RPC, so edits are validated locally and shown as 'would apply if supported'. Resource overrides are accepted on `environment.up` by the CLI but ignored by the current daemon.")
                }

                Form {
                    Section("Resources") {
                        LabeledContent("vCPUs") {
                            TextField("vCPUs", value: $resources.cpuCount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                        LabeledContent("Memory (GB)") {
                            TextField("GB", value: $resources.memoryGB, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                        LabeledContent("Disk (GB)") {
                            TextField("GB", value: $resources.diskGB, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }

                        if !issues.isEmpty {
                            ForEach(issues) { issue in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: issue.severity == .error ? "exclamationmark.circle.fill" : "exclamationmark.triangle")
                                        .foregroundStyle(issue.severity == .error ? .red : .orange)
                                        .font(.caption)
                                    Text(issue.message)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }

                        Text("Host: \(hostResources.logicalCPUs) logical CPUs, \(hostResources.physicalMemoryGB) GB memory")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 520)

                Button("Validate") {
                    issues = ResourceValidator.validate(resources, host: hostResources)
                }
                .buttonStyle(.bordered)
                .disabled(ResourceValidator.isValid(issues) && resources == ResourceConfiguration.tinyBridgeDefault)

                UnsupportedNotice(feature: "Apply configuration") {
                    Text("TinyBridge does not expose configuration update RPC, so no settings can be written to the backend yet.")
                }
            }
            .padding()
        }
    }
}

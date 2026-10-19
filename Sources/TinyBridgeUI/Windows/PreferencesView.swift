import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.title2).bold()

            Form {
                Section("Backend") {
                    LabeledContent("Socket path") {
                        Text(viewModel.backendSocketPath)
                            .font(.caption)
                            .monospaced()
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Picker("Backend", selection: $viewModel.backendKind) {
                        Text("Live daemon").tag(BackendKind.live)
                        Text("Demo (in-process)").tag(BackendKind.demo)
                    }
                    .onChange(of: viewModel.backendKind) { _, newValue in
                        Task {
                            switch newValue {
                            case .live: await viewModel.useLiveBackend()
                            case .demo: await viewModel.useDemoBackend()
                            }
                        }
                    }
                }

                Section("Behavior") {
                    Toggle("Refresh VM list automatically", isOn: $viewModel.autoRefresh)
                }

                Section("About") {
                    HStack {
                        Text("TinyBridge-UI")
                        Spacer()
                        Text("v0.1.0").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Native macOS menu-bar manager for TinyBridge micro-VMs. Built on SwiftUI and Virtualization.framework via the TinyBridge control socket.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 520)
        }
        .padding()
    }
}

enum BackendKind: String, CaseIterable {
    case live, demo
}

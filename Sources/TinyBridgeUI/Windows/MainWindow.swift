import SwiftUI
import TinyBridgeClient

struct MainWindow: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedSection) {
                Section("Overview") {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                        .tag(AppSection.dashboard)
                    Label("Virtual Machines", systemImage: "desktopcomputer")
                        .tag(AppSection.virtualMachines)
                }
                Section("Networking") {
                    Label("Port Forwarding", systemImage: "network")
                        .tag(AppSection.portForwarding)
                    Label("Configuration", systemImage: "slider.horizontal.3")
                        .tag(AppSection.configuration)
                }
                Section("Support") {
                    Label("Diagnostics", systemImage: "stethoscope")
                        .tag(AppSection.diagnostics)
                    Label("Preferences", systemImage: "gear")
                        .tag(AppSection.preferences)
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TinyBridge-UI")
                        .font(.title2).bold()
                    Text(viewModel.connectionState.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial)
            }
        } detail: {
            switch viewModel.selectedSection {
            case .dashboard: DashboardView().environmentObject(viewModel)
            case .virtualMachines: VirtualMachinesView().environmentObject(viewModel)
            case .portForwarding: PortForwardingView().environmentObject(viewModel)
            case .configuration: ConfigurationView().environmentObject(viewModel)
            case .diagnostics: DiagnosticsView().environmentObject(viewModel)
            case .preferences: PreferencesView().environmentObject(viewModel)
            }
        }
    }
}

enum AppSection: Int, Hashable, Identifiable {
    case dashboard, virtualMachines, portForwarding, configuration, diagnostics, preferences
    var id: Int { rawValue }
}

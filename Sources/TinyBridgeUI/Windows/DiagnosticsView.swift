import SwiftUI
import TinyBridgeClient
import VMConfiguration

struct DiagnosticsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var report = DiagnosticReport.unavailable
    @State private var isRunningDoctor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Diagnostics")
                    .font(.title2).bold()

                Text("Run `environment.doctor` against the backend and view structured results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        Task { await runDoctor() }
                    } label: {
                        if isRunningDoctor {
                            ProgressView()
                        } else {
                            Label("Run Diagnostics", systemImage: "stethoscope")
                        }
                    }
                    .disabled(isRunningDoctor)
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Text("Socket: \(viewModel.backendSocketPath)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.subheadline).bold()
                    ScrollView {
                        Text(report.raw.isEmpty ? "No diagnostics run yet." : report.raw)
                            .font(.caption)
                            .monospaced()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(minHeight: 180)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.06)))
                }

                // Parsed lines list.
                if !report.lines.isEmpty {
                    Text("Parsed checks")
                        .font(.subheadline).bold()
                        .padding(.top, 4)
                    ForEach(report.lines, id: \.self) { line in
                        HStack(spacing: 8) {
                            Image(systemName: line.contains("✗") ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(line.contains("✗") ? .red : .green)
                                .font(.caption)
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }

                UnsupportedNotice(feature: "Diagnostic export") {
                    Text("Diagnostics contain no credentials, tokens, or keys by design; the Redactor would strip any before export.")
                }
            }
            .padding()
        }
    }

    private func runDoctor() async {
        isRunningDoctor = true
        defer { isRunningDoctor = false }
        report = await viewModel.doctor(name: nil)
    }
}

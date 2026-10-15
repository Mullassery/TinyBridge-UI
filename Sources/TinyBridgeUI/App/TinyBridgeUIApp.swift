import SwiftUI
import AppKit

/// Ensures the process behaves as a normal (windowed, menu-bearing) app even
/// when launched as a bare SwiftPM executable rather than a bundled `.app`.
/// When packaged with an `Info.plist`, the default policy already applies and
/// this is a no-op.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }
}

@main
struct TinyBridgeUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        // Menu-bar control center. A window style gives a rich popover so the
        // user can see inventory and act without opening the main window.
        MenuBarExtra("TinyBridge", systemImage: "shippingbox.fill") {
            MenuBarView()
                .environmentObject(viewModel)
        }
        .menuBarExtraStyle(.window)

        // Main management window.
        Window("TinyBridge", id: WindowID.main) {
            MainWindow()
                .environmentObject(viewModel)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("TinyBridge") {
                Button("Refresh") {
                    Task { await viewModel.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        // Standard Preferences window (⌘,).
        Settings {
            PreferencesView()
                .environmentObject(viewModel)
                .frame(width: 460)
        }
    }
}

enum WindowID {
    static let main = "tinybridge.main"
}

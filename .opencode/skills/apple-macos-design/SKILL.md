---
name: apple-macos-design
description: Use when building or reviewing native macOS/SwiftUI interfaces for a TinyBridge-UI-style app — menu-bar extras, windows, Tables, Forms, Settings, Swift Charts, SF Symbols, dark/light mode, and accessibility. Encodes Apple HIG-derived conventions so the app feels native, not web-in-a-window. Trigger on MenuBarExtra, SwiftUI layout, macOS window/menu design, SF Symbols, or accessibility work.
---

# Apple macOS design conventions (TinyBridge-UI)

Derived from Apple's first-party Human Interface Guidelines and SwiftUI
documentation. Apply these whenever building or reviewing UI in this project.

## Non-negotiables

1. **Native, not web.** Use system materials, semantic colors, native Forms,
   Toolbars, Menus, Popovers, Tables, and standard window behavior. No Electron,
   no embedded browser, no CSS-like custom chrome.
2. **System typography only.** Semantic text styles (`.largeTitle`, `.title`,
   `.headline`, `.body`, `.caption`, `.monospaced`). Never hardcoded point sizes.
3. **SF Symbols for icons.** `Image(systemName:)` / `Label(_, systemImage:)`.
   Never emoji as an app or toolbar icon. Choose the symbol that matches Apple's
   own semantic (e.g. `cpu`, `memorychip`, `internaldrive`, `network`,
   `stethoscope` for diagnostics, `gearshape` for settings).
4. **Semantic color only.** `.primary`, `.secondary`, `.accentColor`, and
   standard role colors (`.red`, `.green`, `.orange`, `.blue`) so light and dark
   mode work automatically. No raw hex that breaks in dark mode.
5. **Every interactive control has an accessibility label.** Icon-only controls
   must carry a text alternative (`.accessibilityLabel`). Respect system focus
   rings; use standard controls so VoiceOver works by default.
6. **Never rely on color alone.** Pair every VM-state color with a symbol and a
   text label.
7. **Unknown ≠ zero.** If the backend cannot report a value, render `—`, not
   `0` or `0%`. Distinguish host-observed from guest-reported telemetry.
8. **Design every state**, not just the happy path: loading, empty, populated,
   warning, error. No fabricated/placeholder data shown as live.
9. **Motion only to communicate state change.** No decorative animation.
10. **Motion/compactness intentional.** Menu-bar popover is compact; detail
    pages are spacious.

## Scene structure for a menu-bar management app

```swift
@main
struct TinyBridgeUIApp: App {
    @StateObject private var app = AppViewModel()

    var body: some Scene {
        // Menu-bar control center (window style gives a rich popover).
        MenuBarExtra("TinyBridge", systemImage: "shippingbox") {
            MenuBarView().environmentObject(app)
        }
        .menuBarExtraStyle(.window)

        // Main management window.
        Window("TinyBridge", id: "main") {
            MainWindow().environmentObject(app)
        }
        .defaultSize(width: 1040, height: 680)
        .commands { /* toolbar/menu commands */ }

        // Standard Preferences window (⌘,).
        Settings {
            PreferencesView().environmentObject(app)
        }
    }
}
```

Notes:
- `systemImage:` on `MenuBarExtra` takes an SF Symbol name.
- `.menuBarExtraStyle(.window)` gives a popover-like surface for rich content;
  `.menuBarExtraStyle(.menu)` gives a plain `Menu`.
- Use `@Environment(\.openWindow)` to open the main window from the popover.

## Menu bar content (compact)

- Show VM inventory rows: name, state badge (symbol + color + text), and
  Start/Stop as inline controls.
- Provide: Open TinyBridge (main window), Preferences…, Quit.
- Keep it responsive; do not start expensive work when the popover opens.
- Do not poll aggressively. Prefer event-driven refresh with a slow fallback.

## Layout conventions

- Use a `NavigationSplitView` with a source list sidebar for section
  navigation; `Table` for inventories; `Form` for configuration; Swift Charts
  for metrics.
- Use `.padding()`, `Spacer()`, `LabeledContent`, and `GroupBox`/`Section`
  rather than hand-rolled pixel spacing.
- Toolbar items use `ToolbarItem(placement:)`; destructive actions are
  confirmed with `.confirmationDialog`.

## Accessibility checklist

- [ ] Icon-only controls have `.accessibilityLabel`.
- [ ] State is conveyed by symbol + text, not just color.
- [ ] Keyboard: every action reachable; standard shortcuts (⌘R refresh, ⌘,
      settings, ⌘W close).
- [ ] Charts have `.accessibilityLabel` / `accessibilityValue` where used.
- [ ] Dynamic Type / larger text does not clip or overlap.

## Anti-patterns to reject in review

- Gradient backgrounds, glassmorphism, card-in-card-in-card.
- Emoji icons, hardcoded brand colors, custom look-alike system controls.
- Fake or placeholder metrics presented as real.
- A dashboard that hides the operational facts behind decoration.
- Blocking the main actor with socket reads, subprocesses, or heavy work.

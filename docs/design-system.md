# Design System — TinyBridge-UI

This document records the design tokens, layout rules, iconography, typography,
and interaction conventions the app follows. It is the project-local expression
of Apple's Human Interface Guidelines and SwiftUI documentation (see
`docs/design-skill-audit.md` and the `apple-macos-design` skill).

## Source of truth

The `apple-macos-design` opencode skill (`.opencode/skills/apple-macos-design/SKILL.md`)
encodes these conventions and is the reference reviewers should apply.

## Visual language

### Typography
- System fonts only, via semantic SwiftUI text styles:
  `.largeTitle`, `.title`, `.title2`, `.headline`, `.subheadline`, `.body`,
  `.callout`, `.caption`, `.caption2`, `.monospaced`.
- Never hardcoded point sizes. `Font.system(...)` with a fixed size is
  prohibited.

### Color
- Semantic colors only: `.primary`, `.secondary`, `.tertiary`, `.accentColor`,
  and standard role colors (`.green`, `.red`, `.orange`, `.blue`, `.gray`).
- No raw hex / `Color(red:green:blue:)` that breaks in dark mode.
- Color is **always** a secondary cue; state is conveyed by symbol + text.

### Iconography
- SF Symbols exclusively: `Image(systemName:)` / `Label(_, systemImage:)`.
- No emoji as app, toolbar, or state icons.
- Symbol choices (HIG-aligned):
  - VM: `desktopcomputer`, `cpu`, `memorychip`, `internaldrive`
  - Network: `network`, `externaldrive`
  - Diagnostics: `stethoscope`, `exclamationmark.triangle`, `checkmark.circle`
  - Settings: `gearshape`, `slider.horizontal.3`
  - Menu bar: `shippingbox.fill`

### Materials & layout
- System materials: `.regularMaterial`, `.thinMaterial`, `.ultraThinMaterial`
  for sidebars and sidebars-with-content.
- `GroupBox`, `Section`, `LabeledContent`, `Spacer`, `.padding()` — never
  hand-rolled pixel spacing.
- No gradient soup, no card-in-card-in-card, no decorative chrome.
- Compact in the menu-bar popover; spacious on detail pages.

## State presentation

Every lifecycle state renders as **symbol + color + text** (never color alone):

| State | Symbol | Color | Label |
|---|---|---|---|
| Running | `circle.fill` | green | Running |
| Starting | `arrow.triangle.2.circlepath` | orange | Starting (n%) |
| Stopping | `arrow.down.circle` | orange | Stopping |
| Stopped | `stop.circle` | secondary | Stopped |
| Failed | `exclamationmark.triangle.fill` | red | Failed |
| Unknown | `questionmark.circle` | secondary | Unknown |

Accessibility: `.accessibilityLabel` combines symbol meaning + text. VoiceOver
users hear e.g. "Starting, 42 percent" not just an orange dot.

## Unknown ≠ zero

If the backend cannot report a value, render `—` (em dash), never `0` or `0%`.
This applies to metrics, uptime, IP address, and CPU/memory/disk. Distinguish
*host-observed* from *guest-reported*; never chart fabricated values.

## States every screen must handle

- Loading (spinner + "Loading…")
- Empty (illustrative symbol + title + helpful message)
- Populated (the normal view)
- Warning (orange, actionable)
- Error (red, dismissable, with retry where safe)

## Motion

Animations only to communicate meaningful state change (e.g. a VM transitioning
Starting → Running). No decorative animation.

## Accessibility checklist

- [ ] Icon-only controls carry `.accessibilityLabel`.
- [ ] Every state pairs a symbol with a text label.
- [ ] Full keyboard navigation; standard buttons/menus so VoiceOver works.
- [ ] Respect system focus rings; do not hide them.
- [ ] Charts carry `.accessibilityLabel` / `accessibilityValue`.
- [ ] Dynamic Type (larger text) does not clip or overlap.

## Scenes

| Scene | SwiftUI construct | Purpose |
|---|---|---|
| Menu-bar control center | `MenuBarExtra(.window)` | VM inventory, start/stop, open window, preferences, quit |
| Main window | `Window` + `NavigationSplitView` | Dashboard, VMs, port forwarding, configuration, diagnostics |
| Preferences | `Settings` scene | Backend choice, auto-refresh, about |

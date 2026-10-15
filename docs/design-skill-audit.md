# Design Skill Audit — TinyBridge-UI

Status: Phase 0 reconnaissance complete.
Date: 2026-10-15.
Author: TinyBridge-UI implementation session.

This document records the design skills, and the official design references, that
were **actually discovered and reviewed** before any application code was written.
It distinguishes clearly between:

- **Official Apple documentation** used directly as reference material, and
- **Installable agent skills** that were imported through opencode's real skill
  mechanism, and
- **Unavailable / not-found** sources.

Nothing here is claimed to have been imported unless the import actually
succeeded.

---

## 1. opencode skill system — what is actually supported

Determined from the installed opencode build and its built-in
`customize-opencode` skill (loaded during this session), not from guesswork.

| Capability | Supported? | Mechanism |
|---|---|---|
| Agents | Yes | `.opencode/agent(s)/<name>.md`, `~/.config/opencode/agent(s)/` |
| Commands | Yes | `.opencode/command(s)/<name>.md` |
| Skills | Yes | `.opencode/skill(s)/<name>/SKILL.md` |
| External skills (auto-loaded) | Yes | `~/.claude/skills/<name>/SKILL.md`, `~/.agents/skills/<name>/SKILL.md` |
| Remote skill registries | Yes | `skills.urls` (a URL that serves a list of skills), `skills.paths` |
| MCP servers | Yes | `mcp` object in `opencode.json` |

Skill file format (verified):

```markdown
---
name: kebab-case-name
description: One sentence covering what the skill does AND when to trigger it.
---
# Skill body (markdown instructions, examples, references)
```

The loader scans for `**/SKILL.md` inside skill directories. `name` must match
the folder name and be lowercase-hyphenated (≤64 chars). A skill is filtered out
entirely if it has no `description`.

### Existing state of the machine (inspected before changing anything)

- `~/.config/opencode/opencode.json` — exists, contains an Ollama provider
  config and a `permission.external_directory` allow for
  `/Users/georgimullassery/Desktop/**`. **Preserved, not modified.**
- `~/.claude/skills/` — does not exist.
- `~/.agents/skills/` — does not exist.
- `~/Desktop/Projects/tinybridge/.opencode/` — exists but contains only a
  `.DS_Store`; no skills present.
- No Apple/SwiftUI/Swift skills were present anywhere on the machine.

---

## 2. Official Apple design references (reviewed directly)

These are not installable skills. They are first-party references used as the
design foundation. Where a page required JavaScript to render, the equivalent
Markdown endpoint (`<url>.md`) was used.

| Reference | URL | What it contributes |
|---|---|---|
| Human Interface Guidelines (root) | https://developer.apple.com/design/human-interface-guidelines/ | Layout, hierarchy, color restraint, materials, dark/light behavior, accessibility baselines |
| SwiftUI documentation | https://developer.apple.com/documentation/swiftui | Framework API surface and idioms |
| `Menu` (SwiftUI) | https://developer.apple.com/documentation/swiftui/menu | Menu composition, submenus, primary actions, menu item subtitles, `menuStyle(_:)` |
| `MenuBarExtra` (SwiftUI) | https://developer.apple.com/documentation/swiftui/menubarextra | The supported native macOS menu-bar API; `WindowMenuBarExtraStyle` vs `PullDownMenuBarExtraStyle` |
| `Window` / `WindowGroup` (SwiftUI) | https://developer.apple.com/documentation/swiftui/window | Multi-window scene management, `defaultSize`, restoration |
| `Settings` (SwiftUI scene) | https://developer.apple.com/documentation/swiftui/settings | Standard macOS Preferences window |
| `Table` (SwiftUI) | https://developer.apple.com/documentation/swiftui/table | Native sortable/selectable multi-column data presentation |
| `Form` (SwiftUI) | https://developer.apple.com/documentation/swiftui/form | Native settings/form controls and alignment |
| Swift Charts | https://developer.apple.com/documentation/charts | Native data visualization for resource metrics |
| SF Symbols | https://developer.apple.com/design/human-interface-guidelines/sf-symbols | Iconography conventions and symbol selection |
| Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | VoiceOver, keyboard navigation, accessibility labels |
| Apple Developer videos / WWDC | https://developer.apple.com/videos/ | Menu bar extras, SwiftUI architecture, Swift concurrency sessions |

**Attribution note:** these are Apple's own first-party documents. They are cited
as design guidance and are not redistributed in this repository. No content is
copied verbatim into the codebase; only the principles below are applied.

### Apple documentation access limitation (recorded honestly)

Several `developer.apple.com/documentation/...` pages render only client-side
and return a "This page requires JavaScript" shell when fetched by a non-browser
agent. Those pages expose an alternate Markdown document at
`<url>.md`, which is what was used. Some WWDC video transcript pages are gated
the same way and could not be read as plain text; the HIG and API reference
pages that expose `.md` were sufficient for the design principles below.

---

## 3. Community / open-source skills — discovery outcome

A best-effort search was performed across:

- opencode's `skills.urls` remote-registry mechanism,
- the machine's external skill directories (`~/.claude/skills`,
  `~/.agents/skills`),
- public code-hosting search for SwiftUI / macOS / Apple-HIG agent skills,
- the Apple App Store (explicitly **not** required, and not relevant — it
  distributes end-user apps, not agent skills).

**Outcome: no published, installable agent skill in a recognised opencode /
Agent-Skills format was found for native macOS/SwiftUI design work.** Public
code search returned no verified, well-maintained skill repository following a
documented skill specification for this domain during the audit window. Rather
than import an unreviewed or unverifiable artefact, the decision was made to:

1. Use the official Apple documentation above as the design foundation, and
2. Author a **project-local** skill that packages the applicable Apple guidance
   in opencode's real `SKILL.md` format, so future sessions on this project
   apply the same conventions deterministically.

This is recorded as "authored from Apple's first-party guidance", **not** as a
third-party import, to avoid misrepresenting the provenance.

### Security review of what was *not* imported

Because no third-party skill was imported, there is no third-party skill to
review. No installation script from any repository was executed. No `sudo` was
used. No macOS security control (Gatekeeper, SIP, TCC) was disabled. No network
management endpoint, credential, or secret was touched. See
[`security.md`](security.md) for the full posture.

### Why unrelated skills were excluded

Web/front-end-design skills, mobile-only (iOS/iPadOS/Android) design skills, and
Docker/Electron/Tauri-oriented skills were deliberately **not** imported — this
is a native macOS, Apple-Silicon, SwiftUI utility, and those skills would add
noise and could push the implementation toward non-native patterns the product
explicitly forbids.

---

## 4. Skill actually created (project-local, reviewed)

| Field | Value |
|---|---|
| Name | `apple-macos-design` |
| Location | `TinyBridge-UI/.opencode/skills/apple-macos-design/SKILL.md` |
| Provenance | Authored from Apple's first-party HIG and SwiftUI documentation (Section 2) |
| License | Original text; principles derived from Apple public documentation. No Apple content copied verbatim. |
| Install method | Project-local opencode skill directory (no script, no network) |
| Security review | Plain Markdown, no executable content, no network calls, no credential access |
| Contribution | Encodes the design tokens, layout rules, iconography, typography, and accessibility conventions this app must follow |

---

## 5. Design principles extracted (the rules this app follows)

Distilled from the Apple references in Section 2 and applied throughout
`TinyBridge-UI`.

### 5.1 Platform & structure
- It must feel like a macOS app, not a website in a window.
- Prefer system materials, semantic colors, native forms, toolbars, menus,
  popovers, and standard window behavior.
- The menu-bar extra is a first-class surface (`MenuBarExtra` with a window
  style popover for the control center), not an afterthought.
- Use a `Settings` scene for Preferences (⌘,), `Window`/`WindowGroup` for the
  main management window, `Table` for VM/port inventories, `Form` for
  configuration, and Swift Charts for metrics.

### 5.2 Visual language
- System typography only (SF Pro via `.font(.body)` etc.); use semantic text
  styles, not hardcoded point sizes.
- SF Symbols for all iconography; never emoji as an app icon.
- Restrained color: semantic colors (`.primary`, `.secondary`,
  `.accentColor`, `.red`/`.green`/`.orange`) so light/dark mode work for free.
  No raw hex colors that break in dark mode.
- No decorative gradient soup, no card-on-card-on-card, no dashboard clutter.
- Motion only to communicate state change (e.g. a VM transitioning
  Starting→Running), never for decoration.

### 5.3 Information design
- Clear visual hierarchy: primary status first, configuration second,
  diagnostics last.
- Distinguish *unknown* from *zero* everywhere (e.g. "—" not "0%" when the
  backend cannot report a metric).
- Loading, empty, success, warning, and failure states are all designed, not
  just the happy path.
- Compact where compactness helps (menu-bar popover); spacious where
  readability matters (detail pages).

### 5.4 Accessibility
- Every interactive control gets an accessibility label; icon-only controls
  must have text alternatives.
- Full keyboard navigation; respect system focus rings; use standard buttons
  and menus so VoiceOver works without custom work.
- Do not rely on color alone to convey VM state (pair color with a symbol and
  a text label).

### 5.5 Honesty in UI (project-specific, elevated to a design rule)
- No fabricated metrics. If guest telemetry is unavailable, show that it is
  unavailable, and label host-observed vs guest-reported data.
- Never render a *placeholder* as if it were a live value (TinyBridge's own
  history includes a hardcoded `ip_address` bug; the UI must never repeat that
  class of mistake).
- Unsupported operations are shown as disabled-with-reason, never silently
  hidden or faked.

---

## 6. Unavailable sources and reasons

| Source | Status | Reason |
|---|---|---|
| Third-party Apple-HIG agent skills | Not found | No verified skill repository in a recognised format was located; none imported |
| WWDC session transcript pages (plain text) | Partially unavailable | Client-side rendered; not reliably fetchable as text. Peer API/HIG `.md` pages used instead |
| Apple App Store | N/A by design | Distributes end-user apps, not agent skills; explicitly not the right channel per the brief |

---

## 7. Conclusion

- opencode's skill mechanism is real and documented; the format is
  `SKILL.md` in a named folder.
- No third-party design skill was safe-and-verifiable enough to import, so none
  was. This is documented rather than papered over.
- One project-local skill (`apple-macos-design`) was authored from Apple's
  first-party guidance and installed through opencode's supported project-local
  mechanism.
- The design principles in Section 5 are the foundation the rest of the
  implementation is built on.

# Agent Handoff — promptlm-macos

> A complete, self-contained briefing for the next agent (human or AI) picking up this codebase. Read this first, then `docs/architecture.md` for module-level detail. Last updated 2026-05-05.

---

## 1. What this is

Native macOS **menu bar client** for [promptLM](https://github.com/promptLM/promptlm-app). Lives in the menu bar, opens via configurable global hotkey, lets the user pick a prompt, fills in placeholders via a form, and **pastes the rendered text at the cursor** of whichever app the user was working in.

It is **insert-only** — no LLM execution, no editing of prompt specs. Reading from the user's local prompt repository for now; remote/REST repositories are a later concern.

The Mac app is the first of several planned platform clients (Windows, Linux, iOS, Android), each in its own GitHub repo under the `promptLM` org. The pattern for naming sister repos is `promptlm-{os}` (`promptlm-windows`, `promptlm-linux`, …) — agreed with the user, not `promptlm-client-*` because `promptlm-client-sdk` already exists in the org.

Source of truth for the prompt spec format is the Java `PromptSpec` in [promptlm-app](https://github.com/promptLM/promptlm-app). This client decodes a **tolerant subset** — see §6.

---

## 2. Repo & infra

- **GitHub:** <https://github.com/promptLM/promptlm-macos> (private, Apache-2.0)
- **Local clone:** `/Users/fk/dev/promptLM/promptlm-macos`
- **CI:** GitHub Actions, `macos-14` runner, `swift build -c release` + `swift test` on every push/PR to `main`. Workflow at `.github/workflows/macos.yml`.
- **Distribution:** none yet. App is built locally via `./install.sh`, ad-hoc-signed, dropped into `~/Applications/PromptLMMac.app`. Developer ID signing + notarization + DMG release is the last roadmap item, intentionally not started.
- **Toolchain:** Swift 5.9+, deployment target macOS 13 (Ventura). User dev machine is macOS 26.4.1 / arm64.

### Workflow conventions (set with the user)

- **Step 1 → Step 4** were committed directly to `main` while bootstrapping.
- **From Step 5 onwards** the workflow is **branch + PR + squash-merge**. PR #1 (hotkey) merged. PR #2 (settings window) is open at the time of writing — see §4.
- Commit message style is the body-paragraphs style established by Step 5 — short imperative title, blank line, paragraph(s) explaining the *why*. Sign-off line `Co-Authored-By: Claude …` was used at the start; the user dropped requiring it on later commits, but adding it back doesn't hurt.
- The user prefers **step-by-step delivery**: each PR is a single coherent step that they can install, manually test on their Mac, and approve before the next step begins.

---

## 3. Build & install

```bash
git clone git@github.com:promptLM/promptlm-macos.git
cd promptlm-macos
./install.sh --launch     # build, bundle into .app, install to ~/Applications, run
./install.sh --uninstall  # remove the bundle
./install.sh --system     # install to /Applications instead (uses sudo)
```

The script:

1. `swift build -c release` to produce the executable
2. Wraps it into a real `.app` bundle with an Info.plist that has `LSUIElement=true` (menu-bar-only, no Dock icon, no app menu)
3. Ad-hoc-codesigns it
4. **Kills any running instance** before copying the new bundle in — without that step, LaunchServices keeps the old PID registered for the bundle id and `open` activates the stale process instead of starting the new binary. This was a real bug we hit in Step 4; do not break it.
5. Refreshes LaunchServices via `lsregister -f`.

### Accessibility permission caveat

Pasting at the cursor needs Accessibility permission (System Settings → Privacy & Security → Accessibility). **Ad-hoc signing means each rebuild looks like a different binary to macOS**, so the toggle may be silently revoked after `./install.sh`. Symptom: paste stops working but the rendered text still lands on the clipboard (the `PasteInserter` falls back to clipboard-only on failure). Fix: flip the toggle off + on. Real Developer ID signing fixes this permanently and is on the roadmap.

---

## 4. Current state

### What's done (merged on `main`)

- **Step 1** — repo scaffold, menu bar icon, `install.sh`, GitHub Action.
- **Step 2** — `LocalFolderRepository` reads `*.yaml`, `*.yml`, `*.json` from `~/.promptlm/prompts` (or whatever the settings store has). Bad files surface as inline error rows; one bad file does not break the rest.
- **Step 3** — `PromptRenderer` (regex-based `{{key}}` substitution, allows whitespace inside braces, strict on missing keys) + `PlaceholderFormView` (SwiftUI form, defaults pre-filled, required marker `*`, ⌘↵ submit, ⎋ cancel).
- **Step 4** — `PasteInserter`: snapshot the pasteboard, write rendered text, reactivate the captured frontmost app, synthesize Cmd-V via `CGEvent`, restore the pasteboard after `restoreDelay` (default 400 ms). `AccessibilityCheck.isTrusted` gates this; missing permission throws *before* touching the clipboard so the user's clipboard is never disturbed.
- **Step 5** — `GlobalHotkey` (Carbon `RegisterEventHotKey` wrapper). Default ⌃⌥⌘P. Carbon over `CGEventTap` because `CGEventTap` would need Accessibility too — Carbon needs no permission. Merged in PR #1.

### What's in flight (PR #2, branch `feat/settings-window`)

- `SettingsStore` — UserDefaults-backed `ObservableObject` exposing `repositoryPath`, `hotkey`, `launchAtLogin` as `@Published`. Persists via `didSet`.
- `LoginItem` — `SMAppService.mainApp` wrapper for autostart (macOS 13+).
- `HotkeyRecorder` — `NSViewRepresentable` that captures a key combo on click; requires at least one of ⌘/⌥/⌃ so global shortcuts can't steal regular typing.
- `SettingsView` — three-section `Form`: Prompt repository (text field + Choose / Reveal), Global hotkey (recorder + reset), General (Launch at login).
- `SettingsWindowController` — the latest commit on the branch; replaces the SwiftUI `Settings` scene because LSUIElement apps don't get a reliable show path for it. Hosts `SettingsView` in an explicit `NSWindow`, brings it forward via `NSApp.activate` + `makeKeyAndOrderFront`.
- StatusBarController observes `store.$repositoryPath` and `store.$hotkey` via Combine and reacts live (rebuild repo, re-register hotkey, refresh menu header glyph).

### What the user reported as broken

The user's last message before context handoff was **"Settings funktionieren nicht"** ("Settings don't work"). They were testing the latest commit on `feat/settings-window`. Three plausible meanings, none yet confirmed:

1. **Window doesn't open** when clicking Settings… in the menu — should be fixed by `SettingsWindowController`, but unverified by the user.
2. **Window opens but is empty / fields are missing** — same `NSHostingController` sizing trap that bit us with `PlaceholderFormView` in Step 3 (see §7). The fix there was to drop the SwiftUI `ScrollView`, set explicit `NSWindow` content rect, and let SwiftUI fill via `maxWidth/maxHeight = .infinity`. If Settings is also empty, apply the same pattern.
3. **Window opens, fields show, but changes don't take effect** — Combine subscription wiring problem in `StatusBarController.observeSettings()`. The `dropFirst()` is intentional (don't trigger on initial value), but worth double-checking.

Before doing anything else, **ask the user which of (1)/(2)/(3) it is**, or get them to send a screenshot. Don't blindly rewrite the whole thing — Step 3 had the same shape of bug and the fix was small.

There was also an ambiguous comment **"Das Template CV wird weiterhin einfach übernommen"** ("the template CV is still just taken as-is"). I never fully understood it. Best guesses:
- A typo / autocomplete mishap (German keyboards autocorrect oddly)
- They have a prompt with `{{cv}}` and entering a value doesn't substitute (would be a `PromptRenderer` bug — but tests cover this case extensively, 12/12 green)
- "Das Template" = "the template/default", "CV" = something I'm not parsing — ask for clarification

### Logging request

Just before the worktree was deleted, the user asked **"Können wir anfangen logging einzubauen?"** ("can we start adding logging?") and was interrupted. I had proposed a plan but didn't start: central `Logger` using `os_log` with `subsystem: "dev.promptlm.mac"`, calls at key sites (hotkey register/fire, repo reload, insert success/failure, settings mutations), and a "Reveal Log" button in Settings. **Worth raising again once Settings is sorted** — they explicitly asked for it.

---

## 5. Code map

```
Sources/PromptLMMac/
├── PromptLMMacApp.swift          @main; AppDelegate adaptor; no-op Settings scene
├── MenuBarContent.swift          StatusBarController + AppDelegate (lives here for now)
├── Repository/
│   ├── PromptSpec.swift          Tolerant Codable subset; PlaceholderDef
│   └── LocalFolderRepository.swift   Recursive scan, JSONDecoder + YAMLDecoder
├── Render/
│   └── PromptRenderer.swift      NSRegularExpression-based; throws on missing key
├── Form/
│   ├── PlaceholderFormView.swift SwiftUI form, dynamic per placeholder
│   └── FormWindowController.swift Floating NSWindow host (size estimated from placeholder count)
├── Insert/
│   ├── AccessibilityCheck.swift  AXIsProcessTrusted + open Settings URL
│   ├── PasteboardSnapshot.swift  Multi-item, multi-type capture/restore
│   └── PasteInserter.swift       Orchestrates the paste flow
├── Hotkey/
│   ├── HotkeySpec.swift          {keyCode, modifiers}, Codable, displayString
│   └── GlobalHotkey.swift        Carbon RegisterEventHotKey, single shared handler
└── Settings/
    ├── SettingsStore.swift       UserDefaults-backed @Published shared state
    ├── SettingsView.swift        SwiftUI Form (3 sections)
    ├── SettingsWindowController.swift  Explicit NSWindow host (LSUIElement workaround)
    ├── HotkeyRecorder.swift      NSViewRepresentable + NSView, click-to-record
    └── LoginItem.swift           SMAppService.mainApp wrapper

Tests/PromptLMMacTests/
├── PromptLMMacTests.swift        LocalFolderRepository tests + Fixtures/
├── PromptRendererTests.swift     12 tests covering substitution, whitespace, errors
├── PasteboardSnapshotTests.swift 3 tests, uses isolated NSPasteboard(name:)
├── HotkeySpecTests.swift         4 tests — defaults, display, Codable round-trip
└── SettingsStoreTests.swift      5 tests — defaults, persistence, tilde expansion
```

**30 tests passing on `feat/settings-window`** as of the last commit.

The single dependency is `Yams` (YAML decoder) — see `Package.swift`.

---

## 6. PromptSpec schema (this client's view)

We do **not** mirror the full Java schema. We decode the minimum needed to insert text:

```yaml
id: my-prompt          # required, used as fallback for name
name: My Prompt        # optional, defaults to id
group: Engineering     # optional, drives menu submenu grouping
description: …         # optional, shown as tooltip + form subtitle
text: |                # required — the prompt body with {{placeholders}}
  Hello {{name}}!
placeholders:
  name:
    description: …     # optional — shown beneath the input
    default: World     # optional — pre-fills the field
    required: true     # optional — shows red asterisk, blocks submit
    type: multiline    # optional — currently only "multiline" is special
    options: [a, b, c] # optional — switches input to a Picker
```

Both YAML and JSON are accepted. Unknown fields are ignored. Bad files surface as inline error rows in the menu rather than failing the whole load.

**Known limitation:** placeholder ordering is **alphabetical**, not authored order, because Codable dictionaries lose insertion order. This is mentioned in `PlaceholderFormView` as a TODO; preserving authored order needs a custom decoder using Yams' lower-level node API or a list-based schema.

---

## 7. Hard-won lessons (do not relearn)

1. **MenuBarExtra is unreliable on recent macOS for SwiftPM-built ad-hoc-signed apps.** Use AppKit `NSStatusItem` directly — `MenuBarContent.swift` already does. We hit this on the user's macOS 26.

2. **NSHostingController auto-sizing does not honor SwiftUI `.frame(...)` reliably.** Symptoms: window opens at minimum/wrong size; ScrollView contents collapse to zero height. Fix pattern (see `FormWindowController` and `SettingsWindowController`): create the `NSWindow` with an **explicit content rect**, drop ScrollView when possible, and have the SwiftUI root use `.frame(maxWidth: .infinity, maxHeight: .infinity)` so it fills the window.

3. **Stale processes after reinstall.** When a previous launch is still running under the same bundle id, macOS LaunchServices treats `open` as activate-existing instead of launch-new. `install.sh` `pkill`s the old binary and runs `lsregister -f` before `open`. Don't drop those.

4. **Capture frontmost app *before* taking focus.** The flow on prompt-selection is: capture `NSWorkspace.shared.frontmostApplication` *first*, then maybe present the form (which needs `NSApp.activate`), then on submit reactivate the captured app and send Cmd-V. Doing it in any other order pastes into the wrong app or into our own form.

5. **Pasteboard restore needs a delay.** The target app needs to have actually read the pasteboard before we overwrite it again. Default 400 ms (`PasteInserter.restoreDelay`). Less than ~250 ms races slow apps.

6. **Carbon `RegisterEventHotKey` over `CGEventTap`.** Carbon needs no permission; `CGEventTap` would need Accessibility on top of what pasting already needs. The Carbon API is deprecated but still functional and there is no Apple replacement that doesn't make UX worse.

7. **`onChange(of:initial:_:)` is macOS 14-only.** We target macOS 13. Use the older `.onChange(of: x, perform: ...)` form. CI (which is also macOS 14) won't catch this — only the deployment-target check does.

8. **macOS 14+ `NSApp.activate()` is the new API**, pre-14 it's `activate(ignoringOtherApps:)`. Both call sites in `MenuBarContent.swift` use `if #available(macOS 14, *)` to switch. Same for `NSRunningApplication.activate`.

---

## 8. Roadmap

Done:

- [x] Step 1 — Scaffold + menu bar icon
- [x] Step 2 — Local folder repository
- [x] Step 3 — Renderer + placeholder form
- [x] Step 4 — Paste-at-cursor
- [x] Step 5 — Global hotkey (default ⌃⌥⌘P) — **PR #1 merged**

In flight:

- [/] Step 6 — Settings window (repo path, hotkey recorder, launch at login) — **PR #2, user reports it doesn't work, see §4**

Not started:

- [ ] **Logging** — user-requested; not yet planned in any commit
- [ ] **Quick picker** — Spotlight-style floating panel with fuzzy search, replacing the dropdown menu as the hotkey target. The right next feature once the menu has more than ~15 prompts.
- [ ] **Authored-order placeholders** — replace `[String: PlaceholderDef]` with an order-preserving decode
- [ ] **Code signing + notarization + DMG** — required before any public distribution
- [ ] **Onboarding for Accessibility permission** — currently fires only on first paste failure; could be proactive on first launch

---

## 9. Where to start

1. **Verify the worktree.** The previous agent worked in `/Users/fk/dev/promptLM/promptlm-app/.claude/worktrees/...`, which has been deleted. The Mac app lives at **`/Users/fk/dev/promptLM/promptlm-macos`** — `cd` there before doing anything.
2. **Switch to the open branch.** `git checkout feat/settings-window`. Run `swift build && swift test` to confirm 30/30 green.
3. **Ask the user** which symptom of "Settings funktionieren nicht" they're seeing (see §4). Don't guess.
4. Apply the targeted fix, push to the same branch, ping them again. Once they confirm, squash-merge PR #2.
5. Then either start the **logging** plan they asked for, or move on to the **quick picker** — whichever they want next. Default to whatever the user's most recent ask was.

Stay in the **branch + PR per step** rhythm from Step 5 onwards. Don't push to `main`.

---

## 10. User profile (working notes)

- Speaks German with the agent. Replies are usually short ("ok, weiter", "funktioniert"). Read those as approvals, not new questions.
- Wants visible progress they can install and click — **don't batch features**. Each step ends with `./install.sh --launch` and a quick verification protocol they can do in 30 seconds.
- Comfortable with the agent making opinionated calls (Swift over Java, NSStatusItem over MenuBarExtra, Carbon over CGEventTap). State the recommendation + reasoning + accept their override quickly when they push back.
- Notch-equipped MacBook Air — the menu bar fills up easily. Aware Hidden Bar exists; that recommendation already landed.

# Architecture

Native macOS menubar client for promptLM. Inserts rendered prompts at the cursor of the focused application via a Spotlight-style picker, triggered by a configurable global hotkey.

## Module layout (planned)

```
Sources/PromptLMMac/
├── App/                  # Entry point, AppDelegate, DI
├── Menubar/              # MenuBarExtra / NSStatusItem
├── Picker/               # Spotlight-style floating panel + fuzzy search
├── Form/                 # Dynamic placeholder form
├── Repository/           # PromptSpec loaders (local folder for MVP)
├── Render/               # {{key}} substitution (parity with promptlm-app)
├── Insert/               # Pasteboard save/restore + ⌘V dispatch
├── Hotkey/               # Carbon RegisterEventHotKey wrapper
├── Settings/             # UserDefaults-backed store, settings window
└── Util/
```

## Key flows

### Insert flow
1. User presses configured global hotkey (or clicks menubar icon).
2. `frontmostApplication` is captured before the picker takes focus.
3. Quick picker (`NSPanel`, `.floating` level, `nonactivatingPanel`) shows fuzzy-searched prompts.
4. On selection:
   - if `placeholders` empty → render → paste.
   - else → placeholder form → render → paste.
5. Paste:
   1. Save current pasteboard items.
   2. Write rendered text.
   3. Reactivate previous frontmost app.
   4. Post `CGEvent` ⌘V.
   5. After configurable delay (~250 ms) restore original pasteboard.

### Hotkey
`RegisterEventHotKey` (Carbon) — works without Accessibility permission. Modifier+keycode persisted in UserDefaults.

## PromptSpec compatibility

Source of truth: [promptlm-app `PromptSpec.java`](https://github.com/promptLM/promptlm-app/blob/main/components/promptlm-domain/src/main/java/dev/promptlm/domain/promptspec/PromptSpec.java).

This client decodes a tolerant subset:

- `id`, `name`, `group`, `description`
- `request` (chat messages or single prompt)
- `placeholders.definitions` → `{ description?, defaultValue?, required?, type?, options? }`

Unknown fields are ignored. Schema parity is verified by snapshot tests against fixtures committed under `Tests/PromptLMMacTests/Fixtures/` (synced from `promptlm-app` JSON samples).

## Permissions

| Capability | API | Permission |
|---|---|---|
| Global hotkey | Carbon `RegisterEventHotKey` | none |
| Read frontmost app | `NSWorkspace.frontmostApplication` | none |
| Simulated ⌘V | `CGEvent.post` | **Accessibility** (System Settings → Privacy) |
| Login item | `SMAppService.mainApp` | none (macOS 13+) |

First-run onboarding guides the user to grant Accessibility access, with a re-check on focus regain.

## Distribution

- Developer ID signed + notarized via `notarytool`.
- DMG produced in CI on tagged releases (GitHub Actions, `macos-14`).
- Initially **non-sandboxed** for unrestricted folder access to local prompt repositories. Sandbox + Security-Scoped Bookmarks is a follow-up if App Store distribution is pursued.

## Out of scope (MVP)

- Remote prompt repositories (GitHub, REST). Local folder only.
- Prompt execution / LLM calls. The client is insert-only.
- Multi-language UI.

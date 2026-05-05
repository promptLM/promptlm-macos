# promptlm-macos

Native macOS menubar app for [promptLM](https://github.com/promptLM/promptlm-app).

Lives in your menu bar, opens a Spotlight-style picker via configurable global shortcut, and inserts prompts from local prompt repositories at the cursor position. Prompts with placeholders trigger a small form first.

> Status: early scaffold. Menu bar icon only. Picker, hotkey, repository loading, render and paste are tracked in [issues](../../issues).

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ / Swift 5.9+ (for development)

## Build & install

```bash
./install.sh             # build, wrap into .app, install to ~/Applications
./install.sh --launch    # also start the app
./install.sh --system    # install to /Applications instead (uses sudo)
./install.sh --uninstall # remove the installed bundle
```

After install you should see a small chat-bubble icon in the menu bar. Click it to see your prompts.

### Seeding prompts

By default the app reads from `~/.promptlm/prompts`. Override with the env var `PROMPTLM_PROMPTS_DIR`. To try the bundled samples:

```bash
mkdir -p ~/.promptlm/prompts
cp docs/sample-prompts/* ~/.promptlm/prompts/
```

Then click the menu bar icon — the prompts should appear, grouped by their `group` field. Selecting a prompt:

- with **no placeholders** → its text is pasted at your cursor
- with **placeholders** → a form opens with a field per placeholder (defaults pre-filled, required fields marked `*`); on submit the rendered text is pasted at your cursor

The original clipboard contents are restored ~400 ms after the paste.

### Accessibility permission

The first time you select a prompt, macOS will block the synthesized ⌘V. The app shows an alert and offers to open System Settings — flip the toggle for **promptLM** under **Privacy & Security → Accessibility**, then try again.

> **Ad-hoc build caveat:** because the install script signs the app ad-hoc (no Developer ID), macOS may treat each rebuild as a different binary and revoke the permission. If pasting silently stops working after `./install.sh`, re-grant the toggle. Real signing + notarization will fix this; it is on the roadmap.

If pasting fails for any other reason, the rendered prompt is still copied to your clipboard so you can paste manually.

### Prompt file format

YAML or JSON. Minimum:

```yaml
id: my-prompt
name: My Prompt
text: Hello {{audience}}!
placeholders:
  audience:
    default: world
```

The app is ad-hoc signed; on first launch macOS may show a Gatekeeper prompt — right-click the app in Finder and choose **Open** to confirm. Real Developer ID signing + notarization comes later in the roadmap.

For development without bundling:

```bash
swift build
swift run PromptLMMac
```

Or open `Package.swift` in Xcode and run.

## Architecture

See [docs/architecture.md](docs/architecture.md) for the planned module layout and decisions.

The PromptSpec format is defined by [promptlm-app](https://github.com/promptLM/promptlm-app); this client reads a compatible subset (id, name, group, description, request, placeholders).

## Roadmap

- [x] Repo scaffold + menu bar icon
- [x] Local folder prompt repository (YAML/JSON) — prompts listed in menu
- [x] Native `{{key}}` renderer
- [x] Placeholder form (dynamic from PromptSpec)
- [x] Paste-at-cursor insertion with pasteboard restore
- [ ] Spotlight-style quick picker with fuzzy search
- [ ] Configurable global hotkey
- [ ] Settings window (repo path, hotkey recorder, autostart)
- [ ] Code signing + notarization + DMG release

Sister clients planned for Windows, Linux, iOS, Android — each in its own repo.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

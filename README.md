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

After install you should see a small chat-bubble icon in the menu bar. Click it for the (currently placeholder) menu.

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
- [ ] Local folder prompt repository (YAML/JSON)
- [ ] Spotlight-style quick picker with fuzzy search
- [ ] Configurable global hotkey
- [ ] Placeholder form (dynamic from PromptSpec)
- [ ] Native `{{key}}` renderer (parity with promptlm-app `DefaultPromptRenderer`)
- [ ] Paste-at-cursor insertion with pasteboard restore
- [ ] Settings window (repo path, hotkey recorder, autostart)
- [ ] Code signing + notarization + DMG release

Sister clients planned for Windows, Linux, iOS, Android — each in its own repo.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

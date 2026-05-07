// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var loginItemError: String?
    @FocusState private var repositoryPathFocused: Bool

    var body: some View {
        Form {
            Section("Prompt repository") {
                HStack {
                    TextField("Folder", text: $store.repositoryPath)
                        .textFieldStyle(.roundedBorder)
                        .focused($repositoryPathFocused)
                    Button("Choose…") { pickFolder() }
                    Button("Reveal") { revealFolder() }
                        .disabled(!folderExists)
                }
                Text(folderExists
                     ? "promptLM scans this folder for *.yaml, *.yml, and *.json prompt specs."
                     : "Folder does not exist yet. It will be created when you choose or reveal it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global hotkey") {
                HotkeyRecorder(spec: $store.hotkey)
                    .frame(height: 30)
                HStack {
                    Text("Press anywhere to open the prompt menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset to default") {
                        store.hotkey = .default
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $store.launchAtLogin)
                if let error = loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
        .onChange(of: store.launchAtLogin, perform: applyLaunchAtLogin)
        .onAppear {
            // Defer to next runloop so the window is fully presented before
            // SwiftUI applies focus — same fix as the picker and form views.
            DispatchQueue.main.async {
                repositoryPathFocused = true
            }
        }
    }

    private var folderExists: Bool {
        FileManager.default.fileExists(atPath: store.repositoryURL.path)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = store.repositoryURL
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            store.repositoryPath = url.path
        }
    }

    private func revealFolder() {
        let url = store.repositoryURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url, withIntermediateDirectories: true
            )
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginItemError = nil
        } catch {
            loginItemError = "Could not change Login Items: \(error.localizedDescription)"
            // Roll back the toggle so the UI matches reality.
            DispatchQueue.main.async {
                store.launchAtLogin = !enabled
            }
        }
    }
}

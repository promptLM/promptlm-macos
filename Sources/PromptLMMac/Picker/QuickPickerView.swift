// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Spotlight-style picker: a single search field and a scrollable list of
/// prompts that filter as the user types. Arrow keys move selection,
/// Enter activates, Esc closes.
struct QuickPickerView: View {

    let index: PromptIndex
    let onActivate: (IndexedPrompt) -> Void
    let onCancel: () -> Void

    @State private var query: String = ""
    @State private var selection: IndexedPrompt.ID?
    @FocusState private var searchFocused: Bool

    private var results: [IndexedPrompt] { index.search(query) }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if results.isEmpty {
                emptyState
            } else {
                resultsList
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyEventCatcher(
            onUp:    { moveSelection(by: -1) },
            onDown:  { moveSelection(by:  1) },
            onEnter: { activateSelected() },
            onEsc:   { onCancel() }
        ))
        .onAppear {
            selection = results.first?.id
            // Defer focus to the next runloop tick — when the picker is
            // presented from a hotkey, .onAppear fires before the panel is
            // fully key, and an immediate @FocusState assignment is dropped.
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
        .onChange(of: query) { _ in
            // Keep selection valid as the result list changes.
            if let sel = selection, results.contains(where: { $0.id == sel }) {
                return
            }
            selection = results.first?.id
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search prompts…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused($searchFocused)
                .onSubmit { activateSelected() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(results) { entry in
                    PickerRow(entry: entry)
                        .tag(entry.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onActivate(entry) }
                        .id(entry.id)
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 280)
            .onChange(of: selection) { newSel in
                if let id = newSel {
                    withAnimation(.linear(duration: 0.05)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Text(query.isEmpty ? "No prompts available" : "No matches")
                .foregroundStyle(.secondary)
            if query.isEmpty {
                Text("Add a project to ~/.promptlm/context.json or drop a prompt YAML into your repository.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(results.count) prompt\(results.count == 1 ? "" : "s")")
            Spacer()
            Text("↑↓ to navigate")
            Text("↵ to insert")
            Text("esc to close")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let currentIdx = results.firstIndex { $0.id == selection } ?? -1
        let nextIdx = max(0, min(results.count - 1, currentIdx + delta))
        selection = results[nextIdx].id
    }

    private func activateSelected() {
        guard let sel = selection,
              let entry = results.first(where: { $0.id == sel })
        else { return }
        onActivate(entry)
    }
}

private struct PickerRow: View {
    let entry: IndexedPrompt

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.prompt.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.project.name)
                        .foregroundStyle(.tertiary)
                    if let group = entry.prompt.group, !group.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(group).foregroundStyle(.secondary)
                    }
                    if let desc = entry.prompt.description, !desc.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(desc)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11))
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

/// Captures arrow / enter / escape key events at the window level so they
/// work regardless of which subview holds focus. SwiftUI alone can't reliably
/// intercept ↑/↓ while a TextField is focused, hence the AppKit shim.
private struct KeyEventCatcher: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onEsc: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.handler = { code in
            switch code {
            case 126: onUp();    return true        // up arrow
            case 125: onDown();  return true        // down arrow
            case 36, 76: onEnter(); return true     // return / numpad enter
            case 53: onEsc();    return true        // escape
            default: return false
            }
        }
        return v
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.handler = { code in
            switch code {
            case 126: onUp();    return true
            case 125: onDown();  return true
            case 36, 76: onEnter(); return true
            case 53: onEsc();    return true
            default: return false
            }
        }
    }

    final class CatcherView: NSView {
        var handler: ((UInt16) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                if self.handler?(event.keyCode) == true {
                    return nil
                }
                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

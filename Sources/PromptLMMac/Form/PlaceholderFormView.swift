// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Dynamic form generated from a `PromptSpec.placeholders` map.
///
/// One row per placeholder. Default values pre-fill the inputs. Required
/// fields show an asterisk and disable submission until filled. The first
/// field is focused on appear. ⌘↵ submits, ⎋ cancels.
///
/// Placeholder ordering is alphabetical for now — YAML/JSON dictionaries do
/// not preserve insertion order through Codable. Preserving authored order
/// is a follow-up.
struct PlaceholderFormView: View {

    let prompt: PromptSpec
    let onSubmit: ([String: String]) -> Void
    let onCancel: () -> Void

    private let orderedKeys: [String]
    @State private var values: [String: String]
    @FocusState private var focusedKey: String?

    init(
        prompt: PromptSpec,
        onSubmit: @escaping ([String: String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.prompt = prompt
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.orderedKeys = prompt.placeholders.keys.sorted()
        var initial: [String: String] = [:]
        for (k, def) in prompt.placeholders {
            initial[k] = def.defaultValue ?? ""
        }
        self._values = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(orderedKeys, id: \.self) { key in
                        if let def = prompt.placeholders[key] {
                            fieldRow(key: key, def: def)
                        }
                    }
                }
                .padding(.horizontal, 1) // avoid focus-ring clipping
            }
            .frame(maxHeight: 360)
            footer
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            DispatchQueue.main.async {
                focusedKey = orderedKeys.first
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prompt.name).font(.title2).bold()
            if let desc = prompt.description, !desc.isEmpty {
                Text(desc).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("Insert", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
        }
    }

    private var canSubmit: Bool {
        for (key, def) in prompt.placeholders where def.required == true {
            if (values[key] ?? "").isEmpty { return false }
        }
        return true
    }

    private func submit() {
        guard canSubmit else { return }
        onSubmit(values)
    }

    @ViewBuilder
    private func fieldRow(key: String, def: PlaceholderDef) -> some View {
        let binding = Binding<String>(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(key).font(.subheadline).bold()
                if def.required == true {
                    Text("*").foregroundStyle(.red)
                }
                Spacer()
            }
            if let desc = def.description, !desc.isEmpty {
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            input(for: def, key: key, binding: binding)
        }
    }

    @ViewBuilder
    private func input(
        for def: PlaceholderDef,
        key: String,
        binding: Binding<String>
    ) -> some View {
        if let options = def.options, !options.isEmpty {
            Picker("", selection: binding) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .focused($focusedKey, equals: key)
        } else if def.type?.lowercased() == "multiline" {
            TextEditor(text: binding)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
                .focused($focusedKey, equals: key)
        } else {
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
                .focused($focusedKey, equals: key)
        }
    }
}

// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit

/// Captures the current contents of an NSPasteboard so they can be restored
/// after we temporarily overwrite the clipboard to paste a rendered prompt.
///
/// Multi-item, multi-type clipboards (e.g. an image with rich-text fallback)
/// are preserved by storing the raw `Data` for every type on every item.
public struct PasteboardSnapshot {

    public typealias TypedData = [NSPasteboard.PasteboardType: Data]

    private let items: [TypedData]
    private let changeCount: Int

    public init(of pasteboard: NSPasteboard = .general) {
        self.changeCount = pasteboard.changeCount
        self.items = (pasteboard.pasteboardItems ?? []).map { item in
            var dict: TypedData = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    /// Restore the captured items onto the given pasteboard.
    ///
    /// Safe to call even if another writer touched the pasteboard in the
    /// meantime — we simply overwrite. If the snapshot was empty, the
    /// pasteboard is cleared.
    public func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let pbItems: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pbItems)
    }

    /// Number of items captured. Exposed for tests.
    public var itemCount: Int { items.count }
    public var capturedChangeCount: Int { changeCount }
}

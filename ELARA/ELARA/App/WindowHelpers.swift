import AppKit

enum WindowHelpers {
    /// Puts the cursor in the toolbar search field (⌘F).
    /// SwiftUI's `.searchable` has no focus API before macOS 15, so we find the AppKit field directly.
    @MainActor
    static func focusSearchField() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        if let toolbar = window.toolbar {
            for item in toolbar.items {
                if let search = item as? NSSearchToolbarItem {
                    window.makeFirstResponder(search.searchField)
                    return
                }
                if let field = findSearchField(in: item.view) {
                    window.makeFirstResponder(field)
                    return
                }
            }
        }
        if let field = findSearchField(in: window.contentView?.superview) {
            window.makeFirstResponder(field)
        }
    }

    private static func findSearchField(in view: NSView?) -> NSSearchField? {
        guard let view else { return nil }
        if let field = view as? NSSearchField { return field }
        for sub in view.subviews {
            if let found = findSearchField(in: sub) { return found }
        }
        return nil
    }
}

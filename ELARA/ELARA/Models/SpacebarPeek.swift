import Foundation

/// Finder-style spacebar behaviour for Quick View:
/// - **Tap** Space: opens Quick View (it stays open). Tap again to close.
/// - **Hold** Space: Quick View shows only while the key is held and closes on release ("peek").
///
/// Pure value type so it can be unit-tested without a keyboard.
struct SpacebarPeek {
    /// Holding longer than this counts as a peek rather than a tap.
    static let holdThreshold: TimeInterval = 0.35

    enum Action: Equatable { case open, close, none }

    private var pressStart: Date?
    private var openedByThisPress = false

    /// Key went down. Auto-repeat events while held must not call this (they're ignored).
    mutating func keyDown(isOpen: Bool, at time: Date = Date()) -> Action {
        guard pressStart == nil else { return .none } // Already down (missed key-up or repeat).
        pressStart = time
        openedByThisPress = !isOpen
        return isOpen ? .close : .open
    }

    /// Key came up. Closes only if this press opened Quick View *and* it was held (a peek).
    mutating func keyUp(isOpen: Bool, at time: Date = Date()) -> Action {
        defer { pressStart = nil; openedByThisPress = false }
        guard let start = pressStart, openedByThisPress, isOpen else { return .none }
        return time.timeIntervalSince(start) >= Self.holdThreshold ? .close : .none
    }

    /// Clears state, e.g. when the window loses focus mid-press.
    mutating func reset() {
        pressStart = nil
        openedByThisPress = false
    }
}

/// Arrow-key movement through a list of items laid out in `columns` columns.
enum SelectionMover {
    /// Returns the index to select after moving `step` from `current` (nil = nothing selected yet).
    static func index(from current: Int?, step: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let current else { return step < 0 ? count - 1 : 0 }
        return min(max(current + step, 0), count - 1)
    }
}

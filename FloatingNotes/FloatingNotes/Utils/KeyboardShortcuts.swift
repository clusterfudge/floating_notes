import SwiftUI
import AppKit

/// Keyboard shortcut definitions and handlers
struct KeyboardShortcuts {
    // MARK: - Note Actions
    static let newNote = KeyboardShortcut("n", modifiers: .command)
    static let newNoteFromTemplate = KeyboardShortcut("n", modifiers: [.command, .shift])
    static let deleteNote = KeyboardShortcut(.delete, modifiers: .command)
    static let pinNote = KeyboardShortcut("p", modifiers: [.command, .shift])
    static let archiveNote = KeyboardShortcut("e", modifiers: [.command, .shift])

    // MARK: - Navigation
    static let commandPalette = KeyboardShortcut("k", modifiers: .command)
    static let toggleSidebar = KeyboardShortcut("s", modifiers: [.command, .control])
    static let nextNote = KeyboardShortcut(.downArrow, modifiers: [.command, .option])
    static let previousNote = KeyboardShortcut(.upArrow, modifiers: [.command, .option])

    // MARK: - Sync
    static let syncAll = KeyboardShortcut("s", modifiers: [.command, .option])

    // MARK: - Settings
    static let openSettings = KeyboardShortcut(",", modifiers: .command)
}

/// Global keyboard event monitor
class KeyboardEventMonitor {
    private var monitors: [Any] = []

    func start(handlers: [(KeyboardShortcut, () -> Void)]) {
        // Local monitor for key events
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            for (shortcut, handler) in handlers {
                if self.matches(event: event, shortcut: shortcut) {
                    handler()
                    return nil
                }
            }
            return event
        }

        if let monitor = localMonitor {
            monitors.append(monitor)
        }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }

    private func matches(event: NSEvent, shortcut: KeyboardShortcut) -> Bool {
        // Check modifiers
        var requiredModifiers: NSEvent.ModifierFlags = []
        if shortcut.modifiers.contains(.command) {
            requiredModifiers.insert(.command)
        }
        if shortcut.modifiers.contains(.shift) {
            requiredModifiers.insert(.shift)
        }
        if shortcut.modifiers.contains(.option) {
            requiredModifiers.insert(.option)
        }
        if shortcut.modifiers.contains(.control) {
            requiredModifiers.insert(.control)
        }

        let eventModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard eventModifiers == requiredModifiers else { return false }

        // Check key
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }

        // Handle special keys
        switch shortcut.key {
        case .delete:
            return event.keyCode == 51 // Backspace key
        case .upArrow:
            return event.keyCode == 126
        case .downArrow:
            return event.keyCode == 125
        case .leftArrow:
            return event.keyCode == 123
        case .rightArrow:
            return event.keyCode == 124
        case .escape:
            return event.keyCode == 53
        case .return:
            return event.keyCode == 36
        case .tab:
            return event.keyCode == 48
        default:
            // Character key
            if case .character(let char) = shortcut.key {
                return characters == String(char).lowercased()
            }
            return false
        }
    }
}

/// View modifier for handling keyboard shortcuts
struct KeyboardShortcutHandler: ViewModifier {
    let shortcuts: [(KeyboardShortcut, () -> Void)]

    func body(content: Content) -> some View {
        content.background(KeyboardShortcutView(shortcuts: shortcuts))
    }
}

struct KeyboardShortcutView: NSViewRepresentable {
    let shortcuts: [(KeyboardShortcut, () -> Void)]

    func makeNSView(context: Context) -> NSView {
        let view = KeyboardMonitorView()
        view.shortcuts = shortcuts
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyboardMonitorView {
            view.shortcuts = shortcuts
        }
    }
}

class KeyboardMonitorView: NSView {
    var shortcuts: [(KeyboardShortcut, () -> Void)] = []

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        for (shortcut, handler) in shortcuts {
            if matches(event: event, shortcut: shortcut) {
                handler()
                return
            }
        }
        super.keyDown(with: event)
    }

    private func matches(event: NSEvent, shortcut: KeyboardShortcut) -> Bool {
        // Similar matching logic as KeyboardEventMonitor
        var requiredModifiers: NSEvent.ModifierFlags = []
        if shortcut.modifiers.contains(.command) {
            requiredModifiers.insert(.command)
        }
        if shortcut.modifiers.contains(.shift) {
            requiredModifiers.insert(.shift)
        }
        if shortcut.modifiers.contains(.option) {
            requiredModifiers.insert(.option)
        }
        if shortcut.modifiers.contains(.control) {
            requiredModifiers.insert(.control)
        }

        let eventModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard eventModifiers == requiredModifiers else { return false }

        guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }

        if case .character(let char) = shortcut.key {
            return characters == String(char).lowercased()
        }
        return false
    }
}

extension View {
    func handleKeyboardShortcuts(_ shortcuts: [(KeyboardShortcut, () -> Void)]) -> some View {
        modifier(KeyboardShortcutHandler(shortcuts: shortcuts))
    }
}

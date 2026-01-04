import SwiftUI
import AppKit

/// Custom NSTextView wrapper for markdown editing with image paste support
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var onEmojiTrigger: ((String, Int) -> Void)?
    var onImagePaste: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = LinkPasteTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Text container setup
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        // Store callbacks
        textView.onImagePaste = onImagePaste
        textView.onEmojiTrigger = onEmojiTrigger

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Check for emoji trigger
            checkForEmojiTrigger(in: textView)
        }

        private func checkForEmojiTrigger(in textView: NSTextView) {
            let text = textView.string
            let cursorPosition = textView.selectedRange().location

            // Look for :shortcode pattern before cursor
            guard cursorPosition > 0 else { return }

            let beforeCursor = String(text.prefix(cursorPosition))
            let pattern = ":([a-zA-Z0-9_+-]*)$"

            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: beforeCursor, range: NSRange(beforeCursor.startIndex..., in: beforeCursor)),
               let range = Range(match.range(at: 1), in: beforeCursor) {
                let searchText = String(beforeCursor[range])
                parent.onEmojiTrigger?(searchText, cursorPosition)
            }
        }
    }
}

/// Custom NSTextView with image paste support
class LinkPasteTextView: NSTextView {
    var onImagePaste: (() -> Void)?
    var onEmojiTrigger: ((String, Int) -> Void)?

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // Check for image first
        if pasteboard.canReadItem(withDataConformingToTypes: NSImage.imageTypes) ||
           pasteboard.types?.contains(.png) == true ||
           pasteboard.types?.contains(.tiff) == true {
            onImagePaste?()
            return
        }

        // Check for file URLs that might be images
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic"]
            if urls.first(where: { imageExtensions.contains($0.pathExtension.lowercased()) }) != nil {
                onImagePaste?()
                return
            }
        }

        // Default paste behavior
        super.paste(sender)
    }

    override func keyDown(with event: NSEvent) {
        // Handle Escape to dismiss emoji completion
        if event.keyCode == 53 { // Escape key
            // Will be handled by the parent view
        }

        super.keyDown(with: event)
    }

    // Markdown syntax highlighting helpers
    override func didChangeText() {
        super.didChangeText()
        highlightMarkdown()
    }

    private func highlightMarkdown() {
        guard let textStorage = textStorage else { return }

        let text = string
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // Reset to default style
        textStorage.beginEditing()
        textStorage.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        // Highlight headers
        highlightPattern("^#{1,6}\\s+.*$", color: NSColor.systemBlue, in: textStorage)

        // Highlight bold
        highlightPattern("\\*\\*[^*]+\\*\\*", color: NSColor.labelColor, bold: true, in: textStorage)
        highlightPattern("__[^_]+__", color: NSColor.labelColor, bold: true, in: textStorage)

        // Highlight italic
        highlightPattern("\\*[^*]+\\*", color: NSColor.labelColor, italic: true, in: textStorage)
        highlightPattern("_[^_]+_", color: NSColor.labelColor, italic: true, in: textStorage)

        // Highlight code
        highlightPattern("`[^`]+`", color: NSColor.systemPink, in: textStorage)

        // Highlight links
        highlightPattern("\\[([^\\]]+)\\]\\(([^)]+)\\)", color: NSColor.systemBlue, in: textStorage)

        // Highlight list items
        highlightPattern("^\\s*[-*+]\\s+", color: NSColor.systemOrange, in: textStorage)
        highlightPattern("^\\s*\\d+\\.\\s+", color: NSColor.systemOrange, in: textStorage)

        // Highlight checkboxes
        highlightPattern("^\\s*-\\s*\\[[ x]\\]", color: NSColor.systemGreen, in: textStorage)

        textStorage.endEditing()
    }

    private func highlightPattern(_ pattern: String, color: NSColor, bold: Bool = false, italic: Bool = false, in textStorage: NSTextStorage) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }

        let text = string
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))

        for match in matches {
            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]

            if bold {
                attributes[.font] = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            }
            if italic {
                attributes[.font] = NSFontManager.shared.convert(
                    NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    toHaveTrait: .italicFontMask
                )
            }

            textStorage.addAttributes(attributes, range: match.range)
        }
    }
}

#Preview {
    MarkdownTextView(text: .constant("# Hello World\n\nThis is a **test** note."))
        .frame(width: 500, height: 400)
}

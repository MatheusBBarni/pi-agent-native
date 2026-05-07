import SwiftUI
import AppKit

struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var placeholder: String
    var fontSize = 15.0
    var isEditable = true
    var onSubmit: () -> Void
    var onCycleReasoning: () -> Void
    var onControlKey: (ComposerControlKey) -> Bool = { _ in false }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
        textView.onControlKey = onControlKey
        textView.placeholder = placeholder
        textView.isEditable = isEditable
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = NSColor(Theme.primaryText)
        textView.insertionPointColor = NSColor.systemBlue
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SubmitTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        let safeSelectedRange = Self.clampedSelectedRange(selectedRange, textLength: (textView.string as NSString).length)
        if textView.selectedRange() != safeSelectedRange {
            textView.setSelectedRange(safeSelectedRange)
        }
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
        textView.onControlKey = onControlKey
        textView.placeholder = placeholder
        textView.font = .systemFont(ofSize: fontSize)
        textView.isEditable = isEditable
        textView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }

    static func clampedSelectedRange(_ range: NSRange, textLength: Int) -> NSRange {
        let length = max(0, textLength)
        let location = min(max(0, range.location), length)
        let selectionLength = min(max(0, range.length), length - location)
        return NSRange(location: location, length: selectionLength)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var selectedRange: NSRange

        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            _text = text
            _selectedRange = selectedRange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            selectedRange = textView.selectedRange()
            textView.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            selectedRange = textView.selectedRange()
        }
    }
}

final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCycleReasoning: (() -> Void)?
    var onControlKey: ((ComposerControlKey) -> Bool)?
    var placeholder = ""

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 126, onControlKey?(.up) == true {
            return
        }

        if event.keyCode == 125, onControlKey?(.down) == true {
            return
        }

        if event.keyCode == 53, onControlKey?(.escape) == true {
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            if modifiers.contains(.shift) {
                insertNewlineIgnoringFieldEditor(self)
            } else if onControlKey?(.returnKey) == true {
                return
            } else {
                onSubmit?()
            }
            return
        }

        if event.keyCode == 48, modifiers.contains(.shift) {
            onCycleReasoning?()
            return
        }

        if event.keyCode == 48, onControlKey?(.tab) == true {
            return
        }

        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor(Theme.tertiaryText)
        ]
        placeholder.draw(at: NSPoint(x: 0, y: 0), withAttributes: attributes)
    }
}

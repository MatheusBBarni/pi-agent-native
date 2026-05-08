import SwiftUI
import AppKit

struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    var focusRequest: Int
    @Binding var selectedRange: NSRange
    var placeholder: String
    var fontSize = 15.0
    var isEditable = true
    var pendingTextReplacement: MentionTextReplacement?
    var onTextReplacementApplied: (UUID, Bool) -> Void = { _, _ in }
    var onSelectionChange: (NSRange) -> Void = { _ in }
    var onMentionCommand: (MentionPickerCommand) -> Bool = { _ in false }
    var onSubmit: () -> Void
    var onCycleReasoning: () -> Void
    var onControlKey: (ComposerControlKey) -> Bool = { _ in false }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
        textView.onMentionCommand = onMentionCommand
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
        context.coordinator.onSelectionChange = onSelectionChange
        if textView.string != text {
            textView.string = text
        }
        let safeSelectedRange = Self.clampedSelectedRange(selectedRange, textLength: (textView.string as NSString).length)
        if textView.selectedRange() != safeSelectedRange {
            textView.setSelectedRange(safeSelectedRange)
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
        textView.onMentionCommand = onMentionCommand
        textView.onControlKey = onControlKey
        textView.placeholder = placeholder
        textView.font = .systemFont(ofSize: fontSize)
        textView.isEditable = isEditable

        if let pendingTextReplacement,
           context.coordinator.appliedReplacementID != pendingTextReplacement.id {
            let wasApplied = context.coordinator.apply(pendingTextReplacement, to: textView)
            onTextReplacementApplied(pendingTextReplacement.id, wasApplied)
            textView.needsDisplay = true
            return
        }

        if textView.string != text {
            textView.string = text
        }
        textView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange, onSelectionChange: onSelectionChange)
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
        var onSelectionChange: (NSRange) -> Void
        var appliedReplacementID: UUID?
        var lastFocusRequest = 0

        init(
            text: Binding<String>,
            selectedRange: Binding<NSRange>,
            onSelectionChange: @escaping (NSRange) -> Void
        ) {
            _text = text
            _selectedRange = selectedRange
            self.onSelectionChange = onSelectionChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            selectedRange = textView.selectedRange()
            onSelectionChange(textView.selectedRange())
            textView.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            selectedRange = textView.selectedRange()
            onSelectionChange(textView.selectedRange())
        }

        func apply(_ replacement: MentionTextReplacement, to textView: NSTextView) -> Bool {
            let utf16Count = textView.string.utf16.count
            guard replacement.range.location >= 0,
                  replacement.range.length >= 0,
                  replacement.range.location + replacement.range.length <= utf16Count
            else { return false }

            guard textView.shouldChangeText(in: replacement.range, replacementString: replacement.text) else {
                return false
            }
            textView.textStorage?.replaceCharacters(in: replacement.range, with: replacement.text)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(
                location: replacement.range.location + (replacement.text as NSString).length,
                length: 0
            ))
            appliedReplacementID = replacement.id
            return true
        }
    }
}

final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCycleReasoning: (() -> Void)?
    var onMentionCommand: ((MentionPickerCommand) -> Bool)?
    var onControlKey: ((ComposerControlKey) -> Bool)?
    var placeholder = ""

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if let command = MentionPickerCommand(event: event),
           onMentionCommand?(command) == true {
            return
        }

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

enum MentionPickerCommand {
    case moveUp
    case moveDown
    case insertHighlighted
    case dismiss

    init?(event: NSEvent) {
        var modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        modifiers.remove(.capsLock)
        modifiers.remove(.numericPad)
        modifiers.remove(.function)
        guard modifiers.isEmpty else { return nil }

        switch event.keyCode {
        case 126:
            self = .moveUp
        case 125:
            self = .moveDown
        case 36, 48, 76:
            self = .insertHighlighted
        case 53:
            self = .dismiss
        default:
            return nil
        }
    }
}

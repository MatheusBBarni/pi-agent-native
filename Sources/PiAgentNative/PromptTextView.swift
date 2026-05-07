import SwiftUI
import AppKit

struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var fontSize = 15.0
    var isEditable = true
    var pendingTextReplacement: MentionTextReplacement?
    var onTextReplacementApplied: (UUID) -> Void = { _ in }
    var onSelectionChange: (NSRange) -> Void = { _ in }
    var onMentionCommand: (MentionPickerCommand) -> Bool = { _ in false }
    var onSubmit: () -> Void
    var onCycleReasoning: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
        textView.onMentionCommand = onMentionCommand
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
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
        textView.onMentionCommand = onMentionCommand
        textView.placeholder = placeholder
        textView.font = .systemFont(ofSize: fontSize)
        textView.isEditable = isEditable

        if let pendingTextReplacement,
           context.coordinator.appliedReplacementID != pendingTextReplacement.id {
            context.coordinator.apply(pendingTextReplacement, to: textView)
            onTextReplacementApplied(pendingTextReplacement.id)
            textView.needsDisplay = true
            return
        }

        if textView.string != text {
            textView.string = text
        }
        textView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSelectionChange: onSelectionChange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSelectionChange: (NSRange) -> Void
        var appliedReplacementID: UUID?

        init(text: Binding<String>, onSelectionChange: @escaping (NSRange) -> Void) {
            _text = text
            self.onSelectionChange = onSelectionChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            onSelectionChange(textView.selectedRange())
            textView.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            onSelectionChange(textView.selectedRange())
        }

        func apply(_ replacement: MentionTextReplacement, to textView: NSTextView) {
            let utf16Count = textView.string.utf16.count
            guard replacement.range.location >= 0,
                  replacement.range.length >= 0,
                  replacement.range.location + replacement.range.length <= utf16Count
            else { return }

            appliedReplacementID = replacement.id
            guard textView.shouldChangeText(in: replacement.range, replacementString: replacement.text) else {
                return
            }
            textView.textStorage?.replaceCharacters(in: replacement.range, with: replacement.text)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(
                location: replacement.range.location + (replacement.text as NSString).length,
                length: 0
            ))
        }
    }
}

final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCycleReasoning: (() -> Void)?
    var onMentionCommand: ((MentionPickerCommand) -> Bool)?
    var placeholder = ""

    override func keyDown(with event: NSEvent) {
        if let command = MentionPickerCommand(event: event),
           onMentionCommand?(command) == true {
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) {
                insertNewlineIgnoringFieldEditor(self)
            } else {
                onSubmit?()
            }
            return
        }

        if event.keyCode == 48, event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) {
            onCycleReasoning?()
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

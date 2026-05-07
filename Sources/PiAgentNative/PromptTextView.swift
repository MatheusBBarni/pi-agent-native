import SwiftUI
import AppKit

struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    var focusRequest: Int
    var placeholder: String
    var fontSize = 15.0
    var isEditable = true
    var onSubmit: () -> Void
    var onCycleReasoning: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
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
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
        textView.onSubmit = onSubmit
        textView.onCycleReasoning = onCycleReasoning
        textView.placeholder = placeholder
        textView.font = .systemFont(ofSize: fontSize)
        textView.isEditable = isEditable
        textView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var lastFocusRequest = 0

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            textView.needsDisplay = true
        }
    }
}

final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCycleReasoning: (() -> Void)?
    var placeholder = ""

    override func keyDown(with event: NSEvent) {
        let modifiers = event.normalizedKeybindingModifiers

        if event.keyCode == 36 || event.keyCode == 76 {
            if modifiers.isEmpty || modifiers == .command {
                onSubmit?()
            } else if modifiers == .shift {
                insertNewlineIgnoringFieldEditor(self)
            } else {
                super.keyDown(with: event)
            }
            return
        }

        if event.keyCode == 48, modifiers == .shift {
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

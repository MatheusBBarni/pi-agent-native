import Foundation

@MainActor
final class ConversationStore: ObservableObject {
    @Published var messages: [ChatMessage]
    var currentAssistantID: UUID?

    init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    func clear() {
        messages.removeAll()
        currentAssistantID = nil
    }

    func beginAssistantIfNeeded() {
        if let currentAssistantID, messages.contains(where: { $0.id == currentAssistantID }) {
            return
        }

        let message = ChatMessage(role: .assistant, title: "π", text: "", isStreaming: true)
        currentAssistantID = message.id
        messages.append(message)
    }

    func appendAssistantText(_ text: String) {
        beginAssistantIfNeeded()
        guard let index = currentAssistantIndex else { return }
        messages[index].appendText(text)
        messages[index].isStreaming = true
    }

    func appendAssistantThinking(_ text: String) {
        beginAssistantIfNeeded()
        guard let index = currentAssistantIndex else { return }
        messages[index].appendThinking(text)
        messages[index].isStreaming = true
    }

    func appendAssistantToolCall(_ call: ToolCallPresentation) {
        beginAssistantIfNeeded()
        guard let index = currentAssistantIndex else { return }
        if let blockIndex = messages[index].contentBlocks.firstIndex(where: { block in
            if case .toolCall(let existing) = block {
                return existing.toolCallId == call.toolCallId
            }
            return false
        }) {
            messages[index].contentBlocks[blockIndex] = .toolCall(call)
            return
        }
        messages[index].appendToolCall(call)
        messages[index].isStreaming = true
    }

    func appendAssistantToolResult(_ result: ToolResultPresentation) {
        beginAssistantIfNeeded()
        guard let index = currentAssistantIndex else { return }
        messages[index].appendToolResult(result)
        messages[index].isStreaming = true
    }

    func replaceCurrentAssistantText(_ text: String, blocks: [MessageContentBlock]? = nil) {
        beginAssistantIfNeeded()
        guard let index = currentAssistantIndex else { return }
        messages[index].replaceText(text, blocks: blocks)
    }

    func finishCurrentAssistant() {
        guard let index = currentAssistantIndex else { return }
        messages[index].isStreaming = false
        if messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           messages[index].contentBlocks.filter({ !$0.isEmpty }).isEmpty {
            messages[index].replaceText("Finished without text output.")
        }
        currentAssistantID = nil
    }

    var firstPromptTitle: String? {
        messages
            .first { $0.role == .user && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .text
            .truncatedSessionTitle()
    }

    private var currentAssistantIndex: Int? {
        guard let currentAssistantID else { return nil }
        return messages.firstIndex { $0.id == currentAssistantID }
    }
}

import Foundation

enum MessageContentBlock: Equatable {
    case text(String)
    case thinking(String)
    case toolCall(ToolCallPresentation)
    case toolResult(ToolResultPresentation)
    case image(ImageAttachment)

    var plainText: String {
        switch self {
        case .text(let text), .thinking(let text):
            return text
        case .toolCall(let call):
            return "Tool: \(call.name)"
        case .toolResult(let result):
            return result.text
        case .image(let image):
            return image.altText ?? image.url.lastPathComponent
        }
    }

    var isEmpty: Bool {
        plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ToolCallPresentation: Equatable {
    var toolCallId: String
    var name: String
    var argumentsSummary: String
    var status: ToolActivityStatus
}

struct ToolResultPresentation: Equatable {
    var toolCallId: String
    var text: String
    var isError: Bool
}

struct ImageAttachment: Equatable {
    var url: URL
    var altText: String?
}

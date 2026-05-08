import Foundation

enum PiRPCValue {
    static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value { return "\(value)" }
        return nil
    }

    static func compactJSON(_ object: Any) -> String {
        guard
            JSONSerialization.isValidJSONObject(object),
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return "\(object)"
        }
        return text
    }

    static func text(from content: Any) -> String {
        contentBlocks(from: content).map(\.plainText).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    static func resultText(from result: [String: Any]) -> String {
        guard let content = result["content"] as? [[String: Any]] else {
            return compactJSON(result)
        }
        return content.compactMap { string($0["text"]) }.joined(separator: "\n")
    }

    static func contentBlocks(from content: Any) -> [MessageContentBlock] {
        if let text = content as? String {
            return text.isEmpty ? [] : [.text(text)]
        }

        guard let blocks = content as? [[String: Any]] else {
            return []
        }

        return blocks.compactMap { block in
            if let text = string(block["text"]), !text.isEmpty {
                return .text(text)
            }
            if let text = string(block["thinking"]), !text.isEmpty {
                return .thinking(text)
            }

            let type = string(block["type"]) ?? ""
            switch type {
            case "toolCall", "tool_call":
                return .toolCall(ToolCallPresentation(
                    toolCallId: string(block["id"]) ?? string(block["toolCallId"]) ?? UUID().uuidString,
                    name: string(block["name"]) ?? "tool",
                    argumentsSummary: compactJSON(block["args"] ?? block["arguments"] ?? [:]),
                    status: .succeeded
                ))
            case "toolResult", "tool_result":
                return .toolResult(ToolResultPresentation(
                    toolCallId: string(block["toolCallId"]) ?? string(block["id"]) ?? "",
                    text: string(block["text"]) ?? compactJSON(block),
                    isError: block["isError"] as? Bool ?? false
                ))
            case "image":
                guard let urlText = string(block["url"]), let url = URL(string: urlText) else { return nil }
                return .image(ImageAttachment(url: url, altText: string(block["alt"]) ?? string(block["altText"])))
            default:
                return nil
            }
        }
    }
}

struct PiRPCResponse {
    var id: String?
    var command: String
    var success: Bool
    var data: [String: Any]?
    var error: String?
    var raw: [String: Any]

    init(payload: [String: Any]) {
        id = PiRPCValue.string(payload["id"])
        command = PiRPCValue.string(payload["command"]) ?? "response"
        success = payload["success"] as? Bool ?? false
        data = payload["data"] as? [String: Any]
        error = PiRPCValue.string(payload["error"])
        raw = payload
    }
}

struct PiRPCMessage {
    var role: String
    var content: Any

    init?(payload: [String: Any]) {
        guard let role = PiRPCValue.string(payload["role"]) else { return nil }
        self.role = role
        content = payload["content"] ?? ""
    }

    var contentBlocks: [MessageContentBlock] {
        PiRPCValue.contentBlocks(from: content)
    }

    var text: String {
        PiRPCValue.text(from: content)
    }
}

struct PiRPCMessageUpdate {
    enum Delta {
        case text(String)
        case thinking(String)
        case toolCallStart(PiRPCToolCall)
        case toolCallEnd(PiRPCToolCall)
        case error(String)
        case unknown(type: String, payload: [String: Any])
    }

    var delta: Delta

    init(deltaPayload: [String: Any]) {
        let type = PiRPCValue.string(deltaPayload["type"]) ?? "update"
        switch type {
        case "text_delta":
            delta = .text(PiRPCValue.string(deltaPayload["delta"]) ?? "")
        case "thinking_delta":
            delta = .thinking(PiRPCValue.string(deltaPayload["delta"]) ?? "")
        case "toolcall_start":
            delta = .toolCallStart(PiRPCToolCall(payload: deltaPayload))
        case "toolcall_end":
            if let toolCall = deltaPayload["toolCall"] as? [String: Any] {
                delta = .toolCallEnd(PiRPCToolCall(payload: toolCall))
            } else {
                delta = .toolCallEnd(PiRPCToolCall(payload: deltaPayload))
            }
        case "error":
            delta = .error(PiRPCValue.string(deltaPayload["error"]) ?? "unknown error")
        default:
            delta = .unknown(type: type, payload: deltaPayload)
        }
    }
}

struct PiRPCToolCall {
    var id: String
    var name: String
    var argumentsSummary: String

    init(payload: [String: Any]) {
        id = PiRPCValue.string(payload["toolCallId"]) ?? PiRPCValue.string(payload["id"]) ?? UUID().uuidString
        name = PiRPCValue.string(payload["toolName"]) ?? PiRPCValue.string(payload["name"]) ?? "tool"
        if let command = (payload["args"] as? [String: Any])?["command"] {
            argumentsSummary = PiRPCValue.string(command) ?? ""
        } else {
            argumentsSummary = PiRPCValue.compactJSON(payload["args"] ?? payload["arguments"] ?? [:])
        }
    }
}

struct PiRPCToolExecution {
    var toolCallId: String
    var toolName: String
    var args: [String: Any]?
    var partialResult: [String: Any]?
    var result: [String: Any]?
    var isError: Bool

    init(payload: [String: Any]) {
        toolCallId = PiRPCValue.string(payload["toolCallId"]) ?? ""
        toolName = PiRPCValue.string(payload["toolName"]) ?? "tool"
        args = payload["args"] as? [String: Any]
        partialResult = payload["partialResult"] as? [String: Any]
        result = payload["result"] as? [String: Any]
        isError = payload["isError"] as? Bool ?? false
    }

    var summary: String {
        PiRPCValue.string(args?["command"]) ?? PiRPCValue.compactJSON(args ?? [:])
    }

    var partialOutput: String {
        partialResult.map(PiRPCValue.resultText(from:)) ?? ""
    }

    var resultOutput: String {
        result.map(PiRPCValue.resultText(from:)) ?? ""
    }
}

struct PiRPCQueueUpdate: Equatable {
    var steering: [QueuedWorkEntry]
    var followUp: [QueuedWorkEntry]

    init(payload: [String: Any]) {
        steering = Self.entries(from: payload["steering"], kind: .steering)
        followUp = Self.entries(from: payload["followUp"], kind: .followUp)
    }

    var pendingMessageCount: Int {
        entries.count
    }

    var entries: [QueuedWorkEntry] {
        steering + followUp
    }

    private static func entries(from value: Any?, kind: QueuedWorkKind) -> [QueuedWorkEntry] {
        guard let values = value as? [Any] else { return [] }
        return values.compactMap { $0 as? String }.enumerated().map { offset, text in
            QueuedWorkEntry(kind: kind, text: text, position: offset)
        }
    }
}

struct PiExtensionUIRequest: Identifiable, Equatable {
    enum Method: String, Equatable {
        case select
        case confirm
        case input
        case editor
        case notify
        case setStatus
        case setWidget
        case setTitle
        case setEditorText = "set_editor_text"
        case unknown
    }

    struct Option: Identifiable, Equatable {
        var id: String
        var label: String
        var value: String
    }

    var id: String
    var method: Method
    var methodName: String
    var params: [String: Any]

    init(payload: [String: Any]) {
        id = PiRPCValue.string(payload["requestId"]) ??
            PiRPCValue.string(payload["id"]) ??
            UUID().uuidString
        methodName = PiRPCValue.string(payload["method"]) ?? "unknown"
        method = Method(rawValue: methodName) ?? .unknown
        params = payload["params"] as? [String: Any] ?? payload
    }

    static func == (lhs: PiExtensionUIRequest, rhs: PiExtensionUIRequest) -> Bool {
        lhs.id == rhs.id &&
            lhs.method == rhs.method &&
            lhs.methodName == rhs.methodName &&
            PiRPCValue.compactJSON(lhs.params) == PiRPCValue.compactJSON(rhs.params)
    }

    var title: String {
        PiRPCValue.string(params["title"]) ??
            PiRPCValue.string(params["label"]) ??
            methodName
    }

    var message: String {
        PiRPCValue.string(params["message"]) ??
            PiRPCValue.string(params["prompt"]) ??
            PiRPCValue.string(params["description"]) ??
            ""
    }

    var defaultValue: String {
        PiRPCValue.string(params["default"]) ??
            PiRPCValue.string(params["value"]) ??
            PiRPCValue.string(params["text"]) ??
            ""
    }

    var options: [Option] {
        guard let rawOptions = params["options"] as? [Any] else { return [] }
        return rawOptions.enumerated().compactMap { index, raw in
            if let option = raw as? [String: Any] {
                let value = PiRPCValue.string(option["value"]) ?? PiRPCValue.string(option["id"]) ?? "\(index)"
                let label = PiRPCValue.string(option["label"]) ?? PiRPCValue.string(option["title"]) ?? value
                return Option(id: value, label: label, value: value)
            }
            if let text = PiRPCValue.string(raw) {
                return Option(id: text, label: text, value: text)
            }
            return nil
        }
    }
}

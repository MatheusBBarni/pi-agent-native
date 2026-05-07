import Foundation

enum PiRPCEventReducerEffect: Equatable {
    case setStreaming(Bool)
    case setCompacting(Bool)
    case setPendingMessageCount(Int)
    case appendLog(title: String, detail: String)
    case refreshState
    case extensionUIRequest(PiExtensionUIRequest)
}

@MainActor
struct PiRPCEventReducer {
    func reduce(
        _ event: PiRPCEvent,
        conversation: ConversationStore,
        tools: ToolActivityStore
    ) -> [PiRPCEventReducerEffect] {
        switch event {
        case .response:
            return []

        case .agentStart:
            conversation.beginAssistantIfNeeded()
            return [.setStreaming(true)]

        case .agentEnd:
            conversation.finishCurrentAssistant()
            return [.setStreaming(false), .refreshState]

        case .messageStart(let message):
            guard message.role == "assistant" else { return [] }
            conversation.beginAssistantIfNeeded()
            return []

        case .messageUpdate(let update):
            return reduceMessageUpdate(update, conversation: conversation)

        case .messageEnd(let message):
            guard message.role == "assistant" else { return [] }
            let finalText = message.text
            if !finalText.isEmpty {
                conversation.replaceCurrentAssistantText(finalText, blocks: message.contentBlocks)
            }
            conversation.finishCurrentAssistant()
            return []

        case .toolExecutionStart(let event):
            let activity = ToolActivity(
                id: event.toolCallId.isEmpty ? UUID().uuidString : event.toolCallId,
                toolCallId: event.toolCallId,
                name: event.toolName,
                summary: event.summary,
                output: "",
                status: .running,
                isRunning: true,
                isError: false
            )
            tools.upsert(activity)
            conversation.appendAssistantToolCall(ToolCallPresentation(
                toolCallId: activity.toolCallId,
                name: activity.name,
                argumentsSummary: activity.summary,
                status: .running
            ))
            return []

        case .toolExecutionUpdate(let event):
            guard !event.toolCallId.isEmpty else { return [] }
            let output = event.partialOutput
            tools.update(id: event.toolCallId) { tool in
                tool.output = output
                tool.stdout = output
                tool.updateStatus(.running)
            }
            return []

        case .toolExecutionEnd(let event):
            guard !event.toolCallId.isEmpty else { return [] }
            let output = event.resultOutput
            let status: ToolActivityStatus = event.isError ? .failed : .succeeded
            tools.update(id: event.toolCallId) { tool in
                tool.output = output
                tool.result = output
                tool.updateStatus(status)
            }
            if !output.isEmpty {
                conversation.appendAssistantToolResult(ToolResultPresentation(
                    toolCallId: event.toolCallId,
                    text: output,
                    isError: event.isError
                ))
            }
            return []

        case .queueUpdate(let event):
            return [.setPendingMessageCount(event.pendingMessageCount)]

        case .compactionStart:
            return [
                .setCompacting(true),
                .appendLog(title: "compaction", detail: "started")
            ]

        case .compactionEnd(let errorMessage):
            return [
                .setCompacting(false),
                .appendLog(title: "compaction", detail: errorMessage ?? "completed")
            ]

        case .extensionUIRequest(let request):
            return [.extensionUIRequest(request)]

        case .extensionError(let error):
            return [.appendLog(title: "extension error", detail: error)]

        case .decodeFailure(let type, let payload, let reason):
            return [.appendLog(
                title: type.map { "\($0) decode failed" } ?? "rpc decode failed",
                detail: "\(reason): \(PiRPCValue.compactJSON(payload))"
            )]

        case .unknown(let type, let payload):
            return [.appendLog(title: type, detail: PiRPCValue.compactJSON(payload))]
        }
    }

    private func reduceMessageUpdate(
        _ update: PiRPCMessageUpdate,
        conversation: ConversationStore
    ) -> [PiRPCEventReducerEffect] {
        switch update.delta {
        case .text(let delta):
            conversation.appendAssistantText(delta)
            return []
        case .thinking(let delta):
            conversation.appendAssistantThinking(delta)
            return []
        case .toolCallStart(let toolCall):
            conversation.appendAssistantToolCall(ToolCallPresentation(
                toolCallId: toolCall.id,
                name: toolCall.name,
                argumentsSummary: toolCall.argumentsSummary,
                status: .running
            ))
            return [.appendLog(title: "tool call", detail: toolCall.name)]
        case .toolCallEnd(let toolCall):
            return [.appendLog(title: "tool call", detail: toolCall.name)]
        case .error(let error):
            conversation.appendAssistantText("\n\nError: \(error)")
            return []
        case .unknown:
            return []
        }
    }
}

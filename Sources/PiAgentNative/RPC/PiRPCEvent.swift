import Foundation

enum PiRPCEvent {
    case response(PiRPCResponse)
    case agentStart([String: Any])
    case agentEnd([String: Any])
    case messageStart(PiRPCMessage)
    case messageUpdate(PiRPCMessageUpdate)
    case messageEnd(PiRPCMessage)
    case toolExecutionStart(PiRPCToolExecution)
    case toolExecutionUpdate(PiRPCToolExecution)
    case toolExecutionEnd(PiRPCToolExecution)
    case queueUpdate(PiRPCQueueUpdate)
    case compactionStart([String: Any])
    case compactionEnd(errorMessage: String?)
    case extensionUIRequest(PiExtensionUIRequest)
    case extensionError(String)
    case decodeFailure(type: String?, payload: [String: Any], reason: String)
    case unknown(type: String, payload: [String: Any])

    static func decode(_ payload: [String: Any]) -> PiRPCEvent {
        guard let type = PiRPCValue.string(payload["type"]) else {
            return .decodeFailure(type: nil, payload: payload, reason: "Missing RPC event type")
        }

        switch type {
        case "response":
            return .response(PiRPCResponse(payload: payload))
        case "agent_start":
            return .agentStart(payload)
        case "agent_end":
            return .agentEnd(payload)
        case "message_start":
            guard let messagePayload = payload["message"] as? [String: Any],
                  let message = PiRPCMessage(payload: messagePayload)
            else {
                return .decodeFailure(type: type, payload: payload, reason: "Invalid message_start payload")
            }
            return .messageStart(message)
        case "message_update":
            guard let deltaPayload = payload["assistantMessageEvent"] as? [String: Any] else {
                return .decodeFailure(type: type, payload: payload, reason: "Invalid message_update payload")
            }
            return .messageUpdate(PiRPCMessageUpdate(deltaPayload: deltaPayload))
        case "message_end":
            guard let messagePayload = payload["message"] as? [String: Any],
                  let message = PiRPCMessage(payload: messagePayload)
            else {
                return .decodeFailure(type: type, payload: payload, reason: "Invalid message_end payload")
            }
            return .messageEnd(message)
        case "tool_execution_start":
            return .toolExecutionStart(PiRPCToolExecution(payload: payload))
        case "tool_execution_update":
            return .toolExecutionUpdate(PiRPCToolExecution(payload: payload))
        case "tool_execution_end":
            return .toolExecutionEnd(PiRPCToolExecution(payload: payload))
        case "queue_update":
            return .queueUpdate(PiRPCQueueUpdate(payload: payload))
        case "compaction_start":
            return .compactionStart(payload)
        case "compaction_end":
            return .compactionEnd(errorMessage: PiRPCValue.string(payload["errorMessage"]))
        case "extension_ui_request":
            return .extensionUIRequest(PiExtensionUIRequest(payload: payload))
        case "extension_error":
            return .extensionError(PiRPCValue.string(payload["error"]) ?? "unknown error")
        default:
            return .unknown(type: type, payload: payload)
        }
    }
}

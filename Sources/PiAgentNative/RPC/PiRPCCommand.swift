import Foundation

struct PiRPCCommand {
    var id: String
    var type: String
    var payload: [String: Any]

    init(id: String = UUID().uuidString, type: String, payload: [String: Any] = [:]) {
        self.id = id
        self.type = type
        self.payload = payload
    }

    var dictionary: [String: Any] {
        var object = payload
        object["id"] = id
        object["type"] = type
        return object
    }
}

extension PiRPCCommand {
    static func getState(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "get_state")
    }

    static func getAvailableModels(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "get_available_models")
    }

    static func getCommands(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "get_commands")
    }

    static func getSessionStats(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "get_session_stats")
    }

    static func getMessages(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "get_messages")
    }

    static func newSession(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "new_session")
    }

    static func switchSession(sessionPath: String, id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "switch_session", payload: ["sessionPath": sessionPath])
    }

    static func prompt(_ message: String, id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "prompt", payload: ["message": message])
    }

    static func abort(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "abort")
    }

    static func setModel(provider: String, modelId: String, id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "set_model", payload: ["provider": provider, "modelId": modelId])
    }

    static func setThinkingLevel(_ level: String, id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "set_thinking_level", payload: ["level": level.lowercased()])
    }

    static func cycleThinkingLevel(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "cycle_thinking_level")
    }

    static func steer(_ message: String, id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "steer", payload: ["message": message])
    }

    static func followUp(_ message: String, id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "follow_up", payload: ["message": message])
    }

    static func compact(id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "compact")
    }

    static func bash(_ command: String, id: String = UUID().uuidString) -> PiRPCCommand {
        PiRPCCommand(id: id, type: "bash", payload: ["command": command])
    }

    static func extensionUIResponse(
        requestID: String,
        result: Any?,
        error: String? = nil,
        id: String = UUID().uuidString
    ) -> PiRPCCommand {
        var payload: [String: Any] = ["requestId": requestID]
        if let result {
            payload["result"] = result
        }
        if let error {
            payload["error"] = error
        }
        return PiRPCCommand(id: id, type: "extension_ui_response", payload: payload)
    }
}

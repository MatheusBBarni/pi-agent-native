import Foundation

enum ExtensionUIResponse {
    case command(PiRPCCommand)
    case pendingDialog
}

@MainActor
final class ExtensionUIRouter: ObservableObject {
    @Published var activeRequest: PiExtensionUIRequest?
    @Published var statusText = ""
    @Published var widgetText = ""
    @Published var titleOverride = ""
    @Published var editorText = ""
    @Published var notifications: [String] = []

    func route(_ request: PiExtensionUIRequest) -> ExtensionUIResponse {
        switch request.method {
        case .notify:
            let message = request.message.isEmpty ? request.title : request.message
            notifications.insert(message, at: 0)
            return .command(.extensionUIResponse(requestID: request.id, result: ["ok": true]))
        case .setStatus:
            statusText = request.message.isEmpty ? request.defaultValue : request.message
            return .command(.extensionUIResponse(requestID: request.id, result: ["ok": true]))
        case .setWidget:
            widgetText = request.message.isEmpty ? request.defaultValue : request.message
            return .command(.extensionUIResponse(requestID: request.id, result: ["ok": true]))
        case .setTitle:
            titleOverride = request.defaultValue.isEmpty ? request.title : request.defaultValue
            return .command(.extensionUIResponse(requestID: request.id, result: ["ok": true]))
        case .setEditorText:
            editorText = request.defaultValue
            return .command(.extensionUIResponse(requestID: request.id, result: ["ok": true]))
        case .select, .confirm, .input, .editor, .unknown:
            activeRequest = request
            return .pendingDialog
        }
    }

    func resolveActiveRequest(with result: Any?) -> PiRPCCommand? {
        guard let activeRequest else { return nil }
        self.activeRequest = nil
        return .extensionUIResponse(requestID: activeRequest.id, result: result ?? NSNull())
    }

    func rejectActiveRequest(message: String = "cancelled") -> PiRPCCommand? {
        guard let activeRequest else { return nil }
        self.activeRequest = nil
        return .extensionUIResponse(requestID: activeRequest.id, result: nil, error: message)
    }
}

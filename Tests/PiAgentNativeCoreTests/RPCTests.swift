import Foundation
import XCTest
@testable import PiAgentNativeCore

final class JSONLTransportTests: XCTestCase {
    func testConsumesFragmentedStdoutRecords() throws {
        let transport = JSONLTransport()

        XCTAssertTrue(transport.consume(Data(#"{"type":"agent_"#.utf8)).isEmpty)
        var secondFragment = Data(#"start"}"#.utf8)
        secondFragment.append(0x0a)
        let records = transport.consume(secondFragment)

        XCTAssertEqual(records.count, 1)
        let payload = try XCTUnwrap(records.first?.get())
        XCTAssertEqual(PiRPCValue.string(payload["type"]), "agent_start")
    }

    func testToleratesCRLFAndReportsNonJSONOutput() throws {
        let transport = JSONLTransport()
        var data = Data(#"{"type":"queue_update","steering":[1],"followUp":[]}"#.utf8)
        data.append(0x0d)
        data.append(0x0a)
        data.append(contentsOf: Data("hello\n".utf8))
        let records = transport.consume(data)

        XCTAssertEqual(records.count, 2)
        let payload = try XCTUnwrap(records[0].get())
        XCTAssertEqual(PiRPCValue.string(payload["type"]), "queue_update")

        switch records[1] {
        case .success:
            XCTFail("Expected non-JSON output to be reported as a transport error")
        case .failure(let error):
            XCTAssertEqual(error, .nonJSONOutput("hello"))
        }
    }

    func testEncodesStrictLFJSONL() throws {
        let transport = JSONLTransport()
        let data = try transport.encode(["id": "1", "type": "get_state"])

        XCTAssertEqual(data.last, 0x0a)
        XCTAssertFalse(String(data: data.dropLast(), encoding: .utf8)?.contains("\n") ?? true)
    }
}

@MainActor
final class PiRPCEventReducerTests: XCTestCase {
    func testReducesStreamingTextAndThinkingDeltasIntoStructuredBlocks() {
        let conversation = ConversationStore()
        let tools = ToolActivityStore()
        let reducer = PiRPCEventReducer()

        _ = reducer.reduce(.agentStart([:]), conversation: conversation, tools: tools)
        _ = reducer.reduce(.messageUpdate(PiRPCMessageUpdate(deltaPayload: [
            "type": "thinking_delta",
            "delta": "plan"
        ])), conversation: conversation, tools: tools)
        _ = reducer.reduce(.messageUpdate(PiRPCMessageUpdate(deltaPayload: [
            "type": "text_delta",
            "delta": "answer"
        ])), conversation: conversation, tools: tools)

        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages[0].thinking, "plan")
        XCTAssertEqual(conversation.messages[0].text, "answer")
        XCTAssertEqual(conversation.messages[0].contentBlocks, [.thinking("plan"), .text("answer")])
    }

    func testCorrelatesToolStartUpdateAndEndByToolCallID() {
        let conversation = ConversationStore()
        let tools = ToolActivityStore()
        let reducer = PiRPCEventReducer()

        _ = reducer.reduce(.toolExecutionStart(PiRPCToolExecution(payload: [
            "toolCallId": "tool-1",
            "toolName": "bash",
            "args": ["command": "swift test"]
        ])), conversation: conversation, tools: tools)
        _ = reducer.reduce(.toolExecutionUpdate(PiRPCToolExecution(payload: [
            "toolCallId": "tool-1",
            "partialResult": ["content": [["text": "running"]]]
        ])), conversation: conversation, tools: tools)
        let effects = reducer.reduce(.toolExecutionEnd(PiRPCToolExecution(payload: [
            "toolCallId": "tool-1",
            "result": ["content": [["text": "passed"]]],
            "isError": false
        ])), conversation: conversation, tools: tools)

        XCTAssertEqual(tools.tools.count, 1)
        XCTAssertEqual(tools.tools[0].id, "tool-1")
        XCTAssertEqual(tools.tools[0].status, .succeeded)
        XCTAssertEqual(tools.tools[0].output, "passed")
        XCTAssertTrue(conversation.messages[0].contentBlocks.contains(.toolResult(ToolResultPresentation(
            toolCallId: "tool-1",
            text: "passed",
            isError: false
        ))))
        XCTAssertEqual(effects, [.refreshRepositoryChanges])
    }

    func testLocalizedChatChromeDoesNotMutateAssistantOrToolPayloads() {
        let conversation = ConversationStore()
        let tools = ToolActivityStore()
        let reducer = PiRPCEventReducer()
        let assistantText = "Raw assistant output: /tmp/Projeto %@ não traduzir"
        let command = "printf 'Olá /tmp/raw path && $VALUE'"
        let toolOutput = "stdout: caminho=/tmp/Projeto Bruto\nstatus=%@"

        XCTAssertEqual(L10n(language: .portugueseBrazil).string("chat.tool_result.output"), "Saída da ferramenta")

        _ = reducer.reduce(.agentStart([:]), conversation: conversation, tools: tools)
        _ = reducer.reduce(.messageUpdate(PiRPCMessageUpdate(deltaPayload: [
            "type": "text_delta",
            "delta": assistantText
        ])), conversation: conversation, tools: tools)
        _ = reducer.reduce(.toolExecutionStart(PiRPCToolExecution(payload: [
            "toolCallId": "tool-raw",
            "toolName": "bash/raw-tool",
            "args": ["command": command]
        ])), conversation: conversation, tools: tools)
        _ = reducer.reduce(.toolExecutionEnd(PiRPCToolExecution(payload: [
            "toolCallId": "tool-raw",
            "result": ["content": [["text": toolOutput]]],
            "isError": false
        ])), conversation: conversation, tools: tools)

        XCTAssertEqual(conversation.messages[0].text, assistantText)
        XCTAssertTrue(conversation.messages[0].contentBlocks.contains(.text(assistantText)))
        XCTAssertTrue(conversation.messages[0].contentBlocks.contains(.toolCall(ToolCallPresentation(
            toolCallId: "tool-raw",
            name: "bash/raw-tool",
            argumentsSummary: command,
            status: .running
        ))))
        XCTAssertTrue(conversation.messages[0].contentBlocks.contains(.toolResult(ToolResultPresentation(
            toolCallId: "tool-raw",
            text: toolOutput,
            isError: false
        ))))
        XCTAssertEqual(tools.tools[0].name, "bash/raw-tool")
        XCTAssertEqual(tools.tools[0].summary, command)
        XCTAssertEqual(tools.tools[0].output, toolOutput)
    }

    func testEmitsQueueAndExtensionUIEffects() {
        let conversation = ConversationStore()
        let tools = ToolActivityStore()
        let reducer = PiRPCEventReducer()
        let queueUpdate = PiRPCQueueUpdate(payload: [
            "steering": ["Focus on failing tests", "Avoid unrelated refactors"],
            "followUp": ["Run swift test"]
        ])

        let queueEffects = reducer.reduce(.queueUpdate(queueUpdate), conversation: conversation, tools: tools)

        XCTAssertEqual(queueEffects, [.setQueuedWork(queueUpdate)])
        XCTAssertTrue(conversation.messages.isEmpty)
        XCTAssertTrue(tools.tools.isEmpty)

        let request = PiExtensionUIRequest(payload: [
            "id": "request-1",
            "method": "confirm",
            "params": ["message": "Continue?"]
        ])
        let extensionEffects = reducer.reduce(.extensionUIRequest(request), conversation: conversation, tools: tools)

        XCTAssertEqual(extensionEffects, [.extensionUIRequest(request)])
    }

    func testExtensionUIRequestContentRemainsVerbatimWithPortugueseControls() {
        let l10n = L10n(language: .portugueseBrazil)
        let request = PiExtensionUIRequest(payload: [
            "id": "request-raw",
            "method": "select",
            "params": [
                "title": "Pick raw option %@ /tmp/Projeto",
                "message": "Do not translate this RPC message: $VALUE",
                "default": "raw-default-%@",
                "options": [
                    ["label": "First raw option %@ /tmp/path", "value": "first-raw-value"],
                    "Literal raw option %@"
                ]
            ]
        ])

        XCTAssertEqual(l10n.string("extension_ui.cancel"), "Cancelar")
        XCTAssertEqual(l10n.string("extension_ui.selection"), "Seleção")
        XCTAssertEqual(request.title, "Pick raw option %@ /tmp/Projeto")
        XCTAssertEqual(request.message, "Do not translate this RPC message: $VALUE")
        XCTAssertEqual(request.defaultValue, "raw-default-%@")
        XCTAssertEqual(request.options, [
            PiExtensionUIRequest.Option(
                id: "first-raw-value",
                label: "First raw option %@ /tmp/path",
                value: "first-raw-value"
            ),
            PiExtensionUIRequest.Option(
                id: "Literal raw option %@",
                label: "Literal raw option %@",
                value: "Literal raw option %@"
            )
        ])
    }

    func testExtensionUICancelResponsePayloadRemainsProtocolCompatible() throws {
        let router = ExtensionUIRouter()
        let request = PiExtensionUIRequest(payload: [
            "id": "cancel-request",
            "method": "input",
            "params": [
                "title": "Raw input title",
                "message": "Raw input message"
            ]
        ])

        guard case .pendingDialog = router.route(request) else {
            return XCTFail("Expected input request to open a dialog")
        }

        let command = try XCTUnwrap(router.rejectActiveRequest())

        XCTAssertNil(router.activeRequest)
        XCTAssertEqual(command.type, "extension_ui_response")
        XCTAssertEqual(command.payload["requestId"] as? String, "cancel-request")
        XCTAssertEqual(command.payload["error"] as? String, "cancelled")
        XCTAssertNil(command.payload["result"])
    }

    func testExtensionUIRoundTripPreservesRequestPayloadAndSubmittedResult() throws {
        let router = ExtensionUIRouter()
        let request = PiExtensionUIRequest(payload: [
            "id": "submit-request",
            "method": "select",
            "params": [
                "title": "Raw select title %@",
                "message": "Raw select message /tmp/Project",
                "default": "raw-default",
                "options": [
                    ["label": "Raw label A", "value": "raw-value-a"],
                    ["label": "Raw label B", "value": "raw-value-b"]
                ]
            ]
        ])

        guard case .pendingDialog = router.route(request) else {
            return XCTFail("Expected select request to open a dialog")
        }

        XCTAssertEqual(router.activeRequest, request)
        XCTAssertEqual(router.activeRequest?.title, "Raw select title %@")
        XCTAssertEqual(router.activeRequest?.message, "Raw select message /tmp/Project")
        XCTAssertEqual(router.activeRequest?.defaultValue, "raw-default")
        XCTAssertEqual(router.activeRequest?.options.map(\.label), ["Raw label A", "Raw label B"])

        let command = try XCTUnwrap(router.resolveActiveRequest(with: "raw-value-b"))

        XCTAssertNil(router.activeRequest)
        XCTAssertEqual(command.type, "extension_ui_response")
        XCTAssertEqual(command.payload["requestId"] as? String, "submit-request")
        XCTAssertEqual(command.payload["result"] as? String, "raw-value-b")
        XCTAssertNil(command.payload["error"])
    }

    func testQueueUpdateBuildsTypedVisibleEntriesAndIgnoresInvalidValues() throws {
        let event = PiRPCEvent.decode([
            "type": "queue_update",
            "steering": [
                "  Focus   on the failing test first  ",
                42,
                "Do not refactor unrelated files"
            ],
            "followUp": [
                ["message": "not valid"],
                "\nRun  swift   test\n"
            ]
        ])

        guard case .queueUpdate(let update) = event else {
            return XCTFail("Expected queue_update to decode")
        }

        XCTAssertEqual(update.pendingMessageCount, 3)
        XCTAssertEqual(update.entries.map(\.id), ["steering-0", "steering-1", "followUp-0"])
        XCTAssertEqual(update.entries.map(\.title), ["Steering", "Steering", "Follow-up"])
        XCTAssertEqual(update.entries.map(\.position), [0, 1, 0])
        XCTAssertEqual(update.entries[0].text, "  Focus   on the failing test first  ")
        XCTAssertEqual(update.entries[0].summary, "Focus on the failing test first")
        XCTAssertEqual(update.entries[2].summary, "Run swift test")
    }

    func testQueueUpdateTreatsMissingOrNonArrayQueuesAsEmpty() {
        let update = PiRPCQueueUpdate(payload: [
            "steering": "not an array",
            "followUp": ["   "]
        ])

        XCTAssertEqual(update.pendingMessageCount, 1)
        XCTAssertEqual(update.entries, [
            QueuedWorkEntry(kind: .followUp, text: "   ", position: 0)
        ])
        XCTAssertEqual(update.entries[0].summary, "Empty queued message")
    }

    func testQueueEntryCanProvideTruncatedPresentationSummary() {
        let entry = QueuedWorkEntry(
            kind: .steering,
            text: "This queued message is intentionally long",
            position: 0
        )

        let truncated = entry.summary(maxLength: 12)
        XCTAssertEqual(truncated, "This queu...")
        XCTAssertLessThanOrEqual(truncated.count, 12)
        XCTAssertEqual(entry.summary(maxLength: 3), entry.summary)
    }
}

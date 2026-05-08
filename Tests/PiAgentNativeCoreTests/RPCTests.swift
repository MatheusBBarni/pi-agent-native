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

    func testEmitsQueueAndExtensionUIEffects() {
        let conversation = ConversationStore()
        let tools = ToolActivityStore()
        let reducer = PiRPCEventReducer()

        let queueEffects = reducer.reduce(.queueUpdate(PiRPCQueueUpdate(payload: [
            "steering": [1, 2],
            "followUp": [1]
        ])), conversation: conversation, tools: tools)

        XCTAssertEqual(queueEffects, [.setPendingMessageCount(3)])

        let request = PiExtensionUIRequest(payload: [
            "id": "request-1",
            "method": "confirm",
            "params": ["message": "Continue?"]
        ])
        let extensionEffects = reducer.reduce(.extensionUIRequest(request), conversation: conversation, tools: tools)

        XCTAssertEqual(extensionEffects, [.extensionUIRequest(request)])
    }
}

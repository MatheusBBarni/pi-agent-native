import Foundation

@MainActor
final class ProcessLogStore: ObservableObject {
    @Published var eventLog: [EventLog]
    private let limit: Int

    init(eventLog: [EventLog] = [], limit: Int = 80) {
        self.eventLog = eventLog
        self.limit = limit
    }

    func append(title: String, detail: String) {
        guard !detail.isEmpty else { return }
        eventLog.insert(EventLog(title: title, detail: detail), at: 0)
        if eventLog.count > limit {
            eventLog.removeLast(eventLog.count - limit)
        }
    }
}

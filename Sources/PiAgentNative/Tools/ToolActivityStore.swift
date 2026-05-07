import Foundation

@MainActor
final class ToolActivityStore: ObservableObject {
    @Published var tools: [ToolActivity]

    init(tools: [ToolActivity] = []) {
        self.tools = tools
    }

    func clear() {
        tools.removeAll()
    }

    func upsert(_ activity: ToolActivity) {
        if let index = tools.firstIndex(where: { $0.id == activity.id }) {
            tools[index] = activity
        } else {
            tools.insert(activity, at: 0)
        }
    }

    func update(id: String, _ mutate: (inout ToolActivity) -> Void) {
        guard let index = tools.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tools[index])
    }

    var hasRunningTool: Bool {
        tools.contains { $0.isRunning }
    }
}

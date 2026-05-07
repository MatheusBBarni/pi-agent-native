import Foundation

@MainActor
final class NativeSessionIndexStore: ObservableObject {
    @Published var sessions: [StoredSession]
    @Published var selectedSessionID: StoredSession.ID?

    init(sessions: [StoredSession] = [], selectedSessionID: StoredSession.ID? = nil) {
        self.sessions = sessions
        self.selectedSessionID = selectedSessionID
    }

    var selectedSession: StoredSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    func sessionsForProject(_ project: ProjectItem, runningSessionID: StoredSession.ID?, isRunning: (StoredSession) -> Bool) -> [StoredSession] {
        sessions
            .filter { $0.projectPath == project.path }
            .sorted { lhs, rhs in
                let lhsIsRunning = lhs.id == runningSessionID && isRunning(lhs)
                let rhsIsRunning = rhs.id == runningSessionID && isRunning(rhs)
                if lhsIsRunning != rhsIsRunning {
                    return lhsIsRunning
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func lastOpenedSession(for project: ProjectItem) -> StoredSession? {
        Self.lastOpenedSession(in: sessions, projectPath: project.path)
    }

    static func lastOpenedSession(in sessions: [StoredSession], projectPath: String) -> StoredSession? {
        sessions
            .filter { $0.projectPath == projectPath && !$0.sessionFile.isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func touch(_ session: StoredSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index].updatedAt = Date()
    }

    func updateSelectedSnapshot(title: String, status: String) {
        guard let selectedSessionID,
              let index = sessions.firstIndex(where: { $0.id == selectedSessionID })
        else { return }
        sessions[index].title = title
        sessions[index].status = status
        sessions[index].updatedAt = Date()
    }

    func upsert(sessionID: String, project: ProjectItem, title: String, status: String, sessionFile: String) {
        let session = StoredSession(
            id: sessionID,
            projectPath: project.path,
            projectName: project.name,
            title: title,
            status: status,
            sessionFile: sessionFile,
            updatedAt: Date()
        )
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        selectedSessionID = sessionID
    }
}

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
            .filter { $0.projectID == project.id }
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
        Self.lastOpenedSession(in: sessions, projectID: project.id, projectPath: project.path)
    }

    static func lastOpenedSession(in sessions: [StoredSession], projectPath: String) -> StoredSession? {
        lastOpenedSession(in: sessions, projectID: nil, projectPath: projectPath)
    }

    static func lastOpenedSession(in sessions: [StoredSession], projectID: String?, projectPath: String) -> StoredSession? {
        sessions
            .filter { session in
                if let projectID {
                    return session.projectID == projectID && !session.sessionFile.isEmpty
                }
                return session.projectPath == projectPath && !session.sessionFile.isEmpty
            }
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

    @discardableResult
    func removeSessions(forProjectID projectID: ProjectItem.ID) -> [StoredSession] {
        let removedSessions = sessions.filter { $0.projectID == projectID }
        guard !removedSessions.isEmpty else { return [] }

        let removedSessionIDs = Set(removedSessions.map(\.id))
        sessions.removeAll { $0.projectID == projectID }

        if let selectedSessionID, removedSessionIDs.contains(selectedSessionID) {
            self.selectedSessionID = nil
        }

        return removedSessions
    }

    @discardableResult
    func upsert(sessionID piSessionID: String, project: ProjectItem, title: String, status: String, sessionFile: String) -> StoredSession.ID {
        let localSessionID = sessions.first {
            $0.projectID == project.id && $0.piSessionID == piSessionID
        }?.id ?? UUID().uuidString
        let session = StoredSession(
            id: localSessionID,
            piSessionID: piSessionID,
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: title,
            status: status,
            sessionFile: sessionFile,
            updatedAt: Date()
        )
        if let index = sessions.firstIndex(where: { $0.id == localSessionID }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        selectedSessionID = localSessionID
        return localSessionID
    }
}

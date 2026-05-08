import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct AppPersistedState: Codable, Equatable {
    var projects: [ProjectItem] = []
    var sessions: [StoredSession] = []
    var selectedProjectID: String?
    var selectedSessionID: String?
}

enum SessionStore {
    private static let databaseFilename = "sessions.sqlite"

    static var databaseURLForTesting: URL?

    static var storeURL: URL {
        if let databaseURLForTesting {
            return databaseURLForTesting
        }

        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PiAgentNative", isDirectory: true)
        return directory.appendingPathComponent(databaseFilename)
    }

    static func load() -> AppPersistedState {
        guard let database = openDatabase(operation: "load") else {
            return AppPersistedState()
        }
        defer { sqlite3_close(database) }

        guard bootstrapSchema(in: database, operation: "load") else {
            return AppPersistedState()
        }

        return AppPersistedState(
            projects: loadProjects(from: database),
            sessions: loadSessions(from: database),
            selectedProjectID: loadSelectionValue("selected_project_id", from: database),
            selectedSessionID: loadSelectionValue("selected_session_id", from: database)
        )
    }

    static func save(_ state: AppPersistedState) {
        guard let database = openDatabase(operation: "save") else {
            return
        }
        defer { sqlite3_close(database) }

        guard bootstrapSchema(in: database, operation: "save") else {
            return
        }

        guard execute("BEGIN IMMEDIATE TRANSACTION;", in: database, operation: "save") else {
            return
        }

        guard replaceState(state, in: database) else {
            _ = execute("ROLLBACK;", in: database, operation: "save rollback")
            return
        }

        guard execute("COMMIT;", in: database, operation: "save commit") else {
            _ = execute("ROLLBACK;", in: database, operation: "save rollback")
            return
        }
    }

    private static func openDatabase(operation: String) -> OpaquePointer? {
        let url = storeURL

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            logFailure(operation: operation, url: url, message: "create directory failed: \(error)")
            return nil
        }

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &database, flags, nil)

        guard result == SQLITE_OK else {
            let message = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown SQLite open error"
            if let database {
                sqlite3_close(database)
            }
            logFailure(operation: operation, url: url, message: message)
            return nil
        }

        return database
    }

    private static func bootstrapSchema(in database: OpaquePointer, operation: String) -> Bool {
        let statements = [
            """
            PRAGMA foreign_keys = ON;
            """,
            """
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                path TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY NOT NULL,
                project_id TEXT NOT NULL,
                pi_session_id TEXT,
                title TEXT NOT NULL,
                status TEXT NOT NULL,
                session_file TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS app_selection (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT
            );
            """
        ]

        for statement in statements {
            guard execute(statement, in: database, operation: operation) else {
                return false
            }
        }

        return true
    }

    private static func execute(_ sql: String, in database: OpaquePointer, operation: String) -> Bool {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)

        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "unknown SQLite exec error"
            sqlite3_free(errorMessage)
            logFailure(operation: operation, url: storeURL, message: message)
            return false
        }

        return true
    }

    private static func replaceState(_ state: AppPersistedState, in database: OpaquePointer) -> Bool {
        let deduped = dedupeProjects(state.projects)

        guard execute("DELETE FROM app_selection;", in: database, operation: "save selection delete"),
              execute("DELETE FROM sessions;", in: database, operation: "save sessions delete"),
              execute("DELETE FROM projects;", in: database, operation: "save projects delete")
        else {
            return false
        }

        guard insertProjects(deduped.projects, in: database),
              insertSessions(state.sessions, projectIDMap: deduped.projectIDMap, projectsByID: deduped.projectsByID, in: database),
              insertSelection(state.selectedProjectID.flatMap { deduped.projectIDMap[$0] }, key: "selected_project_id", in: database),
              insertSelection(state.selectedSessionID, key: "selected_session_id", in: database)
        else {
            return false
        }

        return true
    }

    private static func dedupeProjects(_ projects: [ProjectItem]) -> (
        projects: [ProjectItem],
        projectIDMap: [String: String],
        projectsByID: [String: ProjectItem]
    ) {
        var canonicalPathToProjectID: [String: String] = [:]
        var projectIDMap: [String: String] = [:]
        var dedupedProjects: [ProjectItem] = []

        for project in projects {
            let canonicalPath = canonicalPath(project.path)

            if let existingProjectID = canonicalPathToProjectID[canonicalPath] {
                projectIDMap[project.id] = existingProjectID
                continue
            }

            var canonicalProject = project
            canonicalProject.path = canonicalPath
            canonicalPathToProjectID[canonicalPath] = canonicalProject.id
            projectIDMap[project.id] = canonicalProject.id
            dedupedProjects.append(canonicalProject)
        }

        let projectsByID = Dictionary(uniqueKeysWithValues: dedupedProjects.map { ($0.id, $0) })
        return (dedupedProjects, projectIDMap, projectsByID)
    }

    private static func insertProjects(_ projects: [ProjectItem], in database: OpaquePointer) -> Bool {
        let sql = """
        INSERT INTO projects (id, name, path, created_at, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
        """

        return withPreparedStatement(sql, in: database, operation: "save projects insert") { statement in
            for project in projects {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                bind(project.id, at: 1, in: statement)
                bind(project.name, at: 2, in: statement)
                bind(project.path, at: 3, in: statement)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    logSQLiteFailure(database: database, operation: "save projects insert")
                    return false
                }
            }

            return true
        } ?? false
    }

    private static func insertSessions(
        _ sessions: [StoredSession],
        projectIDMap: [String: String],
        projectsByID: [String: ProjectItem],
        in database: OpaquePointer
    ) -> Bool {
        let sql = """
        INSERT INTO sessions (id, project_id, pi_session_id, title, status, session_file, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        return withPreparedStatement(sql, in: database, operation: "save sessions insert") { statement in
            for session in sessions {
                guard let persistedProjectID = projectIDMap[session.projectID],
                      projectsByID[persistedProjectID] != nil
                else {
                    continue
                }

                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                bind(session.id, at: 1, in: statement)
                bind(persistedProjectID, at: 2, in: statement)
                bindNullable(session.piSessionID, at: 3, in: statement)
                bind(session.title, at: 4, in: statement)
                bind(session.status, at: 5, in: statement)
                bind(session.sessionFile, at: 6, in: statement)
                bind(formatDate(session.updatedAt), at: 7, in: statement)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    logSQLiteFailure(database: database, operation: "save sessions insert")
                    return false
                }
            }

            return true
        } ?? false
    }

    private static func insertSelection(_ value: String?, key: String, in database: OpaquePointer) -> Bool {
        guard let value else {
            return true
        }

        let sql = "INSERT INTO app_selection (key, value) VALUES (?, ?);"
        return withPreparedStatement(sql, in: database, operation: "save selection insert") { statement in
            bind(key, at: 1, in: statement)
            bind(value, at: 2, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                logSQLiteFailure(database: database, operation: "save selection insert")
                return false
            }

            return true
        } ?? false
    }

    private static func loadProjects(from database: OpaquePointer) -> [ProjectItem] {
        let sql = "SELECT id, name, path FROM projects ORDER BY rowid;"
        var projects: [ProjectItem] = []

        _ = withPreparedStatement(sql, in: database, operation: "load projects") { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = columnText(statement, index: 0),
                      let name = columnText(statement, index: 1),
                      let path = columnText(statement, index: 2)
                else {
                    continue
                }

                projects.append(ProjectItem(id: id, name: name, path: path))
            }

            return true
        }

        return projects
    }

    private static func loadSessions(from database: OpaquePointer) -> [StoredSession] {
        let sql = """
        SELECT sessions.id,
               sessions.pi_session_id,
               sessions.project_id,
               projects.path,
               projects.name,
               sessions.title,
               sessions.status,
               sessions.session_file,
               sessions.updated_at
        FROM sessions
        INNER JOIN projects ON projects.id = sessions.project_id
        ORDER BY sessions.rowid;
        """
        var sessions: [StoredSession] = []

        _ = withPreparedStatement(sql, in: database, operation: "load sessions") { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = columnText(statement, index: 0),
                      let projectID = columnText(statement, index: 2),
                      let projectPath = columnText(statement, index: 3),
                      let projectName = columnText(statement, index: 4),
                      let title = columnText(statement, index: 5),
                      let status = columnText(statement, index: 6),
                      let sessionFile = columnText(statement, index: 7),
                      let updatedAtString = columnText(statement, index: 8),
                      let updatedAt = parseDate(updatedAtString)
                else {
                    continue
                }

                sessions.append(StoredSession(
                    id: id,
                    piSessionID: columnText(statement, index: 1),
                    projectID: projectID,
                    projectPath: projectPath,
                    projectName: projectName,
                    title: title,
                    status: status,
                    sessionFile: sessionFile,
                    updatedAt: updatedAt
                ))
            }

            return true
        }

        return sessions
    }

    private static func loadSelectionValue(_ key: String, from database: OpaquePointer) -> String? {
        let sql = "SELECT value FROM app_selection WHERE key = ? LIMIT 1;"
        var value: String?

        _ = withPreparedStatement(sql, in: database, operation: "load selection") { statement in
            bind(key, at: 1, in: statement)
            if sqlite3_step(statement) == SQLITE_ROW {
                value = columnText(statement, index: 0)
            }
            return true
        }

        return value
    }

    private static func withPreparedStatement<T>(
        _ sql: String,
        in database: OpaquePointer,
        operation: String,
        body: (OpaquePointer) -> T
    ) -> T? {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)

        guard result == SQLITE_OK, let statement else {
            logSQLiteFailure(database: database, operation: operation)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        return body(statement)
    }

    private static func bind(_ value: String, at index: Int32, in statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private static func bindNullable(_ value: String?, at index: Int32, in statement: OpaquePointer) {
        if let value {
            bind(value, at: index, in: statement)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private static func columnText(_ statement: OpaquePointer, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index)
        else {
            return nil
        }
        return String(cString: text)
    }

    private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter.withFractionalSeconds.string(from: date)
    }

    private static func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: value) ?? ISO8601DateFormatter.withInternetDateTime.date(from: value)
    }

    private static func logSQLiteFailure(database: OpaquePointer, operation: String) {
        let message = sqlite3_errmsg(database).map { String(cString: $0) } ?? "unknown SQLite error"
        logFailure(operation: operation, url: storeURL, message: message)
    }

    private static func logFailure(operation: String, url: URL, message: String) {
        NSLog("SessionStore SQLite \(operation) failed at \(url.path): \(message)")
    }
}

private extension ISO8601DateFormatter {
    static var withFractionalSeconds: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static var withInternetDateTime: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}

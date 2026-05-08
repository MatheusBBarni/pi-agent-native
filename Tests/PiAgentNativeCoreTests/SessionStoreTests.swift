import Foundation
import SQLite3
import XCTest
@testable import PiAgentNativeCore

final class SessionStoreTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDownWithError() throws {
        SessionStore.databaseURLForTesting = nil

        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()

        try super.tearDownWithError()
    }

    func testFreshTemporaryDatabaseLoadCreatesSchemaAndReturnsEmptyState() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL

        let state = SessionStore.load()

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertTrue(state.projects.isEmpty)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertNil(state.selectedProjectID)
        XCTAssertNil(state.selectedSessionID)
        XCTAssertEqual(try tableNames(in: databaseURL), Set(["projects", "sessions", "app_selection"]))
        XCTAssertEqual(try columnNames(table: "projects", in: databaseURL), [
            "id",
            "name",
            "path",
            "created_at",
            "updated_at"
        ])
        XCTAssertEqual(try columnNames(table: "sessions", in: databaseURL), [
            "id",
            "project_id",
            "pi_session_id",
            "title",
            "status",
            "session_file",
            "updated_at"
        ])
        XCTAssertEqual(try columnNames(table: "app_selection", in: databaseURL), [
            "key",
            "value"
        ])
    }

    func testRepeatedLoadOnExistingEmptyDatabaseLeavesSchemaIntact() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL

        _ = SessionStore.load()
        let firstTableNames = try tableNames(in: databaseURL)
        let firstProjectColumns = try columnNames(table: "projects", in: databaseURL)

        let state = SessionStore.load()

        XCTAssertTrue(state.projects.isEmpty)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertEqual(try tableNames(in: databaseURL), firstTableNames)
        XCTAssertEqual(try columnNames(table: "projects", in: databaseURL), firstProjectColumns)
    }

    func testSaveOneProjectAndLoadItBackWithSameIdentityNameAndPath() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")

        SessionStore.save(AppPersistedState(projects: [project]))

        let state = SessionStore.load()
        XCTAssertEqual(state.projects, [project])
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertNil(state.selectedProjectID)
        XCTAssertNil(state.selectedSessionID)
    }

    func testSaveTwoSessionsForOneProjectPreservesLocalIDAndPiRPCID() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let older = storedSession(
            id: "local-session-1",
            piSessionID: "pi-session-1",
            project: project,
            title: "Plan persistence",
            updatedAt: Date(timeIntervalSince1970: 1_763_000_000)
        )
        let newer = storedSession(
            id: "local-session-2",
            piSessionID: "pi-session-2",
            project: project,
            title: "Implement persistence",
            updatedAt: Date(timeIntervalSince1970: 1_763_000_100)
        )

        SessionStore.save(AppPersistedState(projects: [project], sessions: [older, newer]))

        let state = SessionStore.load()
        XCTAssertEqual(state.projects, [project])
        XCTAssertEqual(state.sessions, [older, newer])
        XCTAssertEqual(state.sessions.map(\.id), ["local-session-1", "local-session-2"])
        XCTAssertEqual(state.sessions.map(\.piSessionID), ["pi-session-1", "pi-session-2"])
    }

    func testSaveSelectedProjectAndSessionIDsAndLoadBothBack() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let session = storedSession(
            id: "session-1",
            piSessionID: "pi-session-1",
            project: project,
            title: "Build UI",
            updatedAt: Date(timeIntervalSince1970: 1_763_000_000)
        )
        let state = AppPersistedState(
            projects: [project],
            sessions: [session],
            selectedProjectID: project.id,
            selectedSessionID: "session-1"
        )

        SessionStore.save(state)

        let loaded = SessionStore.load()
        XCTAssertEqual(loaded.selectedProjectID, "project-1")
        XCTAssertEqual(loaded.selectedSessionID, "session-1")
    }

    func testSavingDuplicateProjectPathsResultsInOneCanonicalProjectRecord() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let projectDirectory = temporaryDirectoryURL().appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let canonicalProject = ProjectItem(id: "project-1", name: "Repo", path: projectDirectory.path)
        let duplicateProject = ProjectItem(id: "project-2", name: "Repo Duplicate", path: projectDirectory.appendingPathComponent(".").path)

        SessionStore.save(AppPersistedState(projects: [canonicalProject, duplicateProject]))

        let state = SessionStore.load()
        XCTAssertEqual(state.projects, [canonicalProject])
        XCTAssertEqual(try rowCount(table: "projects", in: databaseURL), 1)
    }

    func testLegacySessionsJSONIsIgnoredForFreshSQLiteState() throws {
        let directoryURL = temporaryDirectoryURL()
        try Data(
            """
            {
              "projects": [{"id": "legacy-project", "name": "Legacy", "path": "/tmp/legacy"}],
              "sessions": [],
              "selectedProjectPath": "/tmp/legacy",
              "selectedSessionID": null
            }
            """.utf8
        ).write(to: directoryURL.appendingPathComponent("sessions.json"))
        SessionStore.databaseURLForTesting = directoryURL.appendingPathComponent("sessions.sqlite")

        let state = SessionStore.load()

        XCTAssertTrue(state.projects.isEmpty)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertNil(state.selectedProjectID)
        XCTAssertNil(state.selectedSessionID)
    }

    func testTwoSequentialSaveLoadCyclesPreserveFinalStateWithoutDuplicatingRows() throws {
        let databaseURL = temporaryDatabaseURL()
        SessionStore.databaseURLForTesting = databaseURL
        let project = ProjectItem(id: "project-1", name: "Repo", path: "/tmp/repo")
        let firstSession = storedSession(
            id: "session-1",
            piSessionID: "pi-session-1",
            project: project,
            title: "First",
            updatedAt: Date(timeIntervalSince1970: 1_763_000_000)
        )
        let finalSession = storedSession(
            id: "session-2",
            piSessionID: "pi-session-2",
            project: project,
            title: "Final",
            updatedAt: Date(timeIntervalSince1970: 1_763_000_200)
        )

        SessionStore.save(AppPersistedState(
            projects: [project],
            sessions: [firstSession],
            selectedProjectID: project.id,
            selectedSessionID: firstSession.id
        ))
        XCTAssertEqual(SessionStore.load().sessions, [firstSession])

        SessionStore.save(AppPersistedState(
            projects: [project, ProjectItem(id: "duplicate", name: "Duplicate", path: "/tmp/repo/.")],
            sessions: [firstSession, finalSession],
            selectedProjectID: project.id,
            selectedSessionID: finalSession.id
        ))

        let finalState = SessionStore.load()
        XCTAssertEqual(finalState.projects, [project])
        XCTAssertEqual(finalState.sessions, [firstSession, finalSession])
        XCTAssertEqual(finalState.selectedProjectID, project.id)
        XCTAssertEqual(finalState.selectedSessionID, finalSession.id)
        XCTAssertEqual(try rowCount(table: "projects", in: databaseURL), 1)
        XCTAssertEqual(try rowCount(table: "sessions", in: databaseURL), 2)
    }

    func testInvalidParentPathReturnsEmptyStateWithoutCreatingDatabase() throws {
        let parentFileURL = temporaryDirectoryURL().appendingPathComponent("not-a-directory")
        try Data("not a directory".utf8).write(to: parentFileURL)
        let databaseURL = parentFileURL.appendingPathComponent("sessions.sqlite")
        SessionStore.databaseURLForTesting = databaseURL

        let state = SessionStore.load()

        XCTAssertTrue(state.projects.isEmpty)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertNil(state.selectedProjectID)
        XCTAssertNil(state.selectedSessionID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    func testStoreURLPointsToApplicationSupportSQLiteDatabase() {
        SessionStore.databaseURLForTesting = nil

        let url = SessionStore.storeURL

        XCTAssertEqual(url.lastPathComponent, "sessions.sqlite")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "PiAgentNative")
        XCTAssertTrue(url.path.contains("/Application Support/"))
    }

    private func temporaryDatabaseURL() -> URL {
        temporaryDirectoryURL().appendingPathComponent("sessions.sqlite")
    }

    private func temporaryDirectoryURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }

    private func tableNames(in databaseURL: URL) throws -> Set<String> {
        let rows = try query(
            databaseURL: databaseURL,
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
        )
        return Set(rows.compactMap(\.first))
    }

    private func columnNames(table: String, in databaseURL: URL) throws -> [String] {
        let rows = try query(databaseURL: databaseURL, sql: "PRAGMA table_info(\(table));")
        return rows.compactMap { row in
            guard row.count > 1 else { return nil }
            return row[1]
        }
    }

    private func rowCount(table: String, in databaseURL: URL) throws -> Int {
        let rows = try query(databaseURL: databaseURL, sql: "SELECT COUNT(*) FROM \(table);")
        return rows.first?.first.flatMap(Int.init) ?? 0
    }

    private func storedSession(
        id: String,
        piSessionID: String?,
        project: ProjectItem,
        title: String,
        updatedAt: Date
    ) -> StoredSession {
        StoredSession(
            id: id,
            piSessionID: piSessionID,
            projectID: project.id,
            projectPath: project.path,
            projectName: project.name,
            title: title,
            status: "Ready",
            sessionFile: "/tmp/\(id).json",
            updatedAt: updatedAt
        )
    }

    private func query(databaseURL: URL, sql: String) throws -> [[String]] {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        guard let database else {
            throw SQLiteTestError.openFailed
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
        guard let statement else {
            throw SQLiteTestError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }

        var rows: [[String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String] = []
            for index in 0..<sqlite3_column_count(statement) {
                if let text = sqlite3_column_text(statement, index) {
                    row.append(String(cString: text))
                } else {
                    row.append("")
                }
            }
            rows.append(row)
        }
        return rows
    }
}

private enum SQLiteTestError: Error {
    case openFailed
    case prepareFailed
}

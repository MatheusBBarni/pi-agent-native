import XCTest
@testable import PiAgentNativeCore

@MainActor
final class SettingsDiagnosticsTests: XCTestCase {
    private var temporaryURLs: [URL] = []
    private var originalCustomExecutablePath: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalCustomExecutablePath = UserDefaults.standard.string(forKey: "customExecutablePath")
        SessionStore.databaseURLForTesting = temporaryDatabaseURL()
    }

    override func tearDownWithError() throws {
        SessionStore.databaseURLForTesting = nil
        if let originalCustomExecutablePath {
            UserDefaults.standard.set(originalCustomExecutablePath, forKey: "customExecutablePath")
        } else {
            UserDefaults.standard.removeObject(forKey: "customExecutablePath")
        }
        originalCustomExecutablePath = nil

        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()

        try super.tearDownWithError()
    }

    func testSettingsStoreExposesProjectSessionSQLiteDatabasePathFromSessionStore() {
        let store = SettingsStore(customExecutablePath: "")

        XCTAssertEqual(store.projectSessionStorePath, SessionStore.storeURL.path)
        XCTAssertEqual(URL(fileURLWithPath: store.projectSessionStorePath).lastPathComponent, "sessions.sqlite")
        XCTAssertFalse(store.projectSessionStorePath.contains("sessions.json"))
    }

    func testSettingsStoreKeepsAuthDirectoryPathUnchanged() {
        let store = SettingsStore(customExecutablePath: "")

        XCTAssertEqual(store.authDirectoryPath, NativeAuthStore.authDirectoryURL.path)
    }

    func testExecutableValidationCoversInvalidAndPersistedCustomPaths() throws {
        let store = SettingsStore(customExecutablePath: "/tmp/pi-agent-native-missing-executable")

        XCTAssertEqual(store.executableValidationMessage, "Path is not currently executable")

        let executableURL = temporaryDirectoryURL().appendingPathComponent("pi-test")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        store.customExecutablePath = executableURL.path

        XCTAssertEqual(store.executableValidationMessage, "Executable path is valid")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "customExecutablePath"), executableURL.path)
    }

    func testSettingsSheetDiagnosticsContractRendersSQLiteStatePathAndLaunchDiagnostics() {
        let model = AppModel()

        let presentation = SettingsDiagnosticsPresentation(settingsStore: model.settingsStore)

        XCTAssertEqual(presentation.stateDiagnostics, [
            SettingsDiagnosticItem(title: "Project/session DB", value: SessionStore.storeURL.path),
            SettingsDiagnosticItem(title: "Auth", value: NativeAuthStore.authDirectoryURL.path)
        ])
        XCTAssertFalse(presentation.stateDiagnostics.contains { item in
            item.title == "Sessions" || item.value.contains("sessions.json")
        })
        XCTAssertEqual(presentation.launchDiagnostics, [
            SettingsDiagnosticItem(title: "Validation", value: model.settingsStore.executableValidationMessage),
            SettingsDiagnosticItem(title: "PI_MONO_PATH", value: model.settingsStore.piMonoPath),
            SettingsDiagnosticItem(
                title: "Resolved command",
                value: "\(model.settingsStore.resolvedLaunchPreview.diagnostic) --mode rpc"
            )
        ])
    }

    private func temporaryDatabaseURL() -> URL {
        temporaryDirectoryURL().appendingPathComponent("sessions.sqlite")
    }

    private func temporaryDirectoryURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsDiagnosticsTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }
}

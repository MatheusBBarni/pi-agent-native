import XCTest
@testable import PiAgentNativeCore

@MainActor
final class SettingsStoreLanguageTests: XCTestCase {
    private let appLanguageKey = "appLanguage"
    private let customExecutablePathKey = "customExecutablePath"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: appLanguageKey)
        UserDefaults.standard.removeObject(forKey: customExecutablePathKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: appLanguageKey)
        UserDefaults.standard.removeObject(forKey: customExecutablePathKey)
        super.tearDown()
    }

    func testMissingAppLanguageDefaultsToEnglish() {
        let store = SettingsStore()

        XCTAssertEqual(store.appLanguage, .english)
    }

    func testSavedPortugueseBrazilValueLoads() {
        UserDefaults.standard.set(AppLanguage.portugueseBrazil.rawValue, forKey: appLanguageKey)

        let store = SettingsStore()

        XCTAssertEqual(store.appLanguage, .portugueseBrazil)
    }

    func testInvalidPersistedRawValueFallsBackToEnglish() {
        UserDefaults.standard.set("pt", forKey: appLanguageKey)

        let store = SettingsStore()

        XCTAssertEqual(store.appLanguage, .english)
    }

    func testSettingAppLanguageWritesExpectedRawValue() {
        let store = SettingsStore()

        store.appLanguage = .portugueseBrazil

        XCTAssertEqual(UserDefaults.standard.string(forKey: appLanguageKey), "pt-BR")
    }

    func testAppModelAppLanguageProxiesSettingsStore() {
        let model = AppModel()

        model.appLanguage = .portugueseBrazil

        XCTAssertEqual(model.settingsStore.appLanguage, .portugueseBrazil)
        XCTAssertEqual(model.appLanguage, .portugueseBrazil)
        XCTAssertEqual(UserDefaults.standard.string(forKey: appLanguageKey), "pt-BR")
    }

    func testSelectedLanguageDrivesLocalizedSettingsTextThroughAppModel() {
        let model = AppModel()

        XCTAssertEqual(model.l10n.string("settings.title"), "Settings")

        model.appLanguage = .portugueseBrazil

        XCTAssertEqual(model.l10n.string("settings.title"), "Configurações")
        XCTAssertEqual(model.l10n.string("settings.language.portuguese_brazil"), "Português (Brasil)")
    }

    func testCustomExecutablePathStillWritesThroughSettingsStore() {
        let store = SettingsStore()

        store.customExecutablePath = "/usr/local/bin/pi"

        XCTAssertEqual(UserDefaults.standard.string(forKey: customExecutablePathKey), "/usr/local/bin/pi")
    }

    func testExecutableValidationMessageCoversDefaultInvalidJSAndExecutablePaths() throws {
        let store = SettingsStore()
        XCTAssertEqual(store.executableValidationMessage, "Using bundled pi resolution")

        store.customExecutablePath = "/tmp/not-executable"
        XCTAssertEqual(store.executableValidationMessage, "Path is not currently executable")

        store.customExecutablePath = "/tmp/pi-cli.js"
        XCTAssertEqual(store.executableValidationMessage, "Executable path is valid")

        let executableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try "#!/bin/sh\nexit 0\n".write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )
        defer {
            try? FileManager.default.removeItem(at: executableURL)
        }

        store.customExecutablePath = executableURL.path
        XCTAssertEqual(store.executableValidationMessage, "Executable path is valid")
    }

    func testSettingsDiagnosticsExposeResolvedPathsAndLaunchPreview() {
        let store = SettingsStore(customExecutablePath: "/tmp/pi-cli.js")

        XCTAssertFalse(store.piMonoPath.isEmpty)
        XCTAssertFalse(store.sessionStorePath.isEmpty)
        XCTAssertFalse(store.authDirectoryPath.isEmpty)
        XCTAssertEqual(store.resolvedLaunchPreview.displayName, "Custom pi")
        XCTAssertEqual(store.resolvedLaunchPreview.executableURL.path, "/usr/bin/env")
        XCTAssertEqual(store.resolvedLaunchPreview.arguments, ["node", "/tmp/pi-cli.js", "--mode", "rpc"])
        XCTAssertEqual(store.resolvedLaunchPreview.diagnostic, "node /tmp/pi-cli.js")
    }
}

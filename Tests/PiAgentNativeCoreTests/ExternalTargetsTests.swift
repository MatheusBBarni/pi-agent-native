import XCTest
@testable import PiAgentNativeCore

final class ExternalTargetsTests: XCTestCase {
    func testCatalogContainsFirstVersionTargetsAndExcludesGitHub() {
        let targetIDs = Set(ExternalTargetCatalog.definitions.map(\.id))
        XCTAssertEqual(
            targetIDs,
            [.finder, .terminal, .xcode, .zed, .cursor, .vscode, .androidStudio, .antigravity]
        )
        XCTAssertFalse(ExternalTargetCatalog.definitions.contains { $0.displayName == "GitHub" })
    }

    func testScanReturnsOnlyBaselineTargetsWhenEditorsAreUnavailable() {
        let scanner = ExternalTargetScanner(
            applicationDirectories: [],
            environmentPath: "",
            applicationURLForBundleIdentifier: { _ in nil },
            fileExistsAtPath: { _ in false },
            isExecutableFileAtPath: { _ in false }
        )

        XCTAssertEqual(scanner.scan().map(\.id), [.finder, .terminal])
    }

    func testScanIncludesInstalledAppTargetFromBoundedApplicationDirectory() {
        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let scanner = ExternalTargetScanner(
            applicationDirectories: [applicationsURL],
            environmentPath: "",
            applicationURLForBundleIdentifier: { _ in nil },
            fileExistsAtPath: { path in path == "/Applications/Cursor.app" },
            isExecutableFileAtPath: { _ in false }
        )

        let cursor = scanner.scan().first { $0.id == .cursor }

        XCTAssertEqual(cursor?.launchReference, .appBundleURL(applicationsURL.appendingPathComponent("Cursor.app", isDirectory: true)))
    }

    func testScanIncludesEditorCommandWhenNoAppBundleExists() {
        let scanner = ExternalTargetScanner(
            applicationDirectories: [],
            environmentPath: "/custom/bin",
            applicationURLForBundleIdentifier: { _ in nil },
            fileExistsAtPath: { _ in false },
            isExecutableFileAtPath: { path in path == "/custom/bin/code" }
        )

        let vscode = scanner.scan().first { $0.id == .vscode }

        XCTAssertEqual(vscode?.launchReference, .commandPath("/custom/bin/code"))
    }

    func testTerminalLaunchPlanPassesProjectPathWithSpacesAsOneArgument() {
        let terminal = AvailableExternalTarget(
            definition: ExternalTargetCatalog.definitions.first { $0.id == .terminal }!,
            launchReference: .baselineMacTarget
        )

        let plan = ExternalTargetLauncher.launchPlan(for: terminal, projectPath: "/tmp/My Project")

        XCTAssertEqual(
            plan,
            .command(executablePath: "/usr/bin/open", arguments: ["-a", "Terminal", "/tmp/My Project"])
        )
    }

    func testEditorCommandLaunchPlanPassesProjectPathWithSpacesAsOneArgument() {
        let vscode = AvailableExternalTarget(
            definition: ExternalTargetCatalog.definitions.first { $0.id == .vscode }!,
            launchReference: .commandPath("/custom/bin/code")
        )

        let plan = ExternalTargetLauncher.launchPlan(for: vscode, projectPath: "/tmp/My Project")

        XCTAssertEqual(
            plan,
            .command(executablePath: "/custom/bin/code", arguments: ["/tmp/My Project"])
        )
    }
}

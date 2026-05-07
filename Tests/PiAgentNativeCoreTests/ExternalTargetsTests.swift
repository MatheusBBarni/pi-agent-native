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
            directoryExistsAtPath: { _ in false },
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
            directoryExistsAtPath: { path in path == "/Applications/Cursor.app" },
            isExecutableFileAtPath: { _ in false }
        )

        let cursor = scanner.scan().first { $0.id == .cursor }

        XCTAssertEqual(cursor?.launchReference, .appBundleURL(applicationsURL.appendingPathComponent("Cursor.app", isDirectory: true)))
    }

    func testScanDoesNotIncludeAppTargetWhenAppNameExistsButIsNotDirectory() {
        let scanner = ExternalTargetScanner(
            applicationDirectories: [URL(fileURLWithPath: "/Applications", isDirectory: true)],
            environmentPath: "",
            applicationURLForBundleIdentifier: { _ in nil },
            directoryExistsAtPath: { _ in false },
            isExecutableFileAtPath: { _ in false }
        )

        XCTAssertNil(scanner.scan().first { $0.id == .cursor })
    }

    func testScanIncludesEditorCommandWhenNoAppBundleExists() {
        let scanner = ExternalTargetScanner(
            applicationDirectories: [],
            environmentPath: "/custom/bin",
            applicationURLForBundleIdentifier: { _ in nil },
            directoryExistsAtPath: { _ in false },
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

    func testCommandLaunchReportsNonZeroExitAsFailure() {
        let failingCommand = AvailableExternalTarget(
            definition: ExternalTargetCatalog.definitions.first { $0.id == .vscode }!,
            launchReference: .commandPath("/usr/bin/false")
        )
        let expectation = expectation(description: "command launch completes")

        ExternalTargetLauncher.launch(failingCommand, projectPath: "/tmp/My Project") { result in
            guard case .failure(let error as ExternalCommandLaunchError) = result else {
                XCTFail("Expected command launch to fail")
                expectation.fulfill()
                return
            }

            XCTAssertEqual(error.executablePath, "/usr/bin/false")
            XCTAssertNotEqual(error.terminationStatus, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }
}

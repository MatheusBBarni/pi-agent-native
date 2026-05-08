import Foundation
import XCTest

final class BuildAppScriptTests: XCTestCase {
    private let fileManager = FileManager.default

    func testScriptPreservesSpacedAppBundlePath() throws {
        let script = try String(contentsOf: scriptURL)

        XCTAssertTrue(script.contains("APP_DIR=\"$ROOT_DIR/.build/Pi Agent.app\""))
        XCTAssertTrue(script.contains("LEGACY_APP_DIR=\"$ROOT_DIR/.build/PiAgentNative.app\""))
    }

    func testResourceBundleDiscoveryHandlesDebugBuildOutput() throws {
        let buildProductsURL = try makeTemporaryDirectory()
        let otherBundleURL = buildProductsURL.appendingPathComponent("Unrelated.bundle")
        let localizationBundleURL = buildProductsURL.appendingPathComponent("PiAgentNative_PiAgentNativeCore.bundle")

        try makeBundle(at: otherBundleURL, localizations: ["en"])
        try makeBundle(at: localizationBundleURL, localizations: ["en", "pt-br"])

        let result = try runBash(
            command: #"source "$1"; find_localization_resource_bundle "$2""#,
            arguments: [scriptURL.path, buildProductsURL.path]
        )

        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), localizationBundleURL.path)
    }

    func testScriptDoesNotCopyRawLocalizationDirectoriesAsPackagingStrategy() throws {
        let script = try String(contentsOf: scriptURL)

        XCTAssertFalse(script.contains("Sources/PiAgentNative/Resources/en.lproj"))
        XCTAssertFalse(script.contains("Sources/PiAgentNative/Resources/pt-BR.lproj"))
        XCTAssertTrue(script.contains("copy_localization_resource_bundle"))
        XCTAssertTrue(script.contains("cp -R \"$source_bundle\" \"$destination_bundle\""))
    }

    func testDebugBuildAppPackagesLocalizationResourceBundle() throws {
        try runBuildApp(arguments: [])
        try assertPackagedAppContainsLocalizationBundle()
    }

    func testReleaseBuildAppPackagesLocalizationResourceBundle() throws {
        try runBuildApp(arguments: ["release"])
        try assertPackagedAppContainsLocalizationBundle()
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var scriptURL: URL {
        repositoryRootURL
            .appendingPathComponent("Scripts")
            .appendingPathComponent("build-app.sh")
    }

    private var appBundleURL: URL {
        repositoryRootURL
            .appendingPathComponent(".build")
            .appendingPathComponent("Pi Agent.app")
    }

    private func runBuildApp(arguments: [String]) throws {
        let buildRootURL = try makeTemporaryDirectory()
        let result = try runProcess(
            executableURL: scriptURL,
            arguments: arguments,
            currentDirectoryURL: repositoryRootURL,
            environment: [
                "PI_AGENT_NATIVE_SWIFTPM_BUILD_ROOT": buildRootURL.path
            ]
        )

        XCTAssertTrue(result.stdout.contains(".build/Pi Agent.app"), result.stdout)
    }

    private func assertPackagedAppContainsLocalizationBundle() throws {
        let resourcesURL = appBundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")

        XCTAssertTrue(fileManager.fileExists(atPath: appBundleURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: resourcesURL.appendingPathComponent("AppIcon.icns").path))
        XCTAssertTrue(fileManager.fileExists(
            atPath: appBundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("MacOS")
                .appendingPathComponent("PiAgentNative")
                .path
        ))

        let resourceBundleURL = try XCTUnwrap(
            try fileManager.contentsOfDirectory(
                at: resourcesURL,
                includingPropertiesForKeys: nil
            ).first { url in
                url.pathExtension == "bundle"
                    && self.localizableStringsURL(in: url, locale: "en") != nil
                    && self.localizableStringsURL(in: url, locale: "pt-BR") != nil
            }
        )

        XCTAssertNotNil(localizableStringsURL(in: resourceBundleURL, locale: "en"))
        XCTAssertNotNil(localizableStringsURL(in: resourceBundleURL, locale: "pt-BR"))

        let plistURL = appBundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        let plist = try XCTUnwrap(NSDictionary(contentsOf: plistURL) as? [String: Any])
        XCTAssertEqual(plist["CFBundleDevelopmentRegion"] as? String, "en")
        XCTAssertEqual(Set(plist["CFBundleLocalizations"] as? [String] ?? []), ["en", "pt-BR"])
    }

    private func localizableStringsURL(in bundleURL: URL, locale: String) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        let expectedLproj = "\(locale).lproj".lowercased()
        for case let url as URL in enumerator where url.lastPathComponent == "Localizable.strings" {
            if url.deletingLastPathComponent().lastPathComponent.lowercased() == expectedLproj {
                return url
            }
        }

        return nil
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeBundle(at bundleURL: URL, localizations: [String]) throws {
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>dev.pi-agent-native.build-app-tests</string>
        </dict>
        </plist>
        """.write(to: bundleURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        for localization in localizations {
            let lprojURL = bundleURL.appendingPathComponent("\(localization).lproj")
            try fileManager.createDirectory(at: lprojURL, withIntermediateDirectories: true)
            try "\"localization.smoke_test\" = \"Available\";\n".write(
                to: lprojURL.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    private func runBash(command: String, arguments: [String]) throws -> ProcessResult {
        try runProcess(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-c", command, "bash"] + arguments,
            currentDirectoryURL: repositoryRootURL
        )
    }

    @discardableResult
    private func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        environment: [String: String] = [:]
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        if !environment.isEmpty {
            var mergedEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                mergedEnvironment[key] = value
            }
            process.environment = mergedEnvironment
        }

        let outputURL = try makeTemporaryDirectory().appendingPathComponent("stdout.log")
        let errorURL = try makeTemporaryDirectory().appendingPathComponent("stderr.log")
        _ = fileManager.createFile(atPath: outputURL.path, contents: nil)
        _ = fileManager.createFile(atPath: errorURL.path, contents: nil)

        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        process.standardOutput = outputHandle
        process.standardError = errorHandle

        try process.run()
        process.waitUntilExit()
        try outputHandle.close()
        try errorHandle.close()

        let result = ProcessResult(
            terminationStatus: process.terminationStatus,
            stdout: try String(contentsOf: outputURL, encoding: .utf8),
            stderr: try String(contentsOf: errorURL, encoding: .utf8)
        )

        XCTAssertEqual(
            result.terminationStatus,
            0,
            """
            stdout:
            \(result.stdout)

            stderr:
            \(result.stderr)
            """
        )

        return result
    }

    private struct ProcessResult {
        var terminationStatus: Int32
        var stdout: String
        var stderr: String
    }
}

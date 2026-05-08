import Foundation
import XCTest
@testable import PiAgentNativeCore

final class LocalizationCoverageTests: XCTestCase {
    func testCoverageReporterReturnsNoWarningsForBundleModuleRequiredKeys() {
        let warnings = LocalizationCoverageReporter().warnings()

        XCTAssertEqual(warnings, [])
    }

    func testCoverageReporterReturnsStructuredWarningsForMissingKeys() throws {
        let bundle = try makeBundle(
            localizations: [
                "en": [
                    "present.key": "Present"
                ],
                "pt-BR": [
                    "unrelated.key": "Não relacionado"
                ]
            ]
        )

        let warnings = LocalizationCoverageReporter(
            bundle: bundle,
            languages: [.english, .portugueseBrazil],
            requiredKeys: ["present.key", "missing.key"]
        ).warnings()

        XCTAssertEqual(
            warnings,
            [
                LocalizationCoverageWarning(
                    language: .english,
                    key: "missing.key",
                    reason: .missingKey
                ),
                LocalizationCoverageWarning(
                    language: .portugueseBrazil,
                    key: "present.key",
                    reason: .missingKey
                ),
                LocalizationCoverageWarning(
                    language: .portugueseBrazil,
                    key: "missing.key",
                    reason: .missingKey
                )
            ]
        )
        XCTAssertEqual(
            warnings.map(\.message),
            [
                "Missing localization key 'missing.key' for en.",
                "Missing localization key 'present.key' for pt-BR.",
                "Missing localization key 'missing.key' for pt-BR."
            ]
        )
    }

    func testCoverageReporterReturnsWarningsWhenLanguageResourceIsMissing() throws {
        let bundle = try makeBundle(
            localizations: [
                "en": [
                    "present.key": "Present"
                ]
            ]
        )

        let warnings = LocalizationCoverageReporter(
            bundle: bundle,
            languages: [.portugueseBrazil],
            requiredKeys: ["present.key"]
        ).warnings()

        XCTAssertEqual(
            warnings,
            [
                LocalizationCoverageWarning(
                    language: .portugueseBrazil,
                    key: "present.key",
                    reason: .missingResource
                )
            ]
        )
    }

    private func makeBundle(localizations: [String: [String: String]]) throws -> Bundle {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>dev.pi-agent-native.localization-tests</string>
        </dict>
        </plist>
        """.write(to: rootURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        for (localization, strings) in localizations {
            let lprojURL = rootURL.appendingPathComponent("\(localization).lproj")
            try FileManager.default.createDirectory(at: lprojURL, withIntermediateDirectories: true)

            let contents = strings
                .sorted { $0.key < $1.key }
                .map { "\"\($0.key)\" = \"\($0.value)\";" }
                .joined(separator: "\n")
            try contents.write(
                to: lprojURL.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )
        }

        return try XCTUnwrap(Bundle(url: rootURL))
    }
}

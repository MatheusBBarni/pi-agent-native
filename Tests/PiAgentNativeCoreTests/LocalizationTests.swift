import Foundation
import XCTest
@testable import PiAgentNativeCore

final class LocalizationResourceTests: XCTestCase {
    private let formatKey = "localization.format.verbatim"
    private let smokeTestKey = "localization.smoke_test"

    func testAppLanguageExposesStableIdentifiers() {
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
        XCTAssertEqual(AppLanguage.english.id, "en")
        XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")

        XCTAssertEqual(AppLanguage.portugueseBrazil.rawValue, "pt-BR")
        XCTAssertEqual(AppLanguage.portugueseBrazil.id, "pt-BR")
        XCTAssertEqual(AppLanguage.portugueseBrazil.localeIdentifier, "pt-BR")

        XCTAssertEqual(AppLanguage.allCases, [.english, .portugueseBrazil])
    }

    func testEnglishLocalizableStringsContainsSmokeTestKey() throws {
        let strings = try localizableStrings(for: "en")

        XCTAssertEqual(strings[smokeTestKey], "Localization resources are available.")
        XCTAssertEqual(strings[formatKey], "Open %@")
    }

    func testPortugueseBrazilLocalizableStringsContainsSmokeTestKey() throws {
        let strings = try localizableStrings(for: "pt-BR")

        XCTAssertEqual(strings[smokeTestKey], "Os recursos de localização estão disponíveis.")
        XCTAssertEqual(strings[formatKey], "Abrir %@")
    }

    func testBundleModuleResolvesLocalizedSmokeTestKey() throws {
        XCTAssertEqual(
            try localizedString(for: smokeTestKey, locale: "en"),
            "Localization resources are available."
        )
        XCTAssertEqual(
            try localizedString(for: smokeTestKey, locale: "pt-BR"),
            "Os recursos de localização estão disponíveis."
        )
    }

    func testL10nReturnsSelectedEnglishValue() {
        let l10n = L10n(language: .english)

        XCTAssertEqual(l10n.string(smokeTestKey), "Localization resources are available.")
    }

    func testL10nReturnsSelectedPortugueseBrazilValue() {
        let l10n = L10n(language: .portugueseBrazil)

        XCTAssertEqual(l10n.string(smokeTestKey), "Os recursos de localização estão disponíveis.")
    }

    func testL10nFormattingPreservesRawInterpolationValues() {
        let rawTechnicalValue = "/tmp/Projeto Teste/gpt-5.4-mini.log"

        XCTAssertEqual(
            L10n(language: .english).string(formatKey, rawTechnicalValue),
            "Open /tmp/Projeto Teste/gpt-5.4-mini.log"
        )
        XCTAssertEqual(
            L10n(language: .portugueseBrazil).string(formatKey, rawTechnicalValue),
            "Abrir /tmp/Projeto Teste/gpt-5.4-mini.log"
        )
    }

    func testExtensionDialogControlsResolveInBothLocales() {
        let english = L10n(language: .english)
        let portuguese = L10n(language: .portugueseBrazil)

        XCTAssertEqual(english.string("extension_ui.cancel"), "Cancel")
        XCTAssertEqual(english.string("extension_ui.selection"), "Selection")
        XCTAssertEqual(english.string("extension_ui.confirm"), "Confirm")
        XCTAssertEqual(english.string("extension_ui.submit"), "Submit")
        XCTAssertEqual(english.string("extension_ui.input_label"), "Input")
        XCTAssertEqual(english.string("extension_ui.editor_label"), "Editor")
        XCTAssertEqual(english.string("extension_ui.default_value_label"), "Default value")

        XCTAssertEqual(portuguese.string("extension_ui.cancel"), "Cancelar")
        XCTAssertEqual(portuguese.string("extension_ui.selection"), "Seleção")
        XCTAssertEqual(portuguese.string("extension_ui.confirm"), "Confirmar")
        XCTAssertEqual(portuguese.string("extension_ui.submit"), "Enviar")
        XCTAssertEqual(portuguese.string("extension_ui.input_label"), "Entrada")
        XCTAssertEqual(portuguese.string("extension_ui.editor_label"), "Editor")
        XCTAssertEqual(portuguese.string("extension_ui.default_value_label"), "Valor padrão")
    }

    func testRepresentativeV1SurfaceGroupsResolveInBothLocales() {
        let english = L10n(language: .english)
        let portuguese = L10n(language: .portugueseBrazil)
        let expectations: [(surface: String, key: String, english: String, portuguese: String)] = [
            ("settings", "settings.language.title", "Language", "Idioma"),
            ("app shell", "app_shell.sidebar.projects", "Projects", "Projetos"),
            ("chat", "chat.composer.placeholder", "Ask pi to work in this workspace", "Peça ao pi para trabalhar neste workspace"),
            ("auth", "auth.model_picker.title", "Select Model", "Selecionar modelo"),
            ("command palette", "command_palette.search_placeholder", "Search commands", "Buscar comandos"),
            ("keybinding help", "keybinding.help.title", "Keyboard Shortcuts", "Atalhos de Teclado"),
            ("inspector", "inspector.branch_details.title", "Branch details", "Detalhes do branch"),
            ("process log", "process_log.empty", "No events yet", "Nenhum evento ainda"),
            ("change review", "change_review.title", "Changes", "Alterações"),
            ("extension UI", "extension_ui.submit", "Submit", "Enviar")
        ]

        for expectation in expectations {
            XCTAssertEqual(
                english.string(expectation.key),
                expectation.english,
                "English \(expectation.surface) surface should resolve \(expectation.key)"
            )
            XCTAssertEqual(
                portuguese.string(expectation.key),
                expectation.portuguese,
                "pt-BR \(expectation.surface) surface should resolve \(expectation.key)"
            )
        }
    }

    func testChangedFileCountPluralizesInEnglish() {
        let l10n = L10n(language: .english)

        XCTAssertEqual(l10n.plural("app_model.git.changed_files_count", count: 0), "0 changed files")
        XCTAssertEqual(l10n.plural("app_model.git.changed_files_count", count: 1), "1 changed file")
        XCTAssertEqual(l10n.plural("app_model.git.changed_files_count", count: 3), "3 changed files")
    }

    func testChangedFileCountPluralizesInPortugueseBrazil() {
        let l10n = L10n(language: .portugueseBrazil)

        XCTAssertEqual(l10n.plural("app_model.git.changed_files_count", count: 0), "0 arquivos alterados")
        XCTAssertEqual(l10n.plural("app_model.git.changed_files_count", count: 1), "1 arquivo alterado")
        XCTAssertEqual(l10n.plural("app_model.git.changed_files_count", count: 3), "3 arquivos alterados")
    }

    func testQueuedWorkCountPluralizesInBothLocales() {
        XCTAssertEqual(
            L10n(language: .english).plural("inspector.queued_work.count", count: 1),
            "1 item queued"
        )
        XCTAssertEqual(
            L10n(language: .english).plural("inspector.queued_work.count", count: 2),
            "2 items queued"
        )
        XCTAssertEqual(
            L10n(language: .portugueseBrazil).plural("inspector.queued_work.count", count: 1),
            "1 item na fila"
        )
        XCTAssertEqual(
            L10n(language: .portugueseBrazil).plural("inspector.queued_work.count", count: 2),
            "2 itens na fila"
        )
    }

    private func localizableStrings(for locale: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: locale
            )
        )
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }

    private func localizedString(for key: String, locale: String) throws -> String {
        let localizableURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: locale
            )
        )
        let lprojURL = localizableURL.deletingLastPathComponent()
        let bundle = try XCTUnwrap(Bundle(url: lprojURL))

        return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
}

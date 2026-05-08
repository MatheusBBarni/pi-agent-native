import Foundation

public struct L10n: Sendable {
    public let language: AppLanguage

    private let bundle: Bundle

    public init(language: AppLanguage) {
        self.init(language: language, bundle: .module)
    }

    init(language: AppLanguage, bundle: Bundle) {
        self.language = language
        self.bundle = bundle
    }

    public func string(_ key: String, _ args: CVarArg...) -> String {
        string(key, arguments: args)
    }

    public func string(_ key: String, arguments: [CVarArg]) -> String {
        let format = localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")

        guard !arguments.isEmpty else {
            return format
        }

        // Only the app-owned template is localized. Caller-provided values stay verbatim.
        return String(
            format: format,
            locale: Locale(identifier: language.localeIdentifier),
            arguments: arguments
        )
    }

    public func plural(_ key: String, count: Int) -> String {
        let format = localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        return String.localizedStringWithFormat(format, count)
    }

    public func plural(_ key: String, count: Int, _ argument: CVarArg) -> String {
        let format = localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        return String.localizedStringWithFormat(format, count, argument)
    }

    private var localizedBundle: Bundle {
        Self.localizedBundle(for: language, in: bundle) ?? bundle
    }

    private static func localizedBundle(for language: AppLanguage, in bundle: Bundle) -> Bundle? {
        guard let localizableURL = bundle.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: language.rawValue
        ) else {
            return nil
        }

        return Bundle(url: localizableURL.deletingLastPathComponent())
    }
}

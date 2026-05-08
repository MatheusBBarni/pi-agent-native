import Foundation

public enum LocalizationCoverageWarningReason: String, Sendable {
    case missingKey
    case missingResource
}

public struct LocalizationCoverageWarning: Equatable, Sendable {
    public let language: AppLanguage
    public let key: String
    public let reason: LocalizationCoverageWarningReason

    public init(language: AppLanguage, key: String, reason: LocalizationCoverageWarningReason) {
        self.language = language
        self.key = key
        self.reason = reason
    }

    public var message: String {
        switch reason {
        case .missingKey:
            return "Missing localization key '\(key)' for \(language.rawValue)."
        case .missingResource:
            return "Missing Localizable.strings resource for \(language.rawValue); key '\(key)' cannot be resolved."
        }
    }
}

public struct LocalizationCoverageReporter: Sendable {
    private let bundle: Bundle
    private let languages: [AppLanguage]
    private let requiredKeys: [String]

    public init(
        languages: [AppLanguage] = AppLanguage.allCases,
        requiredKeys: [String] = LocalizationRequiredKeys.all
    ) {
        self.init(bundle: .module, languages: languages, requiredKeys: requiredKeys)
    }

    init(
        bundle: Bundle,
        languages: [AppLanguage] = AppLanguage.allCases,
        requiredKeys: [String] = LocalizationRequiredKeys.all
    ) {
        self.bundle = bundle
        self.languages = languages
        self.requiredKeys = requiredKeys
    }

    public func warnings() -> [LocalizationCoverageWarning] {
        languages.flatMap { language in
            let result = localizedKeys(for: language)

            return requiredKeys.compactMap { key in
                switch result {
                case .success(let keys):
                    return keys.contains(key)
                        ? nil
                        : LocalizationCoverageWarning(language: language, key: key, reason: .missingKey)
                case .failure:
                    return LocalizationCoverageWarning(language: language, key: key, reason: .missingResource)
                }
            }
        }
    }

    private func localizedKeys(for language: AppLanguage) -> Result<Set<String>, Error> {
        guard let url = bundle.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: language.rawValue
        ) else {
            return .failure(CocoaError(.fileNoSuchFile))
        }

        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            guard let strings = plist as? [String: String] else {
                return .failure(CocoaError(.fileReadCorruptFile))
            }

            var keys = Set(strings.keys)
            if let stringsdictURL = bundle.url(
                forResource: "Localizable",
                withExtension: "stringsdict",
                subdirectory: nil,
                localization: language.rawValue
            ) {
                let stringsdictData = try Data(contentsOf: stringsdictURL)
                let stringsdict = try PropertyListSerialization.propertyList(from: stringsdictData, format: nil)
                if let pluralEntries = stringsdict as? [String: Any] {
                    keys.formUnion(pluralEntries.keys)
                }
            }

            return .success(keys)
        } catch {
            return .failure(error)
        }
    }
}

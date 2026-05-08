import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case portugueseBrazil = "pt-BR"

    public var id: String { rawValue }

    public var localeIdentifier: String { rawValue }
}

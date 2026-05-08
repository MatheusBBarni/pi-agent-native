import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum DefaultsKey {
        static let appLanguage = "appLanguage"
        static let customExecutablePath = "customExecutablePath"
    }

    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: DefaultsKey.appLanguage)
        }
    }

    @Published var customExecutablePath: String {
        didSet {
            UserDefaults.standard.set(customExecutablePath, forKey: DefaultsKey.customExecutablePath)
        }
    }

    init(
        customExecutablePath: String = UserDefaults.standard.string(forKey: DefaultsKey.customExecutablePath) ?? "",
        appLanguage: AppLanguage = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage)
            .flatMap(AppLanguage.init(rawValue:)) ?? .english
    ) {
        self.customExecutablePath = customExecutablePath
        self.appLanguage = appLanguage
    }

    var piMonoPath: String {
        PiLaunchResolver.piMonoPath
    }

    var resolvedLaunchPreview: PiLaunchCommand {
        PiLaunchResolver.resolve(customExecutable: customExecutablePath)
    }

    var sessionStorePath: String {
        SessionStore.storeURL.path
    }

    var authDirectoryPath: String {
        NativeAuthStore.authDirectoryURL.path
    }

    var executableValidationMessage: String {
        let trimmed = customExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Using bundled pi resolution"
        }
        if FileManager.default.isExecutableFile(atPath: trimmed) || trimmed.hasSuffix(".js") {
            return "Executable path is valid"
        }
        return "Path is not currently executable"
    }
}

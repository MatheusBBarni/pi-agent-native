import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var customExecutablePath: String {
        didSet {
            UserDefaults.standard.set(customExecutablePath, forKey: "customExecutablePath")
        }
    }

    init(customExecutablePath: String = UserDefaults.standard.string(forKey: "customExecutablePath") ?? "") {
        self.customExecutablePath = customExecutablePath
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

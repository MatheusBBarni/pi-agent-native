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

    var projectSessionStorePath: String {
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

struct SettingsDiagnosticItem: Equatable, Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

@MainActor
struct SettingsDiagnosticsPresentation: Equatable {
    let launchDiagnostics: [SettingsDiagnosticItem]
    let stateDiagnostics: [SettingsDiagnosticItem]

    init(settingsStore: SettingsStore) {
        launchDiagnostics = [
            SettingsDiagnosticItem(title: "Validation", value: settingsStore.executableValidationMessage),
            SettingsDiagnosticItem(title: "PI_MONO_PATH", value: settingsStore.piMonoPath),
            SettingsDiagnosticItem(
                title: "Resolved command",
                value: "\(settingsStore.resolvedLaunchPreview.diagnostic) --mode rpc"
            )
        ]
        stateDiagnostics = [
            SettingsDiagnosticItem(title: "Project/session DB", value: settingsStore.projectSessionStorePath),
            SettingsDiagnosticItem(title: "Auth", value: settingsStore.authDirectoryPath)
        ]
    }
}

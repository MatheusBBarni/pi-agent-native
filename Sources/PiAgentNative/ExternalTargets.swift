import AppKit
import Foundation

enum ExternalTargetID: String, CaseIterable, Identifiable {
    case finder
    case terminal
    case xcode
    case zed
    case cursor
    case vscode
    case androidStudio
    case antigravity

    var id: String { rawValue }
}

struct ExternalTargetDefinition: Identifiable, Equatable {
    let id: ExternalTargetID
    let displayName: String
    let bundleIdentifiers: [String]
    let appNames: [String]
    let commandNames: [String]
    let isBaselineMacTarget: Bool
    let fallbackSystemImage: String
}

enum ExternalLaunchReference: Equatable {
    case baselineMacTarget
    case appBundleURL(URL)
    case commandPath(String)
}

struct AvailableExternalTarget: Identifiable, Equatable {
    let definition: ExternalTargetDefinition
    let launchReference: ExternalLaunchReference

    var id: ExternalTargetID { definition.id }
    var displayName: String { definition.displayName }
    var fallbackSystemImage: String { definition.fallbackSystemImage }
    var appIcon: NSImage? {
        guard case .appBundleURL(let appBundleURL) = launchReference else { return nil }
        return NSWorkspace.shared.icon(forFile: appBundleURL.path)
    }
}

enum ExternalTargetCatalog {
    static let definitions: [ExternalTargetDefinition] = [
        ExternalTargetDefinition(
            id: .finder,
            displayName: "Finder",
            bundleIdentifiers: [],
            appNames: [],
            commandNames: [],
            isBaselineMacTarget: true,
            fallbackSystemImage: "folder"
        ),
        ExternalTargetDefinition(
            id: .terminal,
            displayName: "Terminal",
            bundleIdentifiers: [],
            appNames: [],
            commandNames: [],
            isBaselineMacTarget: true,
            fallbackSystemImage: "terminal"
        ),
        ExternalTargetDefinition(
            id: .xcode,
            displayName: "Xcode",
            bundleIdentifiers: ["com.apple.dt.Xcode"],
            appNames: ["Xcode.app"],
            commandNames: [],
            isBaselineMacTarget: false,
            fallbackSystemImage: "hammer"
        ),
        ExternalTargetDefinition(
            id: .zed,
            displayName: "Zed",
            bundleIdentifiers: ["dev.zed.Zed"],
            appNames: ["Zed.app"],
            commandNames: ["zed"],
            isBaselineMacTarget: false,
            fallbackSystemImage: "chevron.left.forwardslash.chevron.right"
        ),
        ExternalTargetDefinition(
            id: .cursor,
            displayName: "Cursor",
            bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
            appNames: ["Cursor.app"],
            commandNames: ["cursor"],
            isBaselineMacTarget: false,
            fallbackSystemImage: "cursorarrow"
        ),
        ExternalTargetDefinition(
            id: .vscode,
            displayName: "VS Code",
            bundleIdentifiers: ["com.microsoft.VSCode"],
            appNames: ["Visual Studio Code.app"],
            commandNames: ["code"],
            isBaselineMacTarget: false,
            fallbackSystemImage: "curlybraces"
        ),
        ExternalTargetDefinition(
            id: .androidStudio,
            displayName: "Android Studio",
            bundleIdentifiers: ["com.google.android.studio"],
            appNames: ["Android Studio.app"],
            commandNames: [],
            isBaselineMacTarget: false,
            fallbackSystemImage: "apps.iphone"
        ),
        ExternalTargetDefinition(
            id: .antigravity,
            displayName: "Antigravity",
            bundleIdentifiers: ["com.google.antigravity", "com.google.Antigravity"],
            appNames: ["Antigravity.app"],
            commandNames: ["antigravity"],
            isBaselineMacTarget: false,
            fallbackSystemImage: "sparkles"
        )
    ]
}

struct ExternalTargetScanner {
    var definitions = ExternalTargetCatalog.definitions
    var applicationDirectories = Self.defaultApplicationDirectories()
    var environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
    var applicationURLForBundleIdentifier: (String) -> URL? = { bundleIdentifier in
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }
    var fileExistsAtPath: (String) -> Bool = { path in
        FileManager.default.fileExists(atPath: path)
    }
    var isExecutableFileAtPath: (String) -> Bool = { path in
        FileManager.default.isExecutableFile(atPath: path)
    }

    func scan() -> [AvailableExternalTarget] {
        definitions.compactMap { definition in
            if definition.isBaselineMacTarget {
                return AvailableExternalTarget(definition: definition, launchReference: .baselineMacTarget)
            }

            if let appURL = detectedAppBundleURL(for: definition) {
                return AvailableExternalTarget(definition: definition, launchReference: .appBundleURL(appURL))
            }

            if let commandPath = detectedCommandPath(for: definition) {
                return AvailableExternalTarget(definition: definition, launchReference: .commandPath(commandPath))
            }

            return nil
        }
    }

    private func detectedAppBundleURL(for definition: ExternalTargetDefinition) -> URL? {
        for bundleIdentifier in definition.bundleIdentifiers {
            if let url = applicationURLForBundleIdentifier(bundleIdentifier) {
                return url
            }
        }

        for directory in applicationDirectories {
            for appName in definition.appNames {
                let url = directory.appendingPathComponent(appName, isDirectory: true)
                if fileExistsAtPath(url.path) {
                    return url
                }
            }
        }

        return nil
    }

    private func detectedCommandPath(for definition: ExternalTargetDefinition) -> String? {
        let searchDirectories = commandSearchDirectories()
        for commandName in definition.commandNames {
            for directory in searchDirectories {
                let path = URL(fileURLWithPath: directory).appendingPathComponent(commandName).path
                if isExecutableFileAtPath(path) {
                    return path
                }
            }
        }
        return nil
    }

    private func commandSearchDirectories() -> [String] {
        let pathDirectories = environmentPath
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
        let defaultDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        return Array(NSOrderedSet(array: pathDirectories + defaultDirectories)) as? [String] ?? pathDirectories + defaultDirectories
    }

    private static func defaultApplicationDirectories() -> [URL] {
        var directories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]

        directories.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true))

        return directories
    }
}

enum ExternalLaunchPlan: Equatable {
    case revealInFinder(URL)
    case command(executablePath: String, arguments: [String])
    case openWithApplication(projectURL: URL, applicationURL: URL)
}

enum ExternalTargetLauncher {
    static func launch(
        _ target: AvailableExternalTarget,
        projectPath: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let plan = launchPlan(for: target, projectPath: projectPath)

        switch plan {
        case .revealInFinder(let projectURL):
            NSWorkspace.shared.activateFileViewerSelecting([projectURL])
            completion(.success(()))

        case .command(let executablePath, let arguments):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            do {
                try process.run()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }

        case .openWithApplication(let projectURL, let applicationURL):
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([projectURL], withApplicationAt: applicationURL, configuration: configuration) { _, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    static func launchPlan(for target: AvailableExternalTarget, projectPath: String) -> ExternalLaunchPlan {
        let projectURL = URL(fileURLWithPath: projectPath)

        switch (target.id, target.launchReference) {
        case (.finder, _):
            return .revealInFinder(projectURL)
        case (.terminal, _):
            return .command(executablePath: "/usr/bin/open", arguments: ["-a", "Terminal", projectPath])
        case (_, .commandPath(let commandPath)):
            return .command(executablePath: commandPath, arguments: [projectPath])
        case (_, .appBundleURL(let appBundleURL)):
            return .openWithApplication(projectURL: projectURL, applicationURL: appBundleURL)
        case (_, .baselineMacTarget):
            return .openWithApplication(projectURL: projectURL, applicationURL: URL(fileURLWithPath: "/Applications/\(target.displayName).app"))
        }
    }
}

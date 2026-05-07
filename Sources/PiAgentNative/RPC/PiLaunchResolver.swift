import Foundation

struct PiLaunchCommand {
    var executableURL: URL
    var arguments: [String]
    var displayName: String
    var diagnostic: String
}

enum PiLaunchResolver {
    static var appFolderURL: URL {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return Bundle.main.bundleURL.deletingLastPathComponent()
        }

        if let executableURL = Bundle.main.executableURL {
            return executableURL.deletingLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static var piMonoURL: URL {
        if let override = ProcessInfo.processInfo.environment["PI_MONO_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        return appFolderURL.appendingPathComponent("pi-mono", isDirectory: true)
    }

    static var piMonoPath: String {
        piMonoURL.path
    }

    static func resolve(customExecutable: String?) -> PiLaunchCommand {
        if let customExecutable, !customExecutable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return command(forExecutableAt: customExecutable, displayName: "Custom pi")
        }

        if let envExecutable = ProcessInfo.processInfo.environment["PI_AGENT_EXECUTABLE"], !envExecutable.isEmpty {
            return command(forExecutableAt: envExecutable, displayName: "PI_AGENT_EXECUTABLE")
        }

        let binary = piMonoURL
            .appendingPathComponent("packages/coding-agent/dist/pi")
            .path
        if FileManager.default.isExecutableFile(atPath: binary) {
            return PiLaunchCommand(
                executableURL: URL(fileURLWithPath: binary),
                arguments: ["--mode", "rpc"],
                displayName: "pi binary",
                diagnostic: binary
            )
        }

        let distCLI = piMonoURL
            .appendingPathComponent("packages/coding-agent/dist/cli.js")
            .path
        if FileManager.default.fileExists(atPath: distCLI) {
            return PiLaunchCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: ["node", distCLI, "--mode", "rpc"],
                displayName: "pi dist CLI",
                diagnostic: "node \(distCLI)"
            )
        }

        let tsx = piMonoURL
            .appendingPathComponent("node_modules/.bin/tsx")
            .path
        let sourceCLI = piMonoURL
            .appendingPathComponent("packages/coding-agent/src/cli.ts")
            .path
        if FileManager.default.isExecutableFile(atPath: tsx), FileManager.default.fileExists(atPath: sourceCLI) {
            return PiLaunchCommand(
                executableURL: URL(fileURLWithPath: tsx),
                arguments: [sourceCLI, "--mode", "rpc"],
                displayName: "pi source CLI",
                diagnostic: "\(tsx) \(sourceCLI)"
            )
        }

        return PiLaunchCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["pi", "--mode", "rpc"],
            displayName: "pi on PATH",
            diagnostic: "pi; expected local checkout at \(piMonoPath)"
        )
    }

    private static func command(forExecutableAt path: String, displayName: String) -> PiLaunchCommand {
        if path.hasSuffix(".js") {
            return PiLaunchCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: ["node", path, "--mode", "rpc"],
                displayName: displayName,
                diagnostic: "node \(path)"
            )
        }

        return PiLaunchCommand(
            executableURL: URL(fileURLWithPath: path),
            arguments: ["--mode", "rpc"],
            displayName: displayName,
            diagnostic: path
        )
    }
}

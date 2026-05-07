import Foundation

struct OAuthLaunchCommand {
    var executableURL: URL
    var arguments: [String]
    var display: String
}

enum OAuthLoginService {
    static func command(providerID: String) -> OAuthLaunchCommand {
        let aiDistCLI = PiLaunchResolver.piMonoURL
            .appendingPathComponent("packages/ai/dist/cli.js")
            .path
        if FileManager.default.fileExists(atPath: aiDistCLI) {
            return OAuthLaunchCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: ["node", aiDistCLI, "login", providerID],
                display: "node \(aiDistCLI) login \(providerID)"
            )
        }

        let tsx = PiLaunchResolver.piMonoURL
            .appendingPathComponent("node_modules/.bin/tsx")
            .path
        let aiSourceCLI = PiLaunchResolver.piMonoURL
            .appendingPathComponent("packages/ai/src/cli.ts")
            .path
        if FileManager.default.isExecutableFile(atPath: tsx), FileManager.default.fileExists(atPath: aiSourceCLI) {
            return OAuthLaunchCommand(
                executableURL: URL(fileURLWithPath: tsx),
                arguments: [aiSourceCLI, "login", providerID],
                display: "\(tsx) \(aiSourceCLI) login \(providerID)"
            )
        }

        return OAuthLaunchCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["npx", "-y", "@mariozechner/pi-ai", "login", providerID],
            display: "npx -y @mariozechner/pi-ai login \(providerID)"
        )
    }

    static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let basePath = environment["PATH"] ?? ""
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(basePath)"
        return environment
    }
}

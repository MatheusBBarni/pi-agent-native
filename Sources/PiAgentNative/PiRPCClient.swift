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

final class PiRPCClient {
    var onEvent: (([String: Any]) -> Void)?
    var onStderr: ((String) -> Void)?
    var onExit: ((Int32) -> Void)?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutBuffer = Data()
    private let parseQueue = DispatchQueue(label: "pi-agent-native.rpc.parse")
    private var generation = 0

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(workspacePath: String, customExecutable: String?) throws -> PiLaunchCommand {
        stop()
        generation += 1
        let currentGeneration = generation

        let launch = PiLaunchResolver.resolve(customExecutable: customExecutable)
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = launch.executableURL
        process.arguments = launch.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath)
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = rpcEnvironment()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.parseQueue.async {
                guard let self, self.generation == currentGeneration else { return }
                self.consumeStdout(data, generation: currentGeneration)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                guard self?.generation == currentGeneration else { return }
                self?.onStderr?(text)
            }
        }

        process.terminationHandler = { [weak self] process in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                guard self?.generation == currentGeneration, self?.process === process else { return }
                self?.process = nil
                self?.stdinPipe = nil
                self?.onExit?(process.terminationStatus)
            }
        }

        try process.run()
        self.process = process
        self.stdinPipe = stdinPipe
        return launch
    }

    func stop() {
        generation += 1
        let runningProcess = process
        process = nil
        stdinPipe = nil
        stdoutBuffer.removeAll()
        runningProcess?.terminate()
    }

    func send(_ command: [String: Any]) throws {
        guard let stdinPipe else {
            throw NSError(domain: "PiRPCClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pi RPC process is not running"])
        }

        var data = try JSONSerialization.data(withJSONObject: command, options: [])
        data.append(0x0a)
        stdinPipe.fileHandleForWriting.write(data)
    }

    private func consumeStdout(_ data: Data, generation: Int) {
        guard generation == self.generation else { return }
        stdoutBuffer.append(data)

        while let newline = stdoutBuffer.firstIndex(of: 0x0a) {
            let lineData = stdoutBuffer[..<newline]
            stdoutBuffer.removeSubrange(...newline)
            guard !lineData.isEmpty else { continue }

            let trimmedData: Data
            if lineData.last == 0x0d {
                trimmedData = Data(lineData.dropLast())
            } else {
                trimmedData = Data(lineData)
            }

            guard
                let object = try? JSONSerialization.jsonObject(with: trimmedData),
                let event = object as? [String: Any]
            else {
                let text = String(data: trimmedData, encoding: .utf8) ?? "<invalid utf8>"
                DispatchQueue.main.async { [weak self] in
                    guard self?.generation == generation else { return }
                    self?.onStderr?("Non-JSON RPC output: \(text)")
                }
                continue
            }

            DispatchQueue.main.async { [weak self] in
                guard self?.generation == generation else { return }
                self?.onEvent?(event)
            }
        }
    }

    private func rpcEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let basePath = environment["PATH"] ?? ""
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(basePath)"
        environment["NO_COLOR"] = "1"
        environment["FORCE_COLOR"] = "0"
        environment["PI_AGENT_NATIVE"] = "1"
        return environment
    }
}

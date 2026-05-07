import Foundation

final class PiProcessSupervisor {
    typealias StdoutHandler = (_ data: Data, _ generation: Int) -> Void
    typealias StderrHandler = (_ text: String, _ generation: Int) -> Void
    typealias ExitHandler = (_ status: Int32, _ generation: Int) -> Void

    private var process: Process?
    private var stdinPipe: Pipe?
    private var generation = 0

    var currentGeneration: Int {
        generation
    }

    var isRunning: Bool {
        process?.isRunning == true
    }

    @discardableResult
    func start(
        workspace: URL,
        command: PiLaunchCommand,
        onStdout: @escaping StdoutHandler,
        onStderr: @escaping StderrHandler,
        onExit: @escaping ExitHandler
    ) throws -> Int {
        stop()
        generation += 1
        let currentGeneration = generation

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = workspace
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = rpcEnvironment()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, self?.generation == currentGeneration else { return }
            onStdout(data, currentGeneration)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard
                !data.isEmpty,
                self?.generation == currentGeneration,
                let text = String(data: data, encoding: .utf8)
            else { return }
            onStderr(text, currentGeneration)
        }

        process.terminationHandler = { [weak self] process in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            guard self?.generation == currentGeneration, self?.process === process else { return }
            self?.process = nil
            self?.stdinPipe = nil
            onExit(process.terminationStatus, currentGeneration)
        }

        try process.run()
        self.process = process
        self.stdinPipe = stdinPipe
        return currentGeneration
    }

    @discardableResult
    func restart(
        workspace: URL,
        command: PiLaunchCommand,
        onStdout: @escaping StdoutHandler,
        onStderr: @escaping StderrHandler,
        onExit: @escaping ExitHandler
    ) throws -> Int {
        try start(
            workspace: workspace,
            command: command,
            onStdout: onStdout,
            onStderr: onStderr,
            onExit: onExit
        )
    }

    func stop() {
        generation += 1
        let runningProcess = process
        process = nil
        stdinPipe = nil
        runningProcess?.terminate()
    }

    func write(_ data: Data) throws {
        guard let stdinPipe else {
            throw NSError(domain: "PiRPCClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pi RPC process is not running"])
        }

        stdinPipe.fileHandleForWriting.write(data)
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

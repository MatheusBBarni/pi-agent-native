import Foundation

enum NativeAuthStore {
    static var authDirectoryURL: URL {
        if let override = ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".pi", isDirectory: true)
            .appendingPathComponent("agent", isDirectory: true)
    }

    static var authFileURL: URL {
        authDirectoryURL.appendingPathComponent("auth.json")
    }

    static func saveAPIKey(provider: String, apiKey: String) throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "NativeAuthStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "API key cannot be empty"])
        }

        try FileManager.default.createDirectory(at: authDirectoryURL, withIntermediateDirectories: true)

        var auth = try loadAuthObject()
        auth[provider] = [
            "type": "api_key",
            "key": trimmedKey
        ]

        let data = try JSONSerialization.data(withJSONObject: auth, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: authFileURL, options: [.atomic])
        chmod(authFileURL.path, 0o600)
    }

    private static func loadAuthObject() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: authFileURL)
        guard !data.isEmpty else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }
}

final class OAuthLoginRunner: ObservableObject {
    @Published var output = ""
    @Published var isRunning = false
    @Published var exitStatus: Int32?
    @Published var lastURL: URL?

    private var process: Process?
    private var stdinPipe: Pipe?

    func start(provider: LoginProvider) {
        stop()
        output = ""
        exitStatus = nil
        lastURL = nil

        let command = OAuthLoginService.command(providerID: provider.id)
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = NativeAuthStore.authDirectoryURL
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = OAuthLoginService.processEnvironment()

        let consume: (FileHandle) -> Void = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.append(text)
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = consume
        stderrPipe.fileHandleForReading.readabilityHandler = consume

        process.terminationHandler = { [weak self] process in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.exitStatus = process.terminationStatus
                self?.append("\nLogin process exited with status \(process.terminationStatus).\n")
            }
        }

        do {
            try FileManager.default.createDirectory(at: NativeAuthStore.authDirectoryURL, withIntermediateDirectories: true)
            try process.run()
            self.process = process
            self.stdinPipe = stdinPipe
            isRunning = true
            append("Running \(command.display)\n\n")
        } catch {
            append("Failed to start login: \(error.localizedDescription)\n")
        }
    }

    func sendInput(_ text: String) {
        guard let stdinPipe else { return }
        var data = Data(text.utf8)
        data.append(0x0a)
        stdinPipe.fileHandleForWriting.write(data)
    }

    func stop() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        isRunning = false
    }

    private func append(_ text: String) {
        output += text
        if let url = firstURL(in: text) {
            lastURL = url
        }
    }

    private func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, range: range)?.url
    }

}

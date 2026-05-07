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
        try saveAPIKey(provider: provider, apiKey: apiKey, authFileURL: authFileURL)
    }

    static func saveAPIKey(provider: String, apiKey: String, authFileURL: URL) throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "NativeAuthStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "API key cannot be empty"])
        }

        try FileManager.default.createDirectory(at: authFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var auth = try loadAuthObject(from: authFileURL)
        auth[provider] = [
            "type": "api_key",
            "key": trimmedKey
        ]

        try writeAuthObject(auth, to: authFileURL)
    }

    static func removeCredential(provider: String) throws {
        try removeCredential(provider: provider, authFileURL: authFileURL)
    }

    static func removeCredential(provider: String, authFileURL: URL) throws {
        var auth = try loadAuthObject(from: authFileURL)
        auth.removeValue(forKey: provider)
        try writeAuthObject(auth, to: authFileURL)
    }

    static func credentialSnapshot() -> AuthCredentialSnapshot {
        (try? credentialSnapshot(authFileURL: authFileURL)) ?? AuthCredentialSnapshot()
    }

    static func credentialSnapshot(authFileURL: URL) throws -> AuthCredentialSnapshot {
        let auth = try loadAuthObject(from: authFileURL)
        var credentialsByProvider: [String: AuthCredentialKind] = [:]

        for (provider, value) in auth {
            guard let credential = value as? [String: Any] else {
                credentialsByProvider[provider] = .other(nil)
                continue
            }

            switch PiRPCValue.string(credential["type"]) {
            case "api_key":
                credentialsByProvider[provider] = .apiKey
            case "oauth":
                credentialsByProvider[provider] = .oauth
            case let type:
                credentialsByProvider[provider] = .other(type)
            }
        }

        return AuthCredentialSnapshot(credentialsByProvider: credentialsByProvider)
    }

    static func hasCredential(provider: String) -> Bool {
        ((try? loadAuthObject())?[provider] != nil) == true
    }

    private static func loadAuthObject() throws -> [String: Any] {
        try loadAuthObject(from: authFileURL)
    }

    private static func loadAuthObject(from authFileURL: URL) throws -> [String: Any] {
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

    private static func writeAuthObject(_ auth: [String: Any], to authFileURL: URL) throws {
        try FileManager.default.createDirectory(at: authFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: auth, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: authFileURL, options: [.atomic])
        chmod(authFileURL.path, 0o600)
    }
}

final class OAuthLoginRunner: ObservableObject {
    @Published var output = ""
    @Published var isRunning = false
    @Published var exitStatus: Int32?
    @Published var lastURL: URL?
    @Published var currentProvider: LoginProvider?
    @Published var currentAttemptID: UUID?

    var onCompletion: ((LoginProvider, UUID, Int32) -> Void)?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var loginURLDetector = ProviderLoginURLDetector()

    @discardableResult
    func start(provider: LoginProvider) -> Result<UUID, Error> {
        stop()
        output = ""
        exitStatus = nil
        lastURL = nil
        loginURLDetector.reset()
        currentProvider = provider
        let attemptID = UUID()
        currentAttemptID = attemptID

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
            let stdoutRemainder = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrRemainder = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.currentAttemptID == attemptID else { return }
                self.append(stdoutRemainder)
                self.append(stderrRemainder)
                self.detectFinalLoginURL()
                self.isRunning = false
                self.exitStatus = process.terminationStatus
                self.append("\nLogin process exited with status \(process.terminationStatus).\n")
                self.onCompletion?(provider, attemptID, process.terminationStatus)
            }
        }

        do {
            try FileManager.default.createDirectory(at: NativeAuthStore.authDirectoryURL, withIntermediateDirectories: true)
            try process.run()
            self.process = process
            self.stdinPipe = stdinPipe
            isRunning = true
            append("Running \(command.display)\n\n")
            return .success(attemptID)
        } catch {
            currentProvider = nil
            currentAttemptID = nil
            append("Failed to start login: \(error.localizedDescription)\n")
            return .failure(error)
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

    private func append(_ data: Data) {
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
        append(text)
    }

    private func append(_ text: String) {
        guard !text.isEmpty else { return }
        output += text
        if let url = loginURLDetector.append(text) {
            lastURL = url
        }
    }

    private func detectFinalLoginURL() {
        if let url = loginURLDetector.detectFinalURL() {
            lastURL = url
        }
    }

}

struct ProviderLoginURLDetector: Equatable {
    private var accumulatedOutput = ""

    mutating func reset() {
        accumulatedOutput = ""
    }

    mutating func append(_ text: String) -> URL? {
        accumulatedOutput += text
        return Self.latestCompleteWebURL(in: accumulatedOutput, allowTerminalURL: false)
    }

    func detectFinalURL() -> URL? {
        Self.latestCompleteWebURL(in: accumulatedOutput, allowTerminalURL: true)
    }

    static func latestCompleteWebURL(in text: String, allowTerminalURL: Bool) -> URL? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else {
            return nil
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, range: fullRange)
        return matches.compactMap { match -> URL? in
            guard let url = match.url,
                  isWebURL(url),
                  isCompleteMatch(match.range, in: text, allowTerminalURL: allowTerminalURL)
            else {
                return nil
            }
            return url
        }.last
    }

    private static func isWebURL(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https":
            return true
        default:
            return false
        }
    }

    private static func isCompleteMatch(
        _ nsRange: NSRange,
        in text: String,
        allowTerminalURL: Bool
    ) -> Bool {
        guard let range = Range(nsRange, in: text) else { return false }

        if range.upperBound < text.endIndex {
            return isBoundary(text[range.upperBound])
        }

        return allowTerminalURL
    }

    private static func isBoundary(_ character: Character) -> Bool {
        if character.isWhitespace || character.isNewline {
            return true
        }

        return [")", "]", "}", ">", "\"", "'", "`", ".", ",", ";", ":"].contains(character)
    }
}

struct ProviderLoginURLOpeningTracker: Equatable {
    private var openedURLs: Set<URL> = []

    mutating func reset() {
        openedURLs.removeAll()
    }

    mutating func shouldOpen(_ url: URL) -> Bool {
        openedURLs.insert(url).inserted
    }
}

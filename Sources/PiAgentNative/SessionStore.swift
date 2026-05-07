import Foundation

struct AppPersistedState: Codable {
    var projects: [ProjectItem] = []
    var sessions: [StoredSession] = []
    var selectedProjectPath: String?
    var selectedSessionID: String?
}

enum SessionStore {
    static var storeURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PiAgentNative", isDirectory: true)
        return directory.appendingPathComponent("sessions.json")
    }

    static func load() -> AppPersistedState {
        do {
            let url = storeURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                return AppPersistedState()
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppPersistedState.self, from: data)
        } catch {
            return AppPersistedState()
        }
    }

    static func save(_ state: AppPersistedState) {
        do {
            let url = storeURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: url, options: [.atomic])
        } catch {
            // The UI remains usable if persistence fails.
        }
    }
}

import Foundation

enum PiRPCTransportError: Error, Equatable, LocalizedError {
    case nonJSONOutput(String)
    case invalidTopLevel(String)

    var errorDescription: String? {
        switch self {
        case .nonJSONOutput(let text):
            return "Non-JSON RPC output: \(text)"
        case .invalidTopLevel(let text):
            return "Invalid RPC record: \(text)"
        }
    }
}

final class JSONLTransport {
    private var stdoutBuffer = Data()

    func reset() {
        stdoutBuffer.removeAll()
    }

    func encode(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: object, options: [])
        data.append(0x0a)
        return data
    }

    func consume(_ data: Data) -> [Result<[String: Any], PiRPCTransportError>] {
        stdoutBuffer.append(data)
        var records: [Result<[String: Any], PiRPCTransportError>] = []

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

            records.append(decode(trimmedData))
        }

        return records
    }

    private func decode(_ data: Data) -> Result<[String: Any], PiRPCTransportError> {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                let text = String(data: data, encoding: .utf8) ?? "<invalid utf8>"
                return .failure(.invalidTopLevel(text))
            }
            return .success(dictionary)
        } catch {
            let text = String(data: data, encoding: .utf8) ?? "<invalid utf8>"
            return .failure(.nonJSONOutput(text))
        }
    }
}

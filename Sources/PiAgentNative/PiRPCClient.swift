import Foundation

final class PiRPCClient {
    var onEvent: ((PiRPCEvent) -> Void)?
    var onStderr: ((String) -> Void)?
    var onExit: ((Int32) -> Void)?

    private let supervisor = PiProcessSupervisor()
    private let transport = JSONLTransport()
    private let parseQueue = DispatchQueue(label: "pi-agent-native.rpc.parse")

    var isRunning: Bool {
        supervisor.isRunning
    }

    func start(workspacePath: String, customExecutable: String?) throws -> PiLaunchCommand {
        transport.reset()
        let launch = PiLaunchResolver.resolve(customExecutable: customExecutable)
        try supervisor.start(
            workspace: URL(fileURLWithPath: workspacePath),
            command: launch,
            onStdout: { [weak self] data, generation in
                self?.parseQueue.async {
                    self?.consumeStdout(data, generation: generation)
                }
            },
            onStderr: { [weak self] text, generation in
                DispatchQueue.main.async {
                    guard self?.supervisor.currentGeneration == generation else { return }
                    self?.onStderr?(text)
                }
            },
            onExit: { [weak self] status, generation in
                DispatchQueue.main.async {
                    guard self?.supervisor.currentGeneration == generation else { return }
                    self?.onExit?(status)
                }
            }
        )
        return launch
    }

    func stop() {
        supervisor.stop()
        transport.reset()
    }

    func send(_ command: PiRPCCommand) throws {
        try send(command.dictionary)
    }

    func send(_ command: [String: Any]) throws {
        try supervisor.write(transport.encode(command))
    }

    private func consumeStdout(_ data: Data, generation: Int) {
        guard supervisor.currentGeneration == generation else { return }
        let records = transport.consume(data)
        for record in records {
            switch record {
            case .success(let payload):
                let event = PiRPCEvent.decode(payload)
                DispatchQueue.main.async { [weak self] in
                    guard self?.supervisor.currentGeneration == generation else { return }
                    self?.onEvent?(event)
                }
            case .failure(let error):
                DispatchQueue.main.async { [weak self] in
                    guard self?.supervisor.currentGeneration == generation else { return }
                    self?.onStderr?(error.localizedDescription)
                }
            }
        }
    }
}

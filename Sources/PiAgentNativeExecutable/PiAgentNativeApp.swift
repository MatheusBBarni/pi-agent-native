import SwiftUI
import PiAgentNativeCore

@main
struct PiAgentNativeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(model)
                .frame(minWidth: 1160, minHeight: 760)
                .background(Theme.appBackground)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Pi") {
                Button(model.isConnected ? "Stop Pi RPC" : "Start Pi RPC") {
                    if model.isConnected {
                        model.stop()
                    } else {
                        model.start()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("New Session") {
                    model.newSession()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}

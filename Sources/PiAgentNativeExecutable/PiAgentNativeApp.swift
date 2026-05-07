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
                Button("New chat") {
                    model.performAppAction(.newChat)
                }
                .keybindingShortcut(.newChat)
                .disabled(!model.canPerformAppAction(.newChat))

                Button("Open project") {
                    model.performAppAction(.openProject)
                }
                .keybindingShortcut(.openProject)

                Divider()

                Button("Focus composer") {
                    model.performAppAction(.focusComposer)
                }
                .keybindingShortcut(.focusComposer)

                Button("Refresh state") {
                    model.performAppAction(.refreshState)
                }
                .keybindingShortcut(.refreshState)
                .disabled(!model.canPerformAppAction(.refreshState))

                Divider()

                Button("Open process log") {
                    model.performAppAction(.openProcessLog)
                }
                .keybindingShortcut(.openProcessLog)

                Button("Open Keybinding Help") {
                    model.performAppAction(.openKeybindingHelp)
                }
                .keybindingShortcut(.openKeybindingHelp)

                Button("Open settings") {
                    model.performAppAction(.openSettings)
                }
                .keybindingShortcut(.openSettings)

                Divider()

                Button("Toggle sidebar") {
                    model.performAppAction(.toggleSidebar)
                }
                .keybindingShortcut(.toggleSidebar)

                Button("Toggle inspector") {
                    model.performAppAction(.toggleInspector)
                }
                .keybindingShortcut(.toggleInspector)

                Divider()

                Button(model.isConnected ? "Stop Pi RPC" : "Start Pi RPC") {
                    if model.isConnected {
                        model.stop()
                    } else {
                        model.start()
                    }
                }
            }
        }
    }
}

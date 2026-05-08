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
                Button(DefaultKeymap.title(for: .newChat) ?? "New chat") {
                    model.performAppAction(.newChat)
                }
                .keybindingShortcut(.newChat)
                .disabled(!model.canPerformAppAction(.newChat))

                Button(DefaultKeymap.title(for: .openProject) ?? "Open project") {
                    model.performAppAction(.openProject)
                }
                .keybindingShortcut(.openProject)
                .disabled(!model.canPerformAppAction(.openProject))

                Button(DefaultKeymap.title(for: .openCommandPalette) ?? "Open Command Palette") {
                    model.performAppAction(.openCommandPalette)
                }
                .keybindingShortcut(.openCommandPalette)
                .disabled(!model.canPerformAppAction(.openCommandPalette))

                Divider()

                Button(DefaultKeymap.title(for: .focusComposer) ?? "Focus composer") {
                    model.performAppAction(.focusComposer)
                }
                .keybindingShortcut(.focusComposer)
                .disabled(!model.canPerformAppAction(.focusComposer))

                Button(DefaultKeymap.title(for: .refreshState) ?? "Refresh state") {
                    model.performAppAction(.refreshState)
                }
                .keybindingShortcut(.refreshState)
                .disabled(!model.canPerformAppAction(.refreshState))

                Divider()

                Button(DefaultKeymap.title(for: .openProcessLog) ?? "Open process log") {
                    model.performAppAction(.openProcessLog)
                }
                .keybindingShortcut(.openProcessLog)
                .disabled(!model.canPerformAppAction(.openProcessLog))

                Button(DefaultKeymap.title(for: .openKeybindingHelp) ?? "Open Keyboard Shortcuts") {
                    model.performAppAction(.openKeybindingHelp)
                }
                .keybindingShortcut(.openKeybindingHelp)
                .disabled(!model.canPerformAppAction(.openKeybindingHelp))

                Button(DefaultKeymap.title(for: .openSettings) ?? "Open settings") {
                    model.performAppAction(.openSettings)
                }
                .keybindingShortcut(.openSettings)
                .disabled(!model.canPerformAppAction(.openSettings))

                Divider()

                Button(DefaultKeymap.title(for: .toggleSidebar) ?? "Toggle sidebar") {
                    model.performAppAction(.toggleSidebar)
                }
                .keybindingShortcut(.toggleSidebar)
                .disabled(!model.canPerformAppAction(.toggleSidebar))

                Button(DefaultKeymap.title(for: .toggleInspector) ?? "Toggle inspector") {
                    model.performAppAction(.toggleInspector)
                }
                .keybindingShortcut(.toggleInspector)
                .disabled(!model.canPerformAppAction(.toggleInspector))

                Divider()

                Button("Start Pi RPC") {
                    model.start()
                }
                .disabled(model.isConnected)

                Button("Stop Pi RPC") {
                    model.stop()
                }
                .disabled(!model.isConnected)
            }
        }
    }
}

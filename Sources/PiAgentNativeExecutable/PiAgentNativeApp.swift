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
                Button(model.localizedTitle(for: .newChat)) {
                    model.performAppAction(.newChat)
                }
                .keybindingShortcut(.newChat)
                .disabled(!model.canPerformAppAction(.newChat))

                Button(model.localizedTitle(for: .openProject)) {
                    model.performAppAction(.openProject)
                }
                .keybindingShortcut(.openProject)
                .disabled(!model.canPerformAppAction(.openProject))

                Button(model.localizedTitle(for: .openCommandPalette)) {
                    model.performAppAction(.openCommandPalette)
                }
                .keybindingShortcut(.openCommandPalette)
                .disabled(!model.canPerformAppAction(.openCommandPalette))

                Divider()

                Button(model.localizedTitle(for: .focusComposer)) {
                    model.performAppAction(.focusComposer)
                }
                .keybindingShortcut(.focusComposer)
                .disabled(!model.canPerformAppAction(.focusComposer))

                Button(model.localizedTitle(for: .refreshState)) {
                    model.performAppAction(.refreshState)
                }
                .keybindingShortcut(.refreshState)
                .disabled(!model.canPerformAppAction(.refreshState))

                Divider()

                Button(model.localizedTitle(for: .openProcessLog)) {
                    model.performAppAction(.openProcessLog)
                }
                .keybindingShortcut(.openProcessLog)
                .disabled(!model.canPerformAppAction(.openProcessLog))

                Button(model.localizedTitle(for: .openKeybindingHelp)) {
                    model.performAppAction(.openKeybindingHelp)
                }
                .keybindingShortcut(.openKeybindingHelp)
                .disabled(!model.canPerformAppAction(.openKeybindingHelp))

                Button(model.localizedTitle(for: .openSettings)) {
                    model.performAppAction(.openSettings)
                }
                .keybindingShortcut(.openSettings)
                .disabled(!model.canPerformAppAction(.openSettings))

                Divider()

                Button(model.localizedTitle(for: .toggleSidebar)) {
                    model.performAppAction(.toggleSidebar)
                }
                .keybindingShortcut(.toggleSidebar)
                .disabled(!model.canPerformAppAction(.toggleSidebar))

                Button(model.localizedTitle(for: .toggleInspector)) {
                    model.performAppAction(.toggleInspector)
                }
                .keybindingShortcut(.toggleInspector)
                .disabled(!model.canPerformAppAction(.toggleInspector))

                Divider()

                Button(model.startPiRPCMenuTitle) {
                    model.start()
                }
                .disabled(model.isConnected)

                Button(model.stopPiRPCMenuTitle) {
                    model.stop()
                }
                .disabled(!model.isConnected)
            }
        }
    }
}

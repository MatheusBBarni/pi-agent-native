import SwiftUI
import AppKit

public struct AppShellView: View {
    @EnvironmentObject private var model: AppModel

    public init() {}

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: model.isSidebarVisible ? 268 : 0)
                    .opacity(model.isSidebarVisible ? 1 : 0)
                    .allowsHitTesting(model.isSidebarVisible)
                    .clipped()

                Divider()
                    .overlay(Theme.border)
                    .frame(width: model.isSidebarVisible ? 1 : 0)
                    .opacity(model.isSidebarVisible ? 1 : 0)
                    .clipped()

                ChatSurfaceView()
                    .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)

                InspectorView()
                    .frame(width: model.isInspectorVisible ? 280 : 0)
                    .opacity(model.isInspectorVisible ? 1 : 0)
                    .allowsHitTesting(model.isInspectorVisible)
                    .clipped()
            }
            .disabled(model.hasActiveModal)
            .accessibilityHidden(model.hasActiveModal)

            if model.isShowingLogin {
                ModalBackdrop {
                    model.performAppAction(.closeActiveModal)
                } content: {
                    LoginSheetView()
                        .environmentObject(model)
                }
            }

            if model.isShowingModelPicker {
                ModalBackdrop {
                    model.performAppAction(.closeActiveModal)
                } content: {
                    ModelPickerSheetView()
                        .environmentObject(model)
                }
            }

            if model.isShowingProcessLog {
                ModalBackdrop {
                    model.performAppAction(.closeActiveModal)
                } content: {
                    ProcessLogSheetView()
                        .environmentObject(model)
                }
            }

            if model.isShowingSettings {
                ModalBackdrop {
                    model.performAppAction(.closeActiveModal)
                } content: {
                    SettingsSheetView()
                        .environmentObject(model)
                }
            }

            if model.isShowingKeybindingHelp {
                ModalBackdrop {
                    model.performAppAction(.closeActiveModal)
                } content: {
                    KeybindingHelpView()
                        .environmentObject(model)
                }
            }

            if model.isShowingCommandPalette {
                ModalBackdrop {
                    model.closeCommandPalette()
                } content: {
                    CommandPaletteView()
                        .environmentObject(model)
                }
            }

            if let request = model.extensionUIRouter.activeRequest {
                ModalBackdrop {
                    model.cancelExtensionUIRequest()
                } content: {
                    ExtensionUIDialogView(request: request)
                        .environmentObject(model)
                }
            }
        }
        .foregroundStyle(Theme.primaryText)
        .background(Theme.windowBackground)
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.uiFontSize, model.uiFontSize)
        .preferredColorScheme(model.themeVariant.colorScheme)
        .background(WindowConfigurator())
        .background(WindowKeyboardHandler(model: model))
        .onAppear {
            if !model.isConnected, model.selectedProject != nil {
                model.start()
            }
        }
    }
}

struct CommandPaletteView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var isSearchFocused: Bool

    private var items: [CommandPaletteItem] {
        model.filteredCommandPaletteItems(query: model.commandPaletteQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .uiFont(size: 17, weight: .semibold)
                    .foregroundStyle(Theme.tertiaryText)

                TextField("Search commands", text: $model.commandPaletteQuery)
                    .textFieldStyle(.plain)
                    .uiFont(size: 18, weight: .medium)
                    .focused($isSearchFocused)

                Button {
                    model.closeCommandPalette()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help(DefaultKeymap.helpText(for: .closeActiveModal) ?? "Close")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Theme.composerBackground)

            Divider()
                .overlay(Theme.border)

            if items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No commands found")
                        .uiFont(size: 14, weight: .medium)
                    Text("Try another command, project, session, model, or app name.")
                        .uiFont(size: 13)
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { item in
                            CommandPaletteRow(
                                item: item,
                                isHighlighted: item.id == model.commandPaletteHighlightedItemID
                            )
                            .environmentObject(model)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: CGFloat(12 * 48))
                .scrollIndicators(.visible)
            }
        }
        .frame(width: 680)
        .background(Theme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.border.opacity(0.9), lineWidth: 1)
        )
        .background(CommandPaletteKeyboardHandler(model: model))
        .onAppear {
            isSearchFocused = true
            model.refreshCommandPaletteHighlight()
        }
        .onChange(of: model.commandPaletteQuery) { _, _ in
            model.refreshCommandPaletteHighlight()
        }
    }
}

private struct CommandPaletteRow: View {
    @EnvironmentObject private var model: AppModel
    let item: CommandPaletteItem
    let isHighlighted: Bool

    var body: some View {
        Button {
            guard item.availability.isEnabled else { return }
            model.runCommandPaletteItem(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.iconSystemName ?? "command")
                    .uiFont(size: 15, weight: .medium)
                    .foregroundStyle(item.availability.isEnabled ? Theme.secondaryText : Theme.tertiaryText.opacity(0.65))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .uiFont(size: 14, weight: .medium)
                        .foregroundStyle(item.availability.isEnabled ? Theme.primaryText : Theme.secondaryText)
                        .lineLimit(1)

                    if let detailText {
                        Text(detailText)
                            .uiFont(size: 12)
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                if let keybindingLabel = item.keybindingLabel {
                    Text(keybindingLabel)
                        .uiFont(size: 12, weight: .medium)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.elevatedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHighlighted ? Theme.sidebarSelection : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!item.availability.isEnabled)
        .onHover { isHovering in
            if isHovering {
                model.commandPaletteHighlightedItemID = item.id
            }
        }
        .accessibilityLabel(item.title)
        .accessibilityHint(detailText ?? item.title)
    }

    private var detailText: String? {
        item.availability.disabledReason ?? item.subtitle
    }
}

struct CommandPaletteKeyboardHandler: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.window = view.window
        }
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.model = model
        DispatchQueue.main.async {
            context.coordinator.window = nsView.window
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    final class Coordinator {
        weak var window: NSWindow?
        var model: AppModel
        private var monitor: Any?

        init(model: AppModel) {
            self.model = model
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard event.window === window else { return event }
                guard event.normalizedKeybindingModifiers.isEmpty else { return event }

                let handled = MainActor.assumeIsolated {
                    self.handle(event)
                }
                return handled ? nil : event
            }
        }

        @MainActor
        private func handle(_ event: NSEvent) -> Bool {
            guard model.isShowingCommandPalette else { return false }

            switch event.keyCode {
            case 125:
                model.moveCommandPaletteHighlight(by: 1)
                return true
            case 126:
                model.moveCommandPaletteHighlight(by: -1)
                return true
            case 36, 48, 76:
                model.runHighlightedCommandPaletteItem()
                return true
            case 53:
                model.closeCommandPalette()
                return true
            default:
                return false
            }
        }
    }
}

struct ModalBackdrop<Content: View>: View {
    let close: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            content
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 20)
                .onTapGesture {}
        }
    }
}

enum WindowActions {
    static func zoomKeyWindow() {
        (NSApp.keyWindow ?? NSApp.mainWindow)?.performZoom(nil)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarTitlebarControls()
                .frame(height: 56)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: WindowActions.zoomKeyWindow)

            SidebarCommand(icon: "square.and.pencil", title: "New chat", actionID: .newChat) {
                model.performAppAction(.newChat)
            }
            SidebarCommand(icon: "folder.badge.plus", title: "Open project", actionID: .openProject) {
                model.performAppAction(.openProject)
            }

            VStack(alignment: .leading, spacing: 0) {
                SmallCapsLabel(title: "Projects")
                    .padding(.horizontal, 14)
                    .padding(.top, 26)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(model.projects) { project in
                            ProjectSidebarRow(project: project)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.visible)
            }

            Spacer()

            SidebarCommand(icon: "list.bullet.rectangle", title: "Process log", actionID: .openProcessLog) {
                model.performAppAction(.openProcessLog)
            }
            SidebarCommand(icon: "keyboard", title: "Help", actionID: .openKeybindingHelp) {
                model.performAppAction(.openKeybindingHelp)
            }
            SidebarCommand(icon: "key", title: "Login") {
                model.isShowingLogin = true
            }
            SidebarCommand(icon: "gearshape", title: "Settings", actionID: .openSettings) {
                model.performAppAction(.openSettings)
            }
                .padding(.bottom, 14)
        }
        .background(Theme.sidebarBackground)
    }
}

struct ProjectSidebarRow: View {
    @EnvironmentObject private var model: AppModel
    let project: ProjectItem

    private var isSelected: Bool {
        project.id == model.selectedProjectID
    }

    private var isExpanded: Bool {
        model.expandedProjectIDs.contains(project.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                model.toggleProject(project)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .uiFont(size: 14)
                        .frame(width: 18)
                    Text(project.name)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Theme.sidebarSelection : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(model.sessionsForProject(project)) { session in
                    Button {
                        model.switchSession(session)
                    } label: {
                        SidebarSessionRow(
                            title: session.title,
                            isSelected: session.id == model.selectedSessionID
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 28)
                }
            }
        }
    }
}

struct SidebarTitlebarControls: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            HeaderIconButton(
                systemImage: "sidebar.left",
                title: "Toggle sidebar",
                actionID: .toggleSidebar,
                isEnabled: model.canPerformAppAction(.toggleSidebar),
                disabledHelp: "Close active modal first"
            ) {
                model.performAppAction(.toggleSidebar)
            }
            HeaderIconButton(
                systemImage: "chevron.left",
                title: "Previous session",
                isEnabled: model.canNavigateToPreviousSession(),
                disabledHelp: model.previousSessionHelpText()
            ) {
                model.navigateToPreviousSession()
            }
            .padding(.leading, 16)
            HeaderIconButton(
                systemImage: "chevron.right",
                title: "Next session",
                isEnabled: model.canNavigateToNextSession(),
                disabledHelp: model.nextSessionHelpText()
            ) {
                model.navigateToNextSession()
            }
        }
        .uiFont(size: 14, weight: .medium)
        .padding(.horizontal, 14)
        .padding(.leading, 98)
    }
}

struct HeaderIconButton: View {
    let systemImage: String
    let title: String
    var actionID: AppActionID?
    var isEnabled: Bool
    var disabledHelp: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 16, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? Theme.tertiaryText : Theme.tertiaryText.opacity(0.45))
        .help(helpText)
        .accessibilityLabel(title)
        .accessibilityHint(helpText)
    }

    private var helpText: String {
        if !isEnabled, let disabledHelp {
            return disabledHelp
        }

        if let actionID {
            return DefaultKeymap.helpText(for: actionID, title: title) ?? title
        }

        return title
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
    }
}

struct SidebarCommand: View {
    let icon: String
    let title: String
    var actionID: AppActionID?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .uiFont(size: 15)
                    .frame(width: 18)
                Text(title)
                    .uiFont(size: 15)
                Spacer()
            }
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var helpText: String {
        guard let actionID else { return title }
        return DefaultKeymap.helpText(for: actionID, title: title) ?? title
    }
}

struct KeybindingHelpView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Keyboard Shortcuts")
                    .uiFont(size: 22, weight: .semibold)
                Spacer()
                Button {
                    model.performAppAction(.closeActiveModal)
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(DefaultKeymap.helpText(for: .closeActiveModal) ?? "Close active modal")
            }

            VStack(spacing: 16) {
                ForEach(KeybindingHelpGroup.allCases, id: \.self) { group in
                    KeybindingHelpSection(group: group)
                }
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Theme.panelBackground)
    }
}

struct KeybindingHelpSection: View {
    let group: KeybindingHelpGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallCapsLabel(title: group.rawValue)

            VStack(spacing: 0) {
                ForEach(DefaultKeymap.definitions(in: group)) { definition in
                    HStack(spacing: 14) {
                        Text(definition.title)
                            .uiFont(size: 14)
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Text(definition.displayLabel)
                            .uiFont(size: 13, weight: .medium)
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.elevatedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .frame(minHeight: 30)
                }
            }
        }
    }
}

struct WindowKeyboardHandler: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.window = view.window
        }
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.model = model
        DispatchQueue.main.async {
            context.coordinator.window = nsView.window
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    final class Coordinator {
        weak var window: NSWindow?
        var model: AppModel
        private var monitor: Any?

        init(model: AppModel) {
            self.model = model
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard event.window === window else { return event }
                guard let escapeDefinition = DefaultKeymap.firstDefinition(for: .closeActiveModal),
                      escapeDefinition.matches(event) else {
                    return event
                }
                let handled = MainActor.assumeIsolated {
                    self.model.handleEscapeKey()
                }
                return handled ? nil : event
            }
        }
    }
}

struct SidebarSessionRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .uiFont(size: 14, weight: .medium)
            .foregroundStyle(Theme.primaryText)
            .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Theme.sidebarSelection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
#Preview("App Shell") {
    AppShellView()
        .environmentObject(previewAppModel())
        .frame(width: 1320, height: 860)
}

@MainActor
private func previewAppModel() -> AppModel {
    let model = AppModel()
    let project = ProjectItem(name: "pi-agent-native", path: "/Users/matheusbbarni/projects/pi-agent-native")
    let session = StoredSession(
        id: "preview-session",
        projectPath: project.path,
        projectName: project.name,
        title: "Review window preview",
        status: "Ready",
        sessionFile: "/tmp/preview-session.json",
        updatedAt: .now
    )

    model.projects = [project]
    model.selectedProjectID = project.id
    model.expandedProjectIDs = [project.id]
    model.sessions = [session]
    model.selectedSessionID = session.id
    model.workspacePath = project.path
    model.isConnected = true
    model.statusText = "Ready"
    model.launchDetail = "Preview data"
    model.modelName = "openai/gpt-5"
    model.thinkingLevel = "high"
    model.sessionTitle = session.title
    model.messages = [
        ChatMessage(
            role: .user,
            title: "You",
            text: "Configure a realistic SwiftUI preview for the macOS shell."
        ),
        ChatMessage(
            role: .assistant,
            title: "π",
            text: "The preview now renders the sidebar, chat surface, and inspector with seeded sample state."
        )
    ]
    model.tools = [
        ToolActivity(
            id: "preview-tool",
            name: "apply_patch",
            summary: "Add AppShellView preview",
            output: "Preview configuration inserted successfully.",
            isRunning: false,
            isError: false
        )
    ]
    model.eventLog = [
        EventLog(title: "preview", detail: "Loaded sample workspace and session state")
    ]

    return model
}

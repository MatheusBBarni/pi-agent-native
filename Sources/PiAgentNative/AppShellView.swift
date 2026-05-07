import SwiftUI
import AppKit

public struct AppShellView: View {
    @EnvironmentObject private var model: AppModel

    public init() {}

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: 268)

                Divider()
                    .overlay(Theme.border)

                ChatSurfaceView()
                    .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)

                InspectorView()
                    .frame(width: 280)
            }

            if model.isShowingLogin {
                ModalBackdrop {
                    model.isShowingLogin = false
                } content: {
                    LoginSheetView()
                        .environmentObject(model)
                }
            }

            if model.isShowingModelPicker {
                ModalBackdrop {
                    model.isShowingModelPicker = false
                } content: {
                    ModelPickerSheetView()
                        .environmentObject(model)
                }
            }

            if model.isShowingProcessLog {
                ModalBackdrop {
                    model.isShowingProcessLog = false
                } content: {
                    ProcessLogSheetView()
                        .environmentObject(model)
                }
            }

            if model.isShowingSettings {
                ModalBackdrop {
                    model.isShowingSettings = false
                } content: {
                    SettingsSheetView()
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
        .onAppear {
            if !model.isConnected, model.selectedProject != nil {
                model.start()
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

            SidebarCommand(icon: "square.and.pencil", title: "New chat") {
                model.newSession()
            }
            SidebarCommand(icon: "folder.badge.plus", title: "Open project") {
                openProject()
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

            SidebarCommand(icon: "list.bullet.rectangle", title: "Process log") {
                model.isShowingProcessLog = true
            }
            SidebarCommand(icon: "key", title: "Login") {
                model.isShowingLogin = true
            }
            SidebarCommand(icon: "gearshape", title: "Settings") {
                model.isShowingSettings = true
            }
                .padding(.bottom, 14)
        }
        .background(Theme.sidebarBackground)
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a project folder"

        if panel.runModal() == .OK, let url = panel.url {
            model.addProject(path: url.path)
        }
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
    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Image(systemName: "sidebar.left")
                .foregroundStyle(Theme.tertiaryText)
            Image(systemName: "chevron.left")
                .foregroundStyle(Theme.tertiaryText)
                .padding(.leading, 16)
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.tertiaryText)
        }
        .uiFont(size: 14, weight: .medium)
        .padding(.horizontal, 14)
        .padding(.leading, 98)
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

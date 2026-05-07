import AppKit
import MarkdownUI
import SwiftUI

struct ChatSurfaceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView()
                .padding(.horizontal, 20)
                .frame(height: 56)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: WindowActions.zoomKeyWindow)

            Divider()
                .overlay(Theme.border)

            VStack(spacing: 0) {
                ZStack {
                    Theme.windowBackground

                    if model.messages.isEmpty {
                        EmptyConversationView()
                            .padding(.bottom, 20)
                    } else {
                        GeometryReader { geometry in
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 22) {
                                        ForEach(model.messages) { message in
                                            MessageRowView(message: message)
                                                .id(message.id)
                                        }
                                    }
                                    .frame(width: max(0, geometry.size.width - 56), alignment: .leading)
                                    .padding(.horizontal, 28)
                                    .padding(.top, 30)
                                    .padding(.bottom, 26)
                                }
                                .onChange(of: model.messages) { _, messages in
                                    if let last = messages.last {
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            proxy.scrollTo(last.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ComposerView()
                    .padding(.horizontal, 64)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
            }
        }
        .background(Theme.windowBackground)
    }
}

struct ChatHeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Text(model.sessionTitle)
                .uiFont(size: 16, weight: .semibold)
                .lineLimit(1)

            Text(model.statusText)
                .uiFont(size: 12, weight: .medium)
                .foregroundStyle(model.isConnected ? Theme.green : Theme.tertiaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.elevatedBackground)
                .clipShape(Capsule())

            Spacer()

            ExternalTargetMenuView()
        }
    }
}

struct ExternalTargetMenuView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            ForEach(model.availableExternalTargets) { target in
                Button {
                    model.openExternally(target)
                } label: {
                    ExternalTargetMenuItemLabel(target: target)
                }
            }
        } label: {
            Image(systemName: "arrow.up.forward.app")
                .uiFont(size: 15, weight: .medium)
                .foregroundStyle(model.selectedProject == nil ? Theme.tertiaryText : Theme.secondaryText)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .disabled(model.selectedProject == nil)
        .help(model.selectedProject == nil ? "Open a project first" : "Open externally")
        .accessibilityLabel("Open externally")
        .accessibilityHint(model.selectedProject == nil ? "Open a project first" : "Opens the selected project in another app")
    }
}

private struct ExternalTargetMenuItemLabel: View {
    let target: AvailableExternalTarget

    var body: some View {
        Label {
            Text(target.displayName)
        } icon: {
            if let appIcon = target.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: target.fallbackSystemImage)
            }
        }
    }
}

struct EmptyConversationView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .uiFont(size: 28, weight: .medium)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)

            if model.selectedProject != nil {
                VStack(alignment: .leading, spacing: 12) {
                    SuggestedPrompt(text: "Inspect this repository and suggest the native pi shell architecture.")
                    SuggestedPrompt(text: "Start a new pi session for the current workspace.")
                    SuggestedPrompt(text: "List available pi commands and installed skills.")
                }
                .frame(maxWidth: 620)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        guard model.selectedProject != nil else {
            return "Open a project to start working with pi."
        }
        return "What should we work on in \(URL(fileURLWithPath: model.workspacePath).lastPathComponent)?"
    }
}

struct SuggestedPrompt: View {
    @EnvironmentObject private var model: AppModel
    let text: String

    var body: some View {
        Button {
            model.composerText = text
        } label: {
            HStack {
                Text(text)
                    .uiFont(size: 14)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(12)
            .background(Theme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ComposerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            if let pickerState = model.skillPickerState {
                SkillPickerView(
                    state: pickerState,
                    onHighlight: model.highlightSkill,
                    onSelect: model.completeSkillQuery
                )
            }

            if !model.pendingSelectedSkills.isEmpty {
                PendingSkillSelectionView()
            }

            PromptTextView(
                text: $model.composerText,
                selectedRange: $model.composerSelectionRange,
                placeholder: "Ask pi to work in this workspace",
                fontSize: model.uiFontSize,
                isEditable: !model.isStreaming,
                onSubmit: model.sendPrompt,
                onCycleReasoning: model.cycleThinkingLevel,
                onControlKey: model.handleComposerControlKey
            )
            .frame(minHeight: 48, maxHeight: 86)
            .padding(12)
            .background(Theme.composerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .foregroundStyle(Theme.secondaryText)

                Menu {
                    if model.projects.isEmpty {
                        Text("No projects")
                    } else {
                        ForEach(model.projects) { project in
                            Button {
                                model.selectProjectForNewChat(project)
                            } label: {
                                if project.id == model.selectedProjectID {
                                    Label(project.name, systemImage: "checkmark")
                                } else {
                                    Text(project.name)
                                }
                            }
                        }
                    }
                } label: {
                    Text(model.selectedProject?.name ?? "Select project")
                        .uiFont(size: 13, weight: .medium)
                        .foregroundStyle(model.selectedProject == nil ? Theme.tertiaryText : Theme.secondaryText)
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .disabled(model.projects.isEmpty || model.isStreaming)
                .help("Select project for new chat")

                Spacer()

                Button {
                    model.refreshState()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(IconButtonStyle())
                .help("Refresh state")

                Button {
                    model.showModelPicker()
                } label: {
                    Text(model.modelName)
                        .uiFont(size: 13)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(["off", "minimal", "low", "medium", "high", "xhigh"], id: \.self) { level in
                        Button(level.capitalized) {
                            model.setThinkingLevel(level)
                        }
                    }
                } label: {
                    Text(model.thinkingLevel.capitalized)
                        .uiFont(size: 13)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .menuStyle(.borderlessButton)
                .help("Reasoning level. Shift-Tab cycles levels while typing.")

                Button {
                    model.isStreaming ? model.abort() : model.sendPrompt()
                } label: {
                    Image(systemName: model.isStreaming ? "stop.fill" : "arrow.up")
                        .uiFont(size: 16, weight: .bold)
                        .foregroundStyle(Theme.windowBackground)
                        .frame(width: 30, height: 30)
                        .background(Theme.primaryText)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!model.isStreaming && model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
        }
        .padding(8)
        .background(Theme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 26, x: 0, y: 18)
    }
}

struct PendingSkillSelectionView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.pendingSelectedSkills) { skill in
                        SelectedSkillChip(skill: skill) {
                            model.removePendingSkill(skill)
                        }
                    }
                }
            }

            if model.pendingSelectedSkills.count > 1 {
                Button {
                    model.clearPendingSkills()
                } label: {
                    Image(systemName: "xmark.circle")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.tertiaryText)
                .help("Clear selected skills")
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 4)
    }
}

struct SelectedSkillChip: View {
    let skill: AvailableSkill
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
            Text(skill.id)
                .uiFont(size: 12, weight: .medium)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Remove selected skill")
        }
        .foregroundStyle(Theme.secondaryText)
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .frame(height: 24)
        .background(Theme.elevatedBackground)
        .clipShape(Capsule())
    }
}

struct SkillPickerView: View {
    let state: SkillPickerState
    let onHighlight: (AvailableSkill) -> Void
    let onSelect: (AvailableSkill) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch state.status {
            case .results:
                ForEach(state.results) { skill in
                    SkillPickerRow(
                        skill: skill,
                        isHighlighted: skill.id == state.highlightedSkillID,
                        onHighlight: { onHighlight(skill) },
                        onSelect: { onSelect(skill) }
                    )
                }
            case .empty:
                SkillPickerDisabledRow(text: "No matching skills")
            case .unavailable(let message):
                SkillPickerDisabledRow(text: message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.border.opacity(0.8), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 8)
    }
}

private struct SkillPickerRow: View {
    let skill: AvailableSkill
    let isHighlighted: Bool
    let onHighlight: () -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.id)
                    .uiFont(size: 13, weight: .semibold)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                if let detail {
                    Text(detail)
                        .uiFont(size: 12)
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isHighlighted ? Theme.accent.opacity(0.22) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                onHighlight()
            }
        }
    }

    private var detail: String? {
        if let displayName = skill.displayName, !displayName.isEmpty, displayName != skill.id {
            return displayName
        }
        return skill.description
    }
}

private struct SkillPickerDisabledRow: View {
    let text: String

    var body: some View {
        Text(text)
            .uiFont(size: 13, weight: .medium)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if message.role != .user || message.isStreaming {
                HStack(spacing: 8) {
                    if message.role != .user {
                        Text(message.title.isEmpty ? defaultTitle : message.title)
                            .uiFont(size: 13, weight: .semibold)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                    }
                    if message.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    }
                }
            }

            if !message.thinking.isEmpty {
                Text(message.thinking)
                    .uiFont(size: 12)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.elevatedBackground.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            if message.role == .user {
                Text(messageText)
                    .uiFont(size: 15)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                MarkdownMessageText(text: messageText)
            }
        }
        .padding(14)
        .background(message.role == .user ? Theme.userMessageBackground : Theme.assistantMessageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: message.role == .user ? 620 : .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var defaultTitle: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "π"
        case .system: return "System"
        case .tool: return "Tool"
        }
    }

    private var messageText: String {
        message.text.isEmpty ? "Working..." : message.text
    }
}

private struct MarkdownMessageText: View {
    @Environment(\.uiFontSize) private var uiFontSize
    let text: String

    var body: some View {
        Markdown(text)
            .markdownTextStyle {
                FontSize(scaledFontSize)
                ForegroundColor(Theme.primaryText)
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.92))
                ForegroundColor(Theme.primaryText)
                BackgroundColor(Theme.elevatedBackground.opacity(0.75))
            }
            .markdownBlockStyle(\.blockquote) { configuration in
                configuration.label
                    .padding(.vertical, 4)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.accent.opacity(0.65))
                            .frame(width: 3)
                    }
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.9))
                            ForegroundColor(Theme.primaryText)
                        }
                        .padding(12)
                }
                .background(Theme.elevatedBackground.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .tint(Theme.accent)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scaledFontSize: CGFloat {
        15 * CGFloat(uiFontSize / 15)
    }
}

struct MessageRowView: View {
    let message: ChatMessage

    var body: some View {
        Group {
            if message.role == .user {
                MessageBubbleView(message: message)
                    .frame(width: 620, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                MessageBubbleView(message: message)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

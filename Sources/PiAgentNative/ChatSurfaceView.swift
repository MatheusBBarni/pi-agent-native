import AppKit
import MarkdownUI
import SwiftUI

struct ChatSurfaceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView()
                .padding(.horizontal, 20)
                .frame(height: 44)
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
            if !model.isSidebarVisible {
                SidebarToggleButtonView()
                    .padding(.leading, 62)
            }

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
            InspectorToggleButtonView()
        }
    }
}

private struct SidebarToggleButtonView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HeaderIconButton(
            systemImage: "sidebar.left",
            title: model.l10n.string("app_shell.header.show_sidebar"),
            actionID: .toggleSidebar,
            isEnabled: model.canPerformAppAction(.toggleSidebar),
            disabledHelp: model.l10n.string("app_model.status.close_active_modal_first"),
            l10n: model.l10n
        ) {
            model.performAppAction(.toggleSidebar)
        }
        .accessibilityValue(Text(model.l10n.string("app_shell.header.sidebar_hidden")))
        .accessibilityHint(Text(model.l10n.string("app_shell.header.shows_sidebar")))
    }
}

struct InspectorToggleButtonPresentation: Equatable {
    let isInspectorVisible: Bool
    let isEnabled: Bool
    var language: AppLanguage = .english

    var iconSystemName: String { "sidebar.right" }
    var isHighlighted: Bool { !isInspectorVisible }
    var helpText: String { DefaultKeymap.helpText(for: .toggleInspector, l10n: l10n) ?? l10n.string("app_action.toggle_inspector.title") }
    var accessibilityHint: String { l10n.string("app_shell.inspector_toggle.hint") }

    var accessibilityLabel: String {
        isInspectorVisible
            ? l10n.string("app_shell.inspector_toggle.hide")
            : l10n.string("app_shell.inspector_toggle.show")
    }

    var accessibilityValue: String {
        isInspectorVisible
            ? l10n.string("app_shell.inspector_toggle.visible")
            : l10n.string("app_shell.inspector_toggle.hidden")
    }

    private var l10n: L10n {
        L10n(language: language)
    }
}

private struct InspectorToggleButtonView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let presentation = InspectorToggleButtonPresentation(
            isInspectorVisible: model.isInspectorVisible,
            isEnabled: model.canPerformAppAction(.toggleInspector),
            language: model.appLanguage
        )

        Button {
            model.performAppAction(.toggleInspector)
        } label: {
            Image(systemName: presentation.iconSystemName)
                .uiFont(size: 15, weight: .medium)
                .foregroundStyle(iconColor(for: presentation))
                .frame(width: 30, height: 30)
                .background(backgroundColor(for: presentation))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!presentation.isEnabled)
        .help(presentation.helpText)
        .accessibilityLabel(Text(presentation.accessibilityLabel))
        .accessibilityValue(Text(presentation.accessibilityValue))
        .accessibilityHint(Text(presentation.accessibilityHint))
    }

    private func iconColor(for presentation: InspectorToggleButtonPresentation) -> Color {
        if !presentation.isEnabled {
            return Theme.tertiaryText
        }
        return presentation.isHighlighted ? Theme.accent : Theme.secondaryText
    }

    private func backgroundColor(for presentation: InspectorToggleButtonPresentation) -> Color {
        presentation.isHighlighted ? Theme.elevatedBackground : Color.clear
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
        .help(model.selectedProject == nil ? model.l10n.string("app_model.availability.open_project_first") : model.l10n.string("app_shell.external.open_externally"))
        .accessibilityLabel(model.l10n.string("app_shell.external.open_externally"))
        .accessibilityHint(model.selectedProject == nil ? model.l10n.string("app_model.availability.open_project_first") : model.l10n.string("app_shell.external.hint"))
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
                    ForEach(SuggestedPromptContent.defaults(l10n: model.l10n), id: \.id) { prompt in
                        SuggestedPrompt(content: prompt)
                    }
                }
                .frame(maxWidth: 620)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        guard model.selectedProject != nil else {
            return model.l10n.string("chat.empty.open_project_title")
        }
        return model.l10n.string(
            "chat.empty.workspace_title",
            URL(fileURLWithPath: model.workspacePath).lastPathComponent
        )
    }
}

struct SuggestedPromptContent: Equatable {
    let id: String
    let promptText: String
    let displayText: String

    static let inspectRepositoryPrompt = "Inspect this repository and suggest the native pi shell architecture."
    static let startSessionPrompt = "Start a new pi session for the current workspace."
    static let listCommandsPrompt = "List available pi commands and installed skills."

    static func defaults(l10n: L10n) -> [SuggestedPromptContent] {
        [
            SuggestedPromptContent(
                id: "inspect-repository",
                promptText: inspectRepositoryPrompt,
                displayText: l10n.string("chat.suggest.inspect_repository")
            ),
            SuggestedPromptContent(
                id: "start-session",
                promptText: startSessionPrompt,
                displayText: l10n.string("chat.suggest.start_session")
            ),
            SuggestedPromptContent(
                id: "list-commands",
                promptText: listCommandsPrompt,
                displayText: l10n.string("chat.suggest.list_commands")
            )
        ]
    }
}

struct SuggestedPrompt: View {
    @EnvironmentObject private var model: AppModel
    let content: SuggestedPromptContent

    var body: some View {
        Button {
            model.composerText = content.promptText
        } label: {
            HStack {
                Text(content.displayText)
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
            if !model.pendingSelectedSkills.isEmpty {
                PendingSkillSelectionView()
            }

            if !model.pendingContextAttachments.isEmpty {
                PendingContextAttachmentView()
            }

            promptEditor
                .zIndex(1)

            HStack(spacing: 12) {
                Menu {
                    if model.projects.isEmpty {
                        Text(model.l10n.string("chat.composer.no_projects"))
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
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.secondaryText)
                        Text(model.selectedProject?.name ?? model.l10n.string("chat.composer.select_project"))
                            .uiFont(size: 13, weight: .medium)
                            .foregroundStyle(model.selectedProject == nil ? Theme.tertiaryText : Theme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .menuStyle(.borderlessButton)
                .disabled(!canSelectProjectForNewChat)
                .help(projectSelectionHelpText)
                .accessibilityLabel(model.l10n.string("chat.composer.select_project_accessibility"))
                .accessibilityHint(projectSelectionHelpText)

                Spacer()

                Button {
                    model.performAppAction(.refreshState)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(IconButtonStyle())
                .disabled(!model.canPerformAppAction(.refreshState))
                .help(refreshStateHelpText)
                .accessibilityLabel(model.localizedTitle(for: .refreshState))
                .accessibilityHint(refreshStateHelpText)

                Button {
                    model.showModelPicker()
                } label: {
                    Text(model.modelName)
                        .uiFont(size: 13)
                        .foregroundStyle(model.hasActiveModal ? Theme.tertiaryText : Theme.secondaryText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .disabled(model.hasActiveModal)
                .help(modelPickerHelpText)
                .accessibilityLabel(model.l10n.string("app_shell.composer.select_model"))
                .accessibilityHint(modelPickerHelpText)

                Menu {
                    ForEach(["off", "minimal", "low", "medium", "high", "xhigh"], id: \.self) { level in
                        Button(thinkingLevelDisplay(level)) {
                            model.setThinkingLevel(level)
                        }
                    }
                } label: {
                    Text(thinkingLevelDisplay(model.thinkingLevel))
                        .uiFont(size: 13)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .menuStyle(.borderlessButton)
                .disabled(model.hasActiveModal)
                .help(thinkingLevelHelpText)
                .accessibilityLabel(model.l10n.string("app_shell.composer.thinking_level"))
                .accessibilityHint(thinkingLevelHelpText)

                Button {
                    model.performAppAction(model.isStreaming ? .stopGeneration : .sendPrompt)
                } label: {
                    Image(systemName: model.isStreaming ? "stop.fill" : "arrow.up")
                        .uiFont(size: 16, weight: .bold)
                        .foregroundStyle(Theme.windowBackground)
                        .frame(width: 30, height: 30)
                        .background(Theme.primaryText)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canActivateSendButton)
                .help(sendButtonHelp)
                .accessibilityLabel(model.localizedTitle(for: model.isStreaming ? .stopGeneration : .sendPrompt))
                .accessibilityHint(sendButtonHelp)
            }
            .padding(.horizontal, 10)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panelBackground)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 26, x: 0, y: 18)
    }

    private var canSelectProjectForNewChat: Bool {
        !model.projects.isEmpty && !model.isStreaming && !model.hasActiveModal
    }

    private var projectSelectionHelpText: String {
        if model.hasActiveModal {
            return model.l10n.string("app_model.status.close_active_modal_first")
        }

        if model.isStreaming {
            return model.l10n.string("app_shell.composer.stop_generation_first")
        }

        if model.projects.isEmpty {
            return model.l10n.string("app_model.availability.open_project_first")
        }

        return model.l10n.string("app_shell.composer.select_project_for_new_chat")
    }

    private var promptEditor: some View {
        PromptTextView(
            text: $model.composerText,
            focusRequest: model.composerFocusRequest,
            selectedRange: $model.composerSelectionRange,
            placeholder: model.l10n.string("chat.composer.placeholder"),
            fontSize: model.uiFontSize,
            isEditable: !model.isStreaming,
            pendingTextReplacement: model.pendingMentionTextReplacement,
            onTextReplacementApplied: model.mentionTextReplacementWasApplied,
            onSelectionChange: model.updateComposerSelection,
            onMentionCommand: model.handleMentionCommand,
            onSubmit: { model.performAppAction(.sendPrompt) },
            onCycleReasoning: { model.performAppAction(.cycleThinkingLevel) },
            onControlKey: model.handleComposerControlKey
        )
        .frame(minHeight: 48, maxHeight: 86)
        .padding(12)
        .background(Theme.composerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                if let state = model.mentionPickerState {
                    MentionPickerView(
                        state: state,
                        onHover: model.highlightMentionResult,
                        onSelect: model.insertMentionResult
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: -MentionPickerView.preferredHeight(for: state) - 8)
                }

                if let pickerState = model.skillPickerState {
                    SkillPickerView(
                        state: pickerState,
                        onHighlight: model.highlightSkill,
                        onSelect: model.completeSkillQuery
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: -SkillPickerView.preferredHeight(for: pickerState) - 8)
                }
            }
            .zIndex(2)
        }
    }

    private var refreshStateHelpText: String {
        if model.canPerformAppAction(.refreshState) {
            return DefaultKeymap.helpText(for: .refreshState, l10n: model.l10n) ?? model.localizedTitle(for: .refreshState)
        }

        if model.hasActiveModal {
            return model.l10n.string("app_model.status.close_active_modal_first")
        }

        return model.l10n.string("app_model.availability.open_project_first")
    }

    private var modelPickerHelpText: String {
        model.hasActiveModal
            ? model.l10n.string("app_model.status.close_active_modal_first")
            : model.l10n.string("app_shell.composer.select_model")
    }

    private var thinkingLevelHelpText: String {
        if model.hasActiveModal {
            return model.l10n.string("app_model.status.close_active_modal_first")
        }

        return DefaultKeymap.helpText(for: .cycleThinkingLevel, l10n: model.l10n) ?? model.localizedTitle(for: .cycleThinkingLevel)
    }

    private func thinkingLevelDisplay(_ level: String) -> String {
        switch level.lowercased() {
        case "off":
            return model.l10n.string("command_palette.thinking.level.off")
        case "minimal":
            return model.l10n.string("command_palette.thinking.level.minimal")
        case "low":
            return model.l10n.string("command_palette.thinking.level.low")
        case "medium":
            return model.l10n.string("command_palette.thinking.level.medium")
        case "high":
            return model.l10n.string("command_palette.thinking.level.high")
        case "xhigh":
            return model.l10n.string("command_palette.thinking.level.xhigh")
        default:
            return level
        }
    }

    private var canActivateSendButton: Bool {
        if model.isStreaming {
            return model.canPerformAppAction(.stopGeneration)
        }

        return model.canPerformAppAction(.sendPrompt)
    }

    private var sendButtonHelp: String {
        if model.hasActiveModal {
            return model.l10n.string("app_model.status.close_active_modal_first")
        }

        if model.isStreaming {
            return DefaultKeymap.helpText(for: .stopGeneration, l10n: model.l10n) ?? model.localizedTitle(for: .stopGeneration)
        }

        if !model.canPerformAppAction(.sendPrompt) {
            if model.selectedProject == nil {
                return model.l10n.string("app_model.availability.open_project_first")
            }

            if model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return model.l10n.string("app_model.availability.enter_prompt_first")
            }

            return model.l10n.string("app_shell.composer.wait_new_session_ready")
        }

        return DefaultKeymap.helpText(for: .sendPrompt, l10n: model.l10n) ?? model.localizedTitle(for: .sendPrompt)
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
                .help(model.l10n.string("chat.composer.clear_selected_skills"))
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 4)
    }
}

struct SelectedSkillChip: View {
    @EnvironmentObject private var model: AppModel
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
            .help(model.l10n.string("chat.composer.remove_selected_skill"))
        }
        .foregroundStyle(Theme.secondaryText)
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .frame(height: 24)
        .background(Theme.elevatedBackground)
        .clipShape(Capsule())
    }
}

struct PendingContextAttachmentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.pendingContextAttachments) { attachment in
                        ContextAttachmentChip(attachment: attachment) {
                            model.removePendingContextAttachment(attachment)
                        }
                    }
                }
            }

            if model.pendingContextAttachments.count > 1 {
                Button {
                    model.clearPendingContextAttachments()
                } label: {
                    Image(systemName: "xmark.circle")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.tertiaryText)
                .help(model.l10n.string("chat.composer.clear_context_attachments"))
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 4)
    }
}

struct ContextAttachmentChip: View {
    @EnvironmentObject private var model: AppModel
    let attachment: ContextAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: attachment.kind.systemImage)
                .font(.system(size: 11, weight: .semibold))

            Text(label)
                .uiFont(size: 12, weight: .medium)
                .lineLimit(1)
                .truncationMode(.middle)

            if !attachment.status.isValid {
                Text(attachment.status.displayText(l10n: model.l10n))
                    .uiFont(size: 11, weight: .medium)
                    .foregroundStyle(Theme.red)
                    .lineLimit(1)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(model.l10n.string("chat.composer.remove_context_attachment"))
        }
        .foregroundStyle(attachment.status.isValid ? Theme.secondaryText : Theme.red)
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .frame(height: 24)
        .background(Theme.elevatedBackground)
        .clipShape(Capsule())
        .help(helpText)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var label: String {
        let path = attachment.relativePath
        guard !path.isEmpty, path != attachment.displayName else {
            return attachment.displayName
        }
        return path
    }

    private var helpText: String {
        attachment.status.isValid
            ? attachment.relativePath
            : model.l10n.string(
                "chat.context_attachment.help_with_status",
                attachment.relativePath,
                attachment.status.displayText(l10n: model.l10n)
            )
    }

    private var accessibilityLabel: String {
        model.l10n.string(
            "chat.context_attachment.accessibility",
            attachment.kind.localizedLabel(l10n: model.l10n),
            attachment.relativePath,
            attachment.status.displayText(l10n: model.l10n)
        )
    }
}

struct SkillPickerView: View {
    @EnvironmentObject private var model: AppModel
    let state: SkillPickerState
    let onHighlight: (AvailableSkill) -> Void
    let onSelect: (AvailableSkill) -> Void

    static func preferredHeight(for state: SkillPickerState) -> CGFloat {
        let rowCount: Int
        switch state.status {
        case .results:
            rowCount = max(1, state.results.count)
        case .empty, .unavailable:
            rowCount = 1
        }
        return min(CGFloat(rowCount) * 38 + 10, 322)
    }

    var body: some View {
        Group {
            if state.status == .results {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(state.results) { skill in
                                SkillPickerRow(
                                    skill: skill,
                                    isHighlighted: skill.id == state.highlightedSkillID,
                                    onHighlight: { onHighlight(skill) },
                                    onSelect: { onSelect(skill) }
                                )
                                .id(skill.id)
                            }
                        }
                    }
                    .onChange(of: state.highlightedSkillID) { _, highlightedID in
                        guard let highlightedID else { return }
                        proxy.scrollTo(highlightedID)
                    }
                }
            } else if state.status == .empty {
                SkillPickerDisabledRow(text: model.l10n.string("chat.skill_picker.no_matching_skills"))
            } else if case .unavailable(let message) = state.status {
                SkillPickerDisabledRow(text: message)
            }
        }
        .frame(height: Self.preferredHeight(for: state), alignment: .top)
        .background(Theme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

private struct SkillPickerRow: View {
    let skill: AvailableSkill
    let isHighlighted: Bool
    let onHighlight: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .frame(width: 18)
                .foregroundStyle(isHighlighted ? Theme.windowBackground : Theme.tertiaryText)

            Text(skill.id)
                .uiFont(size: 13, weight: .medium)
                .foregroundStyle(isHighlighted ? Theme.windowBackground : Theme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let detail {
                Text(detail)
                    .uiFont(size: 12)
                    .foregroundStyle(isHighlighted ? Theme.windowBackground.opacity(0.82) : Theme.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 38)
        .padding(.horizontal, 10)
        .background(isHighlighted ? Theme.accent : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering {
                onHighlight()
            }
        }
        .onTapGesture(perform: onSelect)
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiaryText)
            Text(text)
                .uiFont(size: 13)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
            Spacer()
        }
        .frame(height: 38)
        .padding(.horizontal, 10)
    }
}

struct MentionPickerView: View {
    @EnvironmentObject private var model: AppModel
    let state: MentionPickerState
    let onHover: (MentionSearchResult.ID) -> Void
    let onSelect: (MentionSearchResult.ID) -> Void

    static func preferredHeight(for state: MentionPickerState) -> CGFloat {
        let rowCount = max(1, state.results.count)
        return min(CGFloat(rowCount) * 38 + 10, 322)
    }

    var body: some View {
        Group {
            if state.status == .ready {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(state.results) { result in
                                MentionPickerRow(
                                    result: result,
                                    isHighlighted: result.id == state.highlightedResultID
                                )
                                .id(result.id)
                                .onHover { isHovering in
                                    if isHovering {
                                        onHover(result.id)
                                    }
                                }
                                .onTapGesture {
                                    onSelect(result.id)
                                }
                            }
                        }
                    }
                    .onChange(of: state.highlightedResultID) { _, highlightedID in
                        guard let highlightedID else { return }
                        proxy.scrollTo(highlightedID)
                    }
                }
            } else {
                MentionPickerStatusRow(text: statusText)
            }
        }
        .frame(height: Self.preferredHeight(for: state), alignment: .top)
        .background(Theme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    private var statusText: String {
        switch state.status {
        case .ready:
            return ""
        case .indexing:
            return model.l10n.string("chat.mention_picker.indexing")
        case .noMatches:
            return state.query.searchText.isEmpty
                ? model.l10n.string("chat.mention_picker.no_project_files")
                : model.l10n.string("chat.mention_picker.no_matching_files")
        case .unavailable:
            return model.l10n.string("chat.mention_picker.no_project_files")
        }
    }
}

private struct MentionPickerRow: View {
    let result: MentionSearchResult
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: result.entry.isDirectory ? "folder" : "doc.text")
                .frame(width: 18)
                .foregroundStyle(isHighlighted ? Theme.windowBackground : Theme.tertiaryText)

            Text(result.entry.displayName)
                .uiFont(size: 13, weight: .medium)
                .foregroundStyle(isHighlighted ? Theme.windowBackground : Theme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(displayPath)
                .uiFont(size: 12, design: .monospaced)
                .foregroundStyle(isHighlighted ? Theme.windowBackground.opacity(0.82) : Theme.tertiaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(height: 38)
        .padding(.horizontal, 10)
        .background(isHighlighted ? Theme.accent : Color.clear)
        .contentShape(Rectangle())
    }

    private var displayPath: String {
        result.entry.isDirectory ? "\(result.entry.relativePath)/" : result.entry.relativePath
    }
}

private struct MentionPickerStatusRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiaryText)
            Text(text)
                .uiFont(size: 13)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
            Spacer()
        }
        .frame(height: 38)
        .padding(.horizontal, 10)
    }
}

struct MessageBubbleView: View {
    @EnvironmentObject private var model: AppModel
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

            if message.role == .user {
                Text(messageText)
                    .uiFont(size: 15)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let blocks = visibleBlocks
                if blocks.isEmpty {
                    MarkdownMessageText(text: messageText)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                            MessageContentBlockView(block: block)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(message.role == .user ? Theme.userMessageBackground : Theme.assistantMessageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: message.role == .user ? 620 : .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var defaultTitle: String {
        switch message.role {
        case .user: return model.l10n.string("chat.message.title.you")
        case .assistant: return "π"
        case .system: return model.l10n.string("chat.message.title.system")
        case .tool: return model.l10n.string("chat.message.title.tool")
        }
    }

    private var messageText: String {
        message.text.isEmpty ? model.l10n.string("chat.message.working") : message.text
    }

    private var visibleBlocks: [MessageContentBlock] {
        message.contentBlocks.filter { !$0.isEmpty }
    }
}

private struct MessageContentBlockView: View {
    @EnvironmentObject private var model: AppModel
    let block: MessageContentBlock

    var body: some View {
        switch block {
        case .text(let text):
            MarkdownMessageText(text: text)
        case .thinking(let text):
            DisclosureGroup {
                Text(text)
                    .uiFont(size: 12)
                    .foregroundStyle(Theme.tertiaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            } label: {
                Label(model.l10n.string("chat.message.thinking"), systemImage: "brain.head.profile")
                    .uiFont(size: 12, weight: .medium)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(10)
            .background(Theme.elevatedBackground.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        case .toolCall(let call):
            InlineToolCallView(call: call)
        case .toolResult(let result):
            InlineToolResultView(result: result)
        case .image(let image):
            Text(image.altText ?? image.url.absoluteString)
                .uiFont(size: 12)
                .foregroundStyle(Theme.tertiaryText)
        }
    }
}

private struct InlineToolCallView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isExpanded = false
    let call: ToolCallPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: call.status.isRunning ? "circle.dotted" : "hammer")
                .frame(width: 18)
                .foregroundStyle(call.status.isError ? Theme.red : Theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(call.name)
                        .uiFont(size: 12, weight: .semibold)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if !call.argumentsSummary.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .uiFont(size: 11, weight: .semibold)
                                .foregroundStyle(Theme.tertiaryText)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(toolMessageToggleLabel)
                        .accessibilityLabel(toolMessageToggleLabel)
                    }
                }

                if !call.argumentsSummary.isEmpty {
                    Text(call.argumentsSummary)
                        .uiFont(size: 11, design: .monospaced)
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.elevatedBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var toolMessageToggleLabel: String {
        isExpanded
            ? model.l10n.string("chat.tool_message.collapse")
            : model.l10n.string("chat.tool_message.expand")
    }
}

private struct InlineToolResultView: View {
    @EnvironmentObject private var model: AppModel
    let result: ToolResultPresentation

    var body: some View {
        DisclosureGroup {
            Text(result.text)
                .uiFont(size: 11, design: .monospaced)
                .foregroundStyle(Theme.tertiaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } label: {
            Label(
                result.isError ? model.l10n.string("chat.tool_result.failed") : model.l10n.string("chat.tool_result.output"),
                systemImage: result.isError ? "xmark.circle" : "terminal"
            )
                .uiFont(size: 12, weight: .medium)
                .foregroundStyle(result.isError ? Theme.red : Theme.secondaryText)
        }
        .padding(10)
        .background(Theme.elevatedBackground.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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

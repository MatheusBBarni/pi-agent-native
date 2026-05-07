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
            if !model.pendingSelectedSkills.isEmpty {
                PendingSkillSelectionView()
            }

            promptEditor
                .zIndex(1)

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
                    model.performAppAction(.refreshState)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(IconButtonStyle())
                .help(DefaultKeymap.helpText(for: .refreshState) ?? "Refresh state")

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
                .help(DefaultKeymap.helpText(for: .cycleThinkingLevel) ?? "Cycle thinking level")

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
                .disabled(!model.isStreaming && !model.canSendPrompt)
                .help(sendButtonHelp)
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

    private var promptEditor: some View {
        PromptTextView(
            text: $model.composerText,
            focusRequest: model.composerFocusRequest,
            selectedRange: $model.composerSelectionRange,
            placeholder: "Ask pi to work in this workspace",
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

    private var sendButtonHelp: String {
        if model.isStreaming {
            return DefaultKeymap.helpText(for: .stopGeneration) ?? "Stop generation"
        }
        return DefaultKeymap.helpText(for: .sendPrompt) ?? "Send prompt"
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
                SkillPickerDisabledRow(text: "No matching skills")
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
            return "Indexing project files..."
        case .noMatches:
            return state.query.searchText.isEmpty ? "No project files available" : "No matching files"
        case .unavailable:
            return "No project files available"
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
        case .user: return "You"
        case .assistant: return "π"
        case .system: return "System"
        case .tool: return "Tool"
        }
    }

    private var messageText: String {
        message.text.isEmpty ? "Working..." : message.text
    }

    private var visibleBlocks: [MessageContentBlock] {
        message.contentBlocks.filter { !$0.isEmpty }
    }
}

private struct MessageContentBlockView: View {
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
                Label("Thinking", systemImage: "brain.head.profile")
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
                        .help(isExpanded ? "Collapse tool message" : "Expand tool message")
                        .accessibilityLabel(isExpanded ? "Collapse tool message" : "Expand tool message")
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
}

private struct InlineToolResultView: View {
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
            Label(result.isError ? "Tool failed" : "Tool output", systemImage: result.isError ? "xmark.circle" : "terminal")
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

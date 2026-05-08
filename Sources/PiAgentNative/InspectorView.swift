import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Color.clear
                .frame(height: 56)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: WindowActions.zoomKeyWindow)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    InspectorCard(title: model.l10n.string("inspector.branch_details.title")) {
                        InspectorMetric(icon: "point.3.connected.trianglepath.dotted", title: model.gitDetails.branch)
                        InspectorMetric(
                            icon: model.gitDetails.hasChanges ? "circle.fill" : "checkmark.circle",
                            title: model.gitDetails.changeSummary
                        )
                        InspectorMetric(
                            icon: "checkmark.circle",
                            title: InspectorPresentation.processStatus(isConnected: model.isConnected, l10n: model.l10n)
                        )
                        InspectorMetric(icon: "sparkles", title: model.modelName)
                        InspectorMetric(
                            icon: "brain.head.profile",
                            title: InspectorPresentation.thinkingLevel(model.thinkingLevel, l10n: model.l10n)
                        )
                    }

                    InspectorCard(title: model.l10n.string("inspector.queued_work.title")) {
                        QueuedWorkSurface(state: model.queuedWorkDisplayState, l10n: model.l10n)
                    }

                    InspectorCard(title: model.l10n.string("inspector.changes.title")) {
                        InspectorMetric(
                            icon: changesIcon,
                            title: changesSummary
                        )
                        Button {
                            model.openChangeReview()
                        } label: {
                            Label(model.l10n.string("inspector.changes.review"), systemImage: "doc.text.magnifyingglass")
                                .uiFont(size: 13, weight: .medium)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.selectedProject == nil)
                        .help(model.selectedProject == nil
                              ? model.l10n.string("inspector.changes.review_help.open_project_first")
                              : model.l10n.string("inspector.changes.review_help.available"))
                    }

                    if !model.tools.isEmpty {
                        InspectorCard(title: model.l10n.string("inspector.tool_activity.title")) {
                            ForEach(model.tools) { tool in
                                ToolActivityRow(tool: tool, l10n: model.l10n)
                                if tool.id != model.tools.last?.id {
                                    Divider()
                                        .overlay(Theme.border)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.visible)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Theme.windowBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)
        }
    }

    private var changesIcon: String {
        switch model.repositoryChangeSnapshot.status {
        case .loading:
            return "arrow.triangle.2.circlepath"
        case .dirty:
            return "doc.on.doc"
        case .clean:
            return "checkmark.circle"
        case .notRepository, .unavailable, .failed:
            return "exclamationmark.triangle"
        }
    }

    private var changesSummary: String {
        InspectorPresentation.changesSummary(for: model.repositoryChangeSnapshot, l10n: model.l10n)
    }
}

struct QueuedWorkSurface: View {
    let state: QueuedWorkDisplayState
    let l10n: L10n

    var body: some View {
        switch state {
        case .empty:
            InspectorMetric(icon: "tray", title: l10n.string("inspector.queued_work.empty"))
        case .countOnly(let count):
            VStack(alignment: .leading, spacing: 6) {
                InspectorMetric(icon: "tray", title: l10n.plural("inspector.queued_work.count", count: count))
                Text(l10n.string("inspector.queued_work.waiting_details"))
                    .uiFont(size: 11)
                    .foregroundStyle(Theme.tertiaryText)
            }
        case .entries(let entries):
            VStack(alignment: .leading, spacing: 10) {
                InspectorMetric(icon: "tray", title: l10n.plural("inspector.queued_work.count", count: entries.count))
                ForEach(entries) { entry in
                    QueuedWorkEntryRow(entry: entry, l10n: l10n)
                    if entry.id != entries.last?.id {
                        Divider()
                            .overlay(Theme.border)
                    }
                }
            }
        }
    }
}

enum InspectorPresentation {
    static func processStatus(isConnected: Bool, l10n: L10n) -> String {
        l10n.string(isConnected ? "inspector.process.connected" : "inspector.process.no_process")
    }

    static func changesSummary(for snapshot: RepositoryChangeSnapshot, l10n: L10n) -> String {
        switch snapshot.status {
        case .loading:
            return l10n.string("inspector.changes.refreshing")
        case .dirty:
            return l10n.plural("app_model.git.changed_files_count", count: snapshot.files.count)
        case .clean:
            return l10n.string("app_model.git.no_changes")
        case .notRepository:
            return l10n.string("inspector.changes.not_repository")
        case .unavailable(let reason):
            return reason
        case .failed(let message):
            return message
        }
    }

    static func thinkingLevel(_ level: String, l10n: L10n) -> String {
        l10n.string("inspector.thinking_level", localizedThinkingLevel(level, l10n: l10n))
    }

    private static func localizedThinkingLevel(_ level: String, l10n: L10n) -> String {
        switch level {
        case "off":
            return l10n.string("command_palette.thinking.level.off")
        case "minimal":
            return l10n.string("command_palette.thinking.level.minimal")
        case "low":
            return l10n.string("command_palette.thinking.level.low")
        case "medium":
            return l10n.string("command_palette.thinking.level.medium")
        case "high":
            return l10n.string("command_palette.thinking.level.high")
        case "xhigh":
            return l10n.string("command_palette.thinking.level.xhigh")
        default:
            return level
        }
    }
}

struct QueuedWorkEntryRow: View {
    let entry: QueuedWorkEntry
    let l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .uiFont(size: 12)
                    .frame(width: 16)
                    .foregroundStyle(entry.kind == .steering ? Theme.accent : Theme.green)
                Text(entry.title(l10n: l10n))
                    .uiFont(size: 12, weight: .semibold)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
            }

            Text(entry.summary(maxLength: 180, l10n: l10n))
                .uiFont(size: 11)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title(l10n: l10n)): \(entry.summary(l10n: l10n))")
    }

    private var icon: String {
        switch entry.kind {
        case .steering:
            return "arrow.up.right"
        case .followUp:
            return "arrow.turn.down.right"
        }
    }
}

struct InspectorCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .uiFont(size: 14, weight: .medium)
                .foregroundStyle(Theme.secondaryText)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }
}

struct InspectorMetric: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .uiFont(size: 14)
                .frame(width: 18)
                .foregroundStyle(Theme.secondaryText)
            Text(title)
                .uiFont(size: 13)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
        }
    }
}

struct ToolActivityRow: View {
    let tool: ToolActivity
    let l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tool.isError ? Theme.red : (tool.isRunning ? Theme.accent : Theme.green))
                Text(tool.name)
                    .uiFont(size: 12, weight: .semibold)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
            }

            Text(tool.summary)
                .uiFont(size: 11, design: .monospaced)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(2)

            if !tool.output.isEmpty {
                DisclosureGroup {
                    Text(tool.output)
                        .uiFont(size: 11, design: .monospaced)
                        .foregroundStyle(Theme.tertiaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } label: {
                    Text(l10n.string("inspector.tool_activity.output"))
                        .uiFont(size: 11, weight: .medium)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch tool.status {
        case .queued:
            return "clock"
        case .running:
            return "circle.dotted"
        case .succeeded:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        case .cancelled:
            return "slash.circle"
        }
    }
}

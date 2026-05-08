import SwiftUI

struct ChangeReviewSheetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedFileID: ChangedFile.ID?

    private var snapshot: RepositoryChangeSnapshot {
        model.repositoryChangeSnapshot
    }

    private var selectedFile: ChangedFile? {
        guard let selectedFileID else { return snapshot.files.first }
        return snapshot.files.first { $0.id == selectedFileID } ?? snapshot.files.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 0) {
                fileList
                    .frame(width: 280)

                Divider()
                    .overlay(Theme.border)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
        }
        .padding(22)
        .frame(width: 980, height: 680)
        .background(Theme.windowBackground)
        .onAppear(perform: ensureValidSelection)
        .onChange(of: snapshot.files) { _, _ in
            ensureValidSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.l10n.string("change_review.title"))
                    .uiFont(size: 20, weight: .semibold)
                Text(headerDetail)
                    .uiFont(size: 12, design: .monospaced)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                model.refreshRepositoryChangeSnapshot()
            } label: {
                Label(model.l10n.string("change_review.refresh"), systemImage: "arrow.clockwise")
            }

            if !model.availableExternalTargets.isEmpty {
                Menu {
                    ForEach(model.availableExternalTargets) { target in
                        Button(model.l10n.string("change_review.open_project_in", target.displayName)) {
                            model.openExternally(target)
                        }
                        if let selectedFile {
                            Button(model.l10n.string("change_review.open_file_in", target.displayName)) {
                                model.openChangedFileExternally(selectedFile, target: target)
                            }
                            .disabled(selectedFile.state == .deleted)
                        }
                    }
                } label: {
                    Label(model.l10n.string("change_review.open_externally"), systemImage: "arrow.up.forward.app")
                }
            }

            Button(model.l10n.string("change_review.close")) {
                model.performAppAction(.closeActiveModal)
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SmallCapsLabel(title: model.l10n.string("change_review.changed_files.title"))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()
                .overlay(Theme.border)

            if snapshot.files.isEmpty {
                ChangeReviewEmptyState(title: emptyTitle, detail: emptyDetail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(snapshot.files) { file in
                            ChangeFileRow(
                                file: file,
                                isSelected: file.id == selectedFile?.id
                            ) {
                                selectedFileID = file.id
                            }
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.visible)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if snapshot.status == .loading {
            ChangeReviewEmptyState(
                title: model.l10n.string("change_review.refreshing.title"),
                detail: model.l10n.string("change_review.refreshing.detail")
            )
        } else if let selectedFile {
            DiffDetailView(file: selectedFile, l10n: model.l10n)
        } else {
            ChangeReviewEmptyState(title: emptyTitle, detail: emptyDetail)
        }
    }

    private var headerDetail: String {
        ChangeReviewPresentation.headerDetail(for: snapshot, l10n: model.l10n)
    }

    private var emptyTitle: String {
        ChangeReviewPresentation.emptyTitle(for: snapshot, l10n: model.l10n)
    }

    private var emptyDetail: String {
        ChangeReviewPresentation.emptyDetail(for: snapshot, l10n: model.l10n)
    }

    private func ensureValidSelection() {
        guard !snapshot.files.isEmpty else {
            selectedFileID = nil
            return
        }
        if let selectedFileID, snapshot.files.contains(where: { $0.id == selectedFileID }) {
            return
        }
        selectedFileID = snapshot.files.first?.id
    }
}

private struct ChangeFileRow: View {
    let file: ChangedFile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Text(file.state.badge)
                    .uiFont(size: 11, weight: .bold, design: .monospaced)
                    .foregroundStyle(file.state.color)
                    .frame(width: 22, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.path)
                        .uiFont(size: 12, weight: .medium, design: .monospaced)
                        .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)
                        .lineLimit(2)
                    if let originalPath = file.originalPath {
                        Text(originalPath)
                            .uiFont(size: 11, design: .monospaced)
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.elevatedBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DiffDetailView: View {
    let file: ChangedFile
    let l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(file.state.badge)
                    .uiFont(size: 12, weight: .bold, design: .monospaced)
                    .foregroundStyle(file.state.color)
                Text(file.path)
                    .uiFont(size: 13, weight: .semibold, design: .monospaced)
                    .lineLimit(1)
                Spacer()
                Text(diffStatusText)
                    .uiFont(size: 12)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(12)

            Divider()
                .overlay(Theme.border)

            if file.hunks.isEmpty {
                ChangeReviewEmptyState(title: l10n.string("change_review.diff.unavailable.title"), detail: diffStatusText)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(file.hunks) { hunk in
                            ForEach(hunk.lines) { line in
                                DiffLineView(line: line)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .textSelection(.enabled)
                }
                .scrollIndicators(.visible)
            }
        }
    }

    private var diffStatusText: String {
        ChangeReviewPresentation.diffStatusText(for: file, l10n: l10n)
    }
}

enum ChangeReviewPresentation {
    static func headerDetail(for snapshot: RepositoryChangeSnapshot, l10n: L10n) -> String {
        switch snapshot.status {
        case .loading:
            return l10n.string("change_review.header.loading")
        case .dirty:
            return l10n.plural(
                "change_review.header.changed_files_on_branch",
                count: snapshot.files.count,
                snapshot.branch
            )
        case .clean:
            return l10n.string("change_review.header.clean_on_branch", snapshot.branch)
        case .notRepository:
            return l10n.string("change_review.header.not_repository")
        case .unavailable(let reason):
            return localizedGitMessage(reason, l10n: l10n)
        case .failed(let message):
            return localizedGitMessage(message, l10n: l10n)
        }
    }

    static func emptyTitle(for snapshot: RepositoryChangeSnapshot, l10n: L10n) -> String {
        switch snapshot.status {
        case .notRepository:
            return l10n.string("change_review.empty.not_repository.title")
        case .unavailable:
            return l10n.string("change_review.empty.no_project_selected.title")
        case .failed:
            return l10n.string("change_review.empty.changes_unavailable.title")
        default:
            return l10n.string("change_review.empty.clean.title")
        }
    }

    static func emptyDetail(for snapshot: RepositoryChangeSnapshot, l10n: L10n) -> String {
        switch snapshot.status {
        case .notRepository:
            return l10n.string("change_review.empty.not_repository.detail")
        case .unavailable(let reason):
            return localizedGitMessage(reason, l10n: l10n)
        case .failed(let message):
            return localizedGitMessage(message, l10n: l10n)
        default:
            return l10n.string("change_review.empty.clean.detail")
        }
    }

    static func diffStatusText(for file: ChangedFile, l10n: L10n) -> String {
        switch file.diffStatus {
        case .notLoaded:
            return l10n.string("change_review.diff.not_loaded")
        case .loading:
            return l10n.string("change_review.diff.loading")
        case .loaded:
            return file.isBinary
                ? l10n.string("change_review.diff.binary")
                : l10n.string("change_review.diff.text")
        case .unavailable(let message), .failed(let message):
            return localizedGitMessage(message, l10n: l10n)
        }
    }

    static func localizedGitMessage(_ message: String, l10n: L10n) -> String {
        switch message {
        case "Could not read Git status.":
            return l10n.string("change_review.git_error.read_status")
        case "Diff unavailable because this repository has no HEAD yet.":
            return l10n.string("change_review.git_error.no_head")
        case "Binary file diff is not shown.":
            return l10n.string("change_review.git_error.binary_diff_not_shown")
        case "No textual diff available.":
            return l10n.string("change_review.git_error.no_textual_diff")
        case "Untracked file is not readable.":
            return l10n.string("change_review.git_error.untracked_not_readable")
        case "Untracked directory diff is not shown.":
            return l10n.string("change_review.git_error.untracked_directory_not_shown")
        case "Untracked file is too large for native preview.":
            return l10n.string("change_review.git_error.untracked_too_large")
        case "Untracked binary file diff is not shown.":
            return l10n.string("change_review.git_error.untracked_binary_not_shown")
        default:
            let prefix = "Could not load diff for "
            if message.hasPrefix(prefix), message.hasSuffix(".") {
                let path = String(message.dropFirst(prefix.count).dropLast())
                return l10n.string("change_review.git_error.load_diff_failed", path)
            }
            return message
        }
    }
}

private struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            Text(line.oldLineNumber.map(String.init) ?? "")
                .frame(width: 46, alignment: .trailing)
                .foregroundStyle(Theme.tertiaryText)
            Text(line.newLineNumber.map(String.init) ?? "")
                .frame(width: 46, alignment: .trailing)
                .foregroundStyle(Theme.tertiaryText)
            Text(prefix)
                .frame(width: 22, alignment: .center)
                .foregroundStyle(prefixColor)
            Text(line.text.isEmpty ? " " : line.text)
                .frame(minWidth: 640, alignment: .leading)
                .foregroundStyle(textColor)
        }
        .uiFont(size: 12, design: .monospaced)
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(background)
    }

    private var prefix: String {
        switch line.kind {
        case .addition: return "+"
        case .deletion: return "-"
        case .hunkHeader: return "@"
        default: return " "
        }
    }

    private var prefixColor: Color {
        switch line.kind {
        case .addition: return Theme.green
        case .deletion: return Theme.red
        case .hunkHeader: return Theme.accent
        default: return Theme.tertiaryText
        }
    }

    private var textColor: Color {
        switch line.kind {
        case .metadata, .hunkHeader:
            return Theme.tertiaryText
        default:
            return Theme.secondaryText
        }
    }

    private var background: Color {
        switch line.kind {
        case .addition:
            return Theme.green.opacity(0.12)
        case .deletion:
            return Theme.red.opacity(0.12)
        case .hunkHeader:
            return Theme.elevatedBackground.opacity(0.7)
        default:
            return Color.clear
        }
    }
}

private struct ChangeReviewEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .uiFont(size: 14, weight: .medium)
                .foregroundStyle(Theme.secondaryText)
            Text(detail)
                .uiFont(size: 12)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension ChangedFileState {
    var badge: String {
        switch self {
        case .added, .untracked:
            return "A"
        case .modified:
            return "M"
        case .deleted:
            return "D"
        case .renamed:
            return "R"
        }
    }

    var color: Color {
        switch self {
        case .added, .untracked:
            return Theme.green
        case .modified:
            return Theme.accent
        case .deleted:
            return Theme.red
        case .renamed:
            return Theme.secondaryText
        }
    }
}

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
                Text("Changes")
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
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            if !model.availableExternalTargets.isEmpty {
                Menu {
                    ForEach(model.availableExternalTargets) { target in
                        Button("Open Project in \(target.displayName)") {
                            model.openExternally(target)
                        }
                        if let selectedFile {
                            Button("Open File in \(target.displayName)") {
                                model.openChangedFileExternally(selectedFile, target: target)
                            }
                            .disabled(selectedFile.state == .deleted)
                        }
                    }
                } label: {
                    Label("Open Externally", systemImage: "arrow.up.forward.app")
                }
            }

            Button("Close") {
                model.performAppAction(.closeActiveModal)
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SmallCapsLabel(title: "Changed Files")
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
            ChangeReviewEmptyState(title: "Refreshing changes", detail: "Reading Git status and diffs.")
        } else if let selectedFile {
            DiffDetailView(file: selectedFile)
        } else {
            ChangeReviewEmptyState(title: emptyTitle, detail: emptyDetail)
        }
    }

    private var headerDetail: String {
        switch snapshot.status {
        case .loading:
            return "Refreshing repository changes"
        case .dirty:
            return "\(snapshot.files.count) changed file\(snapshot.files.count == 1 ? "" : "s") on \(snapshot.branch)"
        case .clean:
            return "No changes on \(snapshot.branch)"
        case .notRepository:
            return "Selected Project is not a Git repository"
        case .unavailable(let reason):
            return reason
        case .failed(let message):
            return message
        }
    }

    private var emptyTitle: String {
        switch snapshot.status {
        case .notRepository:
            return "No Git repository"
        case .unavailable:
            return "No project selected"
        case .failed:
            return "Changes unavailable"
        default:
            return "No changes"
        }
    }

    private var emptyDetail: String {
        switch snapshot.status {
        case .notRepository:
            return "Open a Git repository to review changes."
        case .unavailable(let reason):
            return reason
        case .failed(let message):
            return message
        default:
            return "The Selected Project worktree is clean."
        }
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
                ChangeReviewEmptyState(title: "Diff unavailable", detail: diffStatusText)
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
        switch file.diffStatus {
        case .notLoaded:
            return "Diff not loaded"
        case .loading:
            return "Loading diff"
        case .loaded:
            return file.isBinary ? "Binary file" : "Text diff"
        case .unavailable(let message), .failed(let message):
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

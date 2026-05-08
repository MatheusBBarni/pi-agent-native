import Foundation

struct SidebarProjectRowPresentation: Equatable {
    let title: String
    let metadataText: String?
    let iconSystemName: String
    let isStale: Bool
    let showsRemoveAction: Bool
    let removeActionTitle: String
    let removeActionHelp: String
    let accessibilityLabel: String
    let helpText: String

    init(project: ProjectItem) {
        title = project.name
        isStale = project.availability == .stale
        metadataText = isStale ? "Unavailable" : nil
        iconSystemName = isStale ? "folder.badge.questionmark" : "folder"
        showsRemoveAction = isStale
        removeActionTitle = "Remove from app"
        removeActionHelp = "Remove from Pi Agent Native. Files on disk are not deleted."
        accessibilityLabel = isStale ? "\(project.name), unavailable project" : project.name
        helpText = isStale ? "Project path is unavailable. Expand to inspect saved sessions." : project.path
    }
}

struct SidebarSessionRowPresentation: Equatable {
    let title: String
    let statusText: String
    let updatedAtText: String
    let resumabilityText: String
    let resumabilitySystemImage: String
    let isEnabled: Bool
    let accessibilityLabel: String
    let helpText: String

    init(session: StoredSession, project: ProjectItem, now: Date = Date()) {
        title = session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled session" : session.title
        statusText = session.status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : session.status
        updatedAtText = Self.updatedAtText(for: session.updatedAt, now: now)
        resumabilityText = session.isResumable ? "Resumable" : "Not resumable"
        resumabilitySystemImage = session.isResumable ? "arrow.clockwise.circle" : "exclamationmark.circle"
        isEnabled = project.isAvailable
        accessibilityLabel = "\(title), \(statusText), \(updatedAtText), \(resumabilityText)"
        helpText = isEnabled ? accessibilityLabel : "\(accessibilityLabel). Project unavailable."
    }

    static func updatedAtText(for date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        if elapsed < 60 {
            return "Updated just now"
        }
        if elapsed < 3_600 {
            return "Updated \(Int(elapsed / 60))m ago"
        }
        if elapsed < 86_400 {
            return "Updated \(Int(elapsed / 3_600))h ago"
        }
        if elapsed < 604_800 {
            return "Updated \(Int(elapsed / 86_400))d ago"
        }

        return "Updated \(Self.shortDateFormatter.string(from: date))"
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

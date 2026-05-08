import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var projects: [ProjectItem]
    @Published var selectedProjectID: ProjectItem.ID?
    @Published var expandedProjectIDs: Set<ProjectItem.ID>
    @Published var workspacePath: String
    @Published var availableExternalTargets: [AvailableExternalTarget]

    init(
        projects: [ProjectItem] = [],
        selectedProjectID: ProjectItem.ID? = nil,
        availableExternalTargets: [AvailableExternalTarget] = []
    ) {
        self.projects = projects
        self.availableExternalTargets = availableExternalTargets

        if let selectedProjectID,
           let selectedProject = projects.first(where: { $0.id == selectedProjectID }) {
            self.selectedProjectID = selectedProject.id
            workspacePath = selectedProject.path
            expandedProjectIDs = [selectedProject.id]
        } else {
            self.selectedProjectID = nil
            workspacePath = ""
            expandedProjectIDs = []
        }
    }

    var selectedProject: ProjectItem? {
        projects.first { $0.id == selectedProjectID }
    }

    func select(_ project: ProjectItem, expand: Bool = true) {
        selectedProjectID = project.id
        workspacePath = project.path
        if expand {
            expandedProjectIDs.insert(project.id)
        }
    }

    func addProject(path: String) -> ProjectItem {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let normalizedPath = url.path
        if let existing = projects.first(where: { $0.path == normalizedPath }) {
            select(existing)
            return existing
        }

        let project = ProjectItem(name: url.lastPathComponent, path: normalizedPath)
        projects.append(project)
        select(project)
        return project
    }

    @discardableResult
    func removeProject(id projectID: ProjectItem.ID) -> ProjectItem? {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            return nil
        }

        let removedProject = projects.remove(at: index)
        expandedProjectIDs.remove(projectID)

        if selectedProjectID == projectID {
            selectedProjectID = nil
            workspacePath = ""
        }

        return removedProject
    }

    func toggle(_ project: ProjectItem) {
        if expandedProjectIDs.contains(project.id) {
            expandedProjectIDs.remove(project.id)
        } else {
            expandedProjectIDs.insert(project.id)
        }
    }
}

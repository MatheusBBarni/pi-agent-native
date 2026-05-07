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
                    InspectorCard(title: "Branch details") {
                        InspectorMetric(icon: "point.3.connected.trianglepath.dotted", title: model.gitDetails.branch)
                        InspectorMetric(
                            icon: model.gitDetails.hasChanges ? "circle.fill" : "checkmark.circle",
                            title: model.gitDetails.changeSummary
                        )
                        InspectorMetric(icon: "checkmark.circle", title: model.isConnected ? "Pi RPC connected" : "No process")
                        InspectorMetric(icon: "sparkles", title: model.modelName)
                        InspectorMetric(icon: "brain.head.profile", title: "\(model.thinkingLevel.capitalized) thinking")
                        if model.pendingMessageCount > 0 {
                            InspectorMetric(icon: "tray", title: "\(model.pendingMessageCount) queued")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: tool.isRunning ? "circle.dotted" : (tool.isError ? "xmark.circle" : "checkmark.circle"))
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
                Text(tool.output)
                    .uiFont(size: 11, design: .monospaced)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(5)
            }
        }
        .padding(.vertical, 4)
    }
}

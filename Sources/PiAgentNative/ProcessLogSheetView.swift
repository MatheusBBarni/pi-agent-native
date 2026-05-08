import SwiftUI

struct ProcessLogSheetView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.l10n.string("process_log.title"))
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button(model.l10n.string("process_log.close")) {
                    model.isShowingProcessLog = false
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.eventLog.isEmpty {
                        Text(model.l10n.string("process_log.empty"))
                            .foregroundStyle(Theme.tertiaryText)
                            .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
                    } else {
                        ForEach(model.eventLog) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .uiFont(size: 12, weight: .semibold)
                                    .foregroundStyle(Theme.secondaryText)
                                Text(event.detail)
                                    .uiFont(size: 12, design: .monospaced)
                                    .foregroundStyle(Theme.tertiaryText)
                                    .textSelection(.enabled)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.panelBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 420)
        }
        .padding(22)
        .frame(width: 720, height: 520)
        .background(Theme.windowBackground)
    }
}

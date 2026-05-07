import SwiftUI

struct SettingsSheetView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button("Done") {
                    model.isShowingSettings = false
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("UI font size")
                        .uiFont(size: 13, weight: .medium)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(Int(model.uiFontSize)) pt")
                        .uiFont(size: 12, design: .monospaced)
                        .foregroundStyle(Theme.tertiaryText)
                }

                Slider(value: $model.uiFontSize, in: 12...20, step: 1)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Theme")
                    .uiFont(size: 13, weight: .medium)
                    .foregroundStyle(Theme.secondaryText)

                HStack(spacing: 12) {
                    Picker("Palette", selection: $model.themeFamily) {
                        ForEach(AppThemeFamily.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)

                    Picker("Variant", selection: $model.themeVariant) {
                        ForEach(AppThemeVariant.allCases) { variant in
                            Text(variant.label).tag(variant)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
        .padding(22)
        .frame(width: 420)
        .background(Theme.windowBackground)
    }
}

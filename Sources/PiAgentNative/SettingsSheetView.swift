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

            VStack(alignment: .leading, spacing: 10) {
                Text("Pi executable")
                    .uiFont(size: 13, weight: .medium)
                    .foregroundStyle(Theme.secondaryText)

                TextField("Custom executable path", text: customExecutableBinding)
                    .textFieldStyle(.roundedBorder)

                SettingsDiagnosticRow(title: "Validation", value: model.settingsStore.executableValidationMessage)
                SettingsDiagnosticRow(title: "PI_MONO_PATH", value: model.settingsStore.piMonoPath)
                SettingsDiagnosticRow(
                    title: "Resolved command",
                    value: "\(model.settingsStore.resolvedLaunchPreview.diagnostic) --mode rpc"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("State directories")
                    .uiFont(size: 13, weight: .medium)
                    .foregroundStyle(Theme.secondaryText)

                SettingsDiagnosticRow(title: "Sessions", value: model.settingsStore.sessionStorePath)
                SettingsDiagnosticRow(title: "Auth", value: model.settingsStore.authDirectoryPath)
            }
        }
        .padding(22)
        .frame(width: 560)
        .background(Theme.windowBackground)
    }

    private var customExecutableBinding: Binding<String> {
        Binding(
            get: { model.customExecutablePath },
            set: { model.customExecutablePath = $0 }
        )
    }
}

private struct SettingsDiagnosticRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .uiFont(size: 12, weight: .medium)
                .foregroundStyle(Theme.tertiaryText)
                .frame(width: 116, alignment: .leading)

            Text(value)
                .uiFont(size: 12, design: .monospaced)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

import SwiftUI

struct SettingsSheetView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(model.l10n.string("settings.title"))
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button(model.l10n.string("settings.done")) {
                    model.isShowingSettings = false
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(model.l10n.string("settings.language.title"))
                    .uiFont(size: 13, weight: .medium)
                    .foregroundStyle(Theme.secondaryText)

                Picker(selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(model.l10n.string(language.settingsLabelKey))
                            .tag(language)
                    }
                } label: {
                    Text(model.l10n.string("settings.language.picker"))
                }
                .pickerStyle(.menu)
                .frame(width: 220, alignment: .leading)
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

                ForEach(diagnostics.launchDiagnostics) { item in
                    SettingsDiagnosticRow(title: item.title, value: item.value)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("State directories")
                    .uiFont(size: 13, weight: .medium)
                    .foregroundStyle(Theme.secondaryText)

                ForEach(diagnostics.stateDiagnostics) { item in
                    SettingsDiagnosticRow(title: item.title, value: item.value)
                }
            }
        }
        .padding(22)
        .frame(width: 560)
        .background(Theme.windowBackground)
    }

    private var diagnostics: SettingsDiagnosticsPresentation {
        SettingsDiagnosticsPresentation(settingsStore: model.settingsStore)
    }

    private var customExecutableBinding: Binding<String> {
        Binding(
            get: { model.customExecutablePath },
            set: { model.customExecutablePath = $0 }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.appLanguage },
            set: { model.appLanguage = $0 }
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

private extension AppLanguage {
    var settingsLabelKey: String {
        switch self {
        case .english:
            return "settings.language.english"
        case .portugueseBrazil:
            return "settings.language.portuguese_brazil"
        }
    }
}

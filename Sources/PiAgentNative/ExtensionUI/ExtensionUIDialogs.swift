import SwiftUI

struct ExtensionUIDialogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var textValue = ""
    @State private var selectedValue = ""
    let request: PiExtensionUIRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(request.title)
                    .uiFont(size: 20, weight: .semibold)
                    .lineLimit(2)
                Spacer()
                Button {
                    model.cancelExtensionUIRequest()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(localized("extension_ui.cancel"))
                .accessibilityLabel(localized("extension_ui.cancel"))
            }

            if !request.message.isEmpty {
                Text(request.message)
                    .uiFont(size: 13)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            requestControl

            HStack {
                Spacer()
                Button(localized("extension_ui.cancel")) {
                    model.cancelExtensionUIRequest()
                }
                Button(primaryTitle) {
                    model.submitExtensionUIRequest(result: result)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Theme.panelBackground)
        .onAppear {
            textValue = request.defaultValue
            selectedValue = request.options.first?.value ?? request.defaultValue
        }
    }

    @ViewBuilder
    private var requestControl: some View {
        switch request.method {
        case .select:
            Picker(localized("extension_ui.selection"), selection: $selectedValue) {
                ForEach(request.options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
        case .confirm:
            EmptyView()
        case .input:
            TextField(localized("extension_ui.input_label"), text: $textValue)
                .textFieldStyle(.roundedBorder)
        case .editor:
            TextEditor(text: $textValue)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 180)
                .scrollContentBackground(.hidden)
                .background(Theme.elevatedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel(localized("extension_ui.editor_label"))
        case .notify, .setStatus, .setWidget, .setTitle, .setEditorText, .unknown:
            if !request.defaultValue.isEmpty {
                Text(request.defaultValue)
                    .uiFont(size: 13, design: .monospaced)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.elevatedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel(localized("extension_ui.default_value_label"))
            }
        }
    }

    private var primaryTitle: String {
        switch request.method {
        case .confirm:
            return localized("extension_ui.confirm")
        default:
            return localized("extension_ui.submit")
        }
    }

    private var result: Any {
        switch request.method {
        case .select:
            return selectedValue
        case .confirm:
            return true
        case .input, .editor:
            return textValue
        case .notify, .setStatus, .setWidget, .setTitle, .setEditorText, .unknown:
            return request.defaultValue
        }
    }

    private func localized(_ key: String) -> String {
        model.l10n.string(key)
    }
}

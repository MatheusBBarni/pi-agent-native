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
                .help("Cancel")
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
                Button("Cancel") {
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
            Picker("Selection", selection: $selectedValue) {
                ForEach(request.options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
        case .confirm:
            EmptyView()
        case .input:
            TextField("", text: $textValue)
                .textFieldStyle(.roundedBorder)
        case .editor:
            TextEditor(text: $textValue)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 180)
                .scrollContentBackground(.hidden)
                .background(Theme.elevatedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .notify, .setStatus, .setWidget, .setTitle, .setEditorText, .unknown:
            if !request.defaultValue.isEmpty {
                Text(request.defaultValue)
                    .uiFont(size: 13, design: .monospaced)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.elevatedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var primaryTitle: String {
        switch request.method {
        case .confirm:
            return "Confirm"
        default:
            return "Submit"
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
}

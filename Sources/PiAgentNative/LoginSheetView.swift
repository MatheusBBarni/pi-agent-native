import SwiftUI
import AppKit

struct LoginSheetView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var oauthRunner = OAuthLoginRunner()
    @State private var authMethod = AuthMethod.apiKey
    @State private var selectedAPIProvider = LoginProvider.apiKeyProviders.first!
    @State private var selectedSubscriptionProvider = LoginProvider.subscriptionProviders.first!
    @State private var apiKey = ""
    @State private var terminalInput = ""
    @State private var errorMessage: String?
    @State private var openedLoginURLs: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Login")
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button("Done") {
                    if oauthRunner.exitStatus == 0 {
                        model.finishSubscriptionLogin()
                    }
                    model.isShowingLogin = false
                }
            }

            Picker("Authentication", selection: $authMethod) {
                Text("API key").tag(AuthMethod.apiKey)
                Text("Subscription").tag(AuthMethod.subscription)
            }
            .pickerStyle(.segmented)

            if authMethod == .apiKey {
                apiKeyPane
            } else {
                subscriptionPane
            }
        }
        .padding(22)
        .frame(width: 620)
        .background(Theme.windowBackground)
        .onChange(of: oauthRunner.lastURL) { _, url in
            guard let url, !openedLoginURLs.contains(url) else { return }
            openedLoginURLs.insert(url)
            NSWorkspace.shared.open(url)
        }
    }

    private var apiKeyPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider")
                .uiFont(size: 13, weight: .medium)
                .foregroundStyle(Theme.secondaryText)

            Picker("Provider", selection: $selectedAPIProvider) {
                ForEach(LoginProvider.apiKeyProviders) { provider in
                    Text(provider.name).tag(provider)
                }
            }

            SecureField("API key", text: $apiKey)
                .textFieldStyle(.plain)
                .uiFont(size: 13, design: .monospaced)
                .padding(10)
                .background(Theme.composerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text("Saved to \(NativeAuthStore.authFileURL.path)")
                .uiFont(size: 11, design: .monospaced)
                .foregroundStyle(Theme.tertiaryText)
                .textSelection(.enabled)

            if let errorMessage {
                Text(errorMessage)
                    .uiFont(size: 12)
                    .foregroundStyle(Theme.red)
            }

            HStack {
                Spacer()
                Button("Save API Key") {
                    do {
                        try model.saveAPIKey(provider: selectedAPIProvider, apiKey: apiKey)
                        apiKey = ""
                        model.isShowingLogin = false
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var subscriptionPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider")
                .uiFont(size: 13, weight: .medium)
                .foregroundStyle(Theme.secondaryText)

            Picker("Provider", selection: $selectedSubscriptionProvider) {
                ForEach(LoginProvider.subscriptionProviders) { provider in
                    Text(provider.name).tag(provider)
                }
            }

            HStack {
                Button(oauthRunner.isRunning ? "Running..." : "Start Login") {
                    openedLoginURLs.removeAll()
                    oauthRunner.start(provider: selectedSubscriptionProvider)
                }
                .disabled(oauthRunner.isRunning)

                if let url = oauthRunner.lastURL {
                    Button("Open Link") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Spacer()

                Button("Stop") {
                    oauthRunner.stop()
                }
                .disabled(!oauthRunner.isRunning)
            }

            ScrollView {
                Text(oauthRunner.output.isEmpty ? "Start login to see browser and device-code instructions." : oauthRunner.output)
                    .uiFont(size: 12, design: .monospaced)
                    .foregroundStyle(Theme.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 220)
            .background(Theme.composerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            HStack {
                TextField("Type a response for the login process", text: $terminalInput)
                    .textFieldStyle(.plain)
                    .uiFont(size: 12, design: .monospaced)
                    .padding(9)
                    .background(Theme.composerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .onSubmit {
                        oauthRunner.sendInput(terminalInput)
                        terminalInput = ""
                    }

                Button("Send") {
                    oauthRunner.sendInput(terminalInput)
                    terminalInput = ""
                }
                .disabled(terminalInput.isEmpty)
            }
        }
    }
}

private enum AuthMethod: Hashable {
    case apiKey
    case subscription
}

struct ModelPickerSheetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText = ""

    private var filteredModels: [PiModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return model.availableModels }
        return model.availableModels.filter {
            $0.provider.lowercased().contains(query)
                || $0.modelId.lowercased().contains(query)
                || $0.name.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Select Model")
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button("Refresh") {
                    model.refreshState()
                }
            }

            TextField("Search models", text: $searchText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Theme.composerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            if filteredModels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No authenticated models found.")
                        .uiFont(size: 14, weight: .medium)
                    Text("Use Login to add an API key or subscription, then refresh.")
                        .uiFont(size: 13)
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                List(filteredModels) { piModel in
                    Button {
                        model.selectModel(piModel)
                        model.isShowingModelPicker = false
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(piModel.displayName)
                                .uiFont(size: 13, weight: .medium)
                            Text(piModel.id)
                                .uiFont(size: 11, design: .monospaced)
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
                .frame(height: 320)
            }
        }
        .padding(22)
        .frame(width: 620, height: 460)
        .background(Theme.windowBackground)
    }
}

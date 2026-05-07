import SwiftUI
import AppKit

struct LoginSheetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var authMethod = AuthMethod.apiKey
    @State private var selectedAPIProvider = LoginProvider.apiKeyProviders.first!
    @State private var selectedSubscriptionProvider = LoginProvider.subscriptionProviders.first!
    @State private var apiKey = ""
    @State private var terminalInput = ""
    @State private var errorMessage: String?
    @State private var openedLoginURLs: Set<URL> = []

    private var oauthRunner: OAuthLoginRunner {
        model.oauthLoginRunner
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Login")
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button("Done") {
                    model.dismissLoginSheet()
                }
            }

            Picker("Authentication", selection: $authMethod) {
                Text("API key").tag(AuthMethod.apiKey)
                Text("Subscription").tag(AuthMethod.subscription)
            }
            .pickerStyle(.segmented)

            AccessStatusSummaryView()

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
        .onDisappear {
            model.dismissLoginSheet()
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
                Button("Logout Provider") {
                    model.logout(provider: selectedAPIProvider)
                }
                .disabled(!NativeAuthStore.hasCredential(provider: selectedAPIProvider.id))

                Spacer()

                Button("Save API Key") {
                    do {
                        try model.saveAPIKey(provider: selectedAPIProvider, apiKey: apiKey)
                        apiKey = ""
                        model.dismissLoginSheet()
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
                    model.startSubscriptionLogin(provider: selectedSubscriptionProvider)
                }
                .disabled(oauthRunner.isRunning)

                if let url = oauthRunner.lastURL {
                    Button("Open Link") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Logout Provider") {
                    model.logout(provider: selectedSubscriptionProvider)
                }
                .disabled(oauthRunner.isRunning || !NativeAuthStore.hasCredential(provider: selectedSubscriptionProvider.id))

                Spacer()

                Button("Stop") {
                    model.stopSubscriptionLogin()
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

private struct AccessStatusSummaryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .uiFont(size: 13, weight: .semibold)
                .foregroundStyle(Theme.primaryText)
            Text(detail)
                .uiFont(size: 12)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var title: String {
        switch model.authAccess.authentication {
        case .unknown:
            return "Authentication not checked"
        case .unauthenticated:
            return "Not logged in"
        case .authenticating(let providerID):
            return "Logging in to \(providerID)"
        case .authenticated(let providerID):
            return "Authenticated\(providerID.map { " with \($0)" } ?? "")"
        case .failed:
            return "Authentication error"
        }
    }

    private var detail: String {
        let modelMessage = model.authAccess.modelAccess.unavailableMessage
        let subscriptionMessage = model.authAccess.subscriptionAccess.unavailableMessage
        if model.authAccess.hasAvailableModelAccess {
            return model.authAccess.hasActiveSubscriptionAccess
                ? "Model access and subscription access are active."
                : "Model access is active. \(subscriptionMessage)"
        }
        return "\(modelMessage) \(subscriptionMessage)"
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
                    Text(emptyTitle)
                        .uiFont(size: 14, weight: .medium)
                    Text(emptyDetail)
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

    private var emptyTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !model.availableModels.isEmpty {
            return "No models match your search"
        }
        return model.authAccess.modelPickerEmptyTitle
    }

    private var emptyDetail: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !model.availableModels.isEmpty {
            return "Try a different provider, model name, or model id."
        }
        return model.authAccess.modelPickerEmptyDetail
    }
}

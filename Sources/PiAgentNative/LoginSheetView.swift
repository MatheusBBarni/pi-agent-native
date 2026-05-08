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
    @State private var loginURLOpeningTracker = ProviderLoginURLOpeningTracker()

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
        .onChange(of: oauthRunner.attemptState.lastURL) { _, url in
            guard let url, loginURLOpeningTracker.shouldOpen(url) else { return }
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
        let status = SubscriptionLoginStatusSummary.make(
            selectedProvider: selectedSubscriptionProvider,
            attemptState: oauthRunner.attemptState
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Provider")
                .uiFont(size: 13, weight: .medium)
                .foregroundStyle(Theme.secondaryText)

            Picker("Provider", selection: $selectedSubscriptionProvider) {
                ForEach(LoginProvider.subscriptionProviders) { provider in
                    Text(provider.name).tag(provider)
                }
            }

            SubscriptionLoginStatusView(status: status)

            HStack {
                Button(oauthRunner.isRunning ? "Running..." : "Start Login") {
                    loginURLOpeningTracker.reset()
                    model.startSubscriptionLogin(provider: selectedSubscriptionProvider)
                }
                .disabled(oauthRunner.isRunning)

                if let url = status.providerLoginURL {
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

            Text("Provider command output")
                .uiFont(size: 12, weight: .medium)
                .foregroundStyle(Theme.tertiaryText)

            ScrollView {
                Text(oauthRunner.output.isEmpty ? "Provider login output will appear here when the command starts." : oauthRunner.output)
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
                TextField("Paste terminal responses here when needed", text: $terminalInput)
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

private struct SubscriptionLoginStatusView: View {
    let status: SubscriptionLoginStatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.title)
                .uiFont(size: 14, weight: .semibold)
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Selected provider: \(status.providerName)")
                .uiFont(size: 11, weight: .medium)
                .foregroundStyle(badgeColor)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(status.detail)
                .uiFont(size: 12)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let url = status.providerLoginURL {
                Text("Provider Login URL: \(url.absoluteString)")
                    .uiFont(size: 11, design: .monospaced)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var badgeColor: Color {
        switch status.emphasis {
        case .neutral:
            return Theme.tertiaryText
        case .progress:
            return Theme.accent
        case .success:
            return Theme.green
        case .failure:
            return Theme.red
        }
    }

    private var borderColor: Color {
        switch status.emphasis {
        case .neutral:
            return Theme.border
        case .progress, .success, .failure:
            return badgeColor.opacity(0.65)
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

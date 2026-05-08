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
                Text(model.l10n.string("auth.login_sheet.title"))
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button(model.l10n.string("auth.login_sheet.done")) {
                    model.dismissLoginSheet()
                }
            }

            Picker(model.l10n.string("auth.login_sheet.authentication_picker"), selection: $authMethod) {
                Text(model.l10n.string("auth.login_sheet.auth_method.api_key")).tag(AuthMethod.apiKey)
                Text(model.l10n.string("auth.login_sheet.auth_method.subscription")).tag(AuthMethod.subscription)
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
            guard let url, loginURLOpeningTracker.shouldOpen(url) else { return }
            NSWorkspace.shared.open(url)
        }
        .onDisappear {
            model.dismissLoginSheet()
        }
    }

    private var apiKeyPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.l10n.string("auth.login_sheet.provider_label"))
                .uiFont(size: 13, weight: .medium)
                .foregroundStyle(Theme.secondaryText)

            Picker(model.l10n.string("auth.login_sheet.provider_picker"), selection: $selectedAPIProvider) {
                ForEach(LoginProvider.apiKeyProviders) { provider in
                    Text(provider.name).tag(provider)
                }
            }

            SecureField(model.l10n.string("auth.login_sheet.api_key_placeholder"), text: $apiKey)
                .textFieldStyle(.plain)
                .uiFont(size: 13, design: .monospaced)
                .padding(10)
                .background(Theme.composerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(model.l10n.string("auth.login_sheet.saved_to_path", NativeAuthStore.authFileURL.path))
                .uiFont(size: 11, design: .monospaced)
                .foregroundStyle(Theme.tertiaryText)
                .textSelection(.enabled)

            if let errorMessage {
                Text(errorMessage)
                    .uiFont(size: 12)
                    .foregroundStyle(Theme.red)
            }

            HStack {
                Button(model.l10n.string("auth.login_sheet.logout_provider")) {
                    model.logout(provider: selectedAPIProvider)
                }
                .disabled(!NativeAuthStore.hasCredential(provider: selectedAPIProvider.id))

                Spacer()

                Button(model.l10n.string("auth.login_sheet.save_api_key")) {
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
            Text(model.l10n.string("auth.login_sheet.provider_label"))
                .uiFont(size: 13, weight: .medium)
                .foregroundStyle(Theme.secondaryText)

            Picker(model.l10n.string("auth.login_sheet.provider_picker"), selection: $selectedSubscriptionProvider) {
                ForEach(LoginProvider.subscriptionProviders) { provider in
                    Text(provider.name).tag(provider)
                }
            }

            Text(model.l10n.string("auth.login_sheet.subscription_command_help"))
                .uiFont(size: 12)
                .foregroundStyle(Theme.secondaryText)

            HStack {
                Button(oauthRunner.isRunning ? model.l10n.string("auth.login_sheet.running") : model.l10n.string("auth.login_sheet.start_login")) {
                    loginURLOpeningTracker.reset()
                    model.startSubscriptionLogin(provider: selectedSubscriptionProvider)
                }
                .disabled(oauthRunner.isRunning)

                if let url = oauthRunner.lastURL {
                    Button(model.l10n.string("auth.login_sheet.open_link")) {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button(model.l10n.string("auth.login_sheet.logout_provider")) {
                    model.logout(provider: selectedSubscriptionProvider)
                }
                .disabled(oauthRunner.isRunning || !NativeAuthStore.hasCredential(provider: selectedSubscriptionProvider.id))

                Spacer()

                Button(model.l10n.string("auth.login_sheet.stop")) {
                    model.stopSubscriptionLogin()
                }
                .disabled(!oauthRunner.isRunning)
            }

            ScrollView {
                Text(oauthRunner.output.isEmpty ? model.l10n.string("auth.login_sheet.oauth_output_placeholder") : oauthRunner.output)
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
                TextField(model.l10n.string("auth.login_sheet.terminal_input_placeholder"), text: $terminalInput)
                    .textFieldStyle(.plain)
                    .uiFont(size: 12, design: .monospaced)
                    .padding(9)
                    .background(Theme.composerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .onSubmit {
                        oauthRunner.sendInput(terminalInput)
                        terminalInput = ""
                    }

                Button(model.l10n.string("auth.login_sheet.send")) {
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
        summary.title
    }

    private var detail: String {
        summary.detail
    }

    private var summary: SubscriptionLoginStatusSummary {
        SubscriptionLoginStatusSummary(authAccess: model.authAccess, l10n: model.l10n)
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
                Text(model.l10n.string("auth.model_picker.title"))
                    .uiFont(size: 20, weight: .semibold)
                Spacer()
                Button(model.l10n.string("auth.model_picker.refresh")) {
                    model.refreshState()
                }
            }

            TextField(model.l10n.string("auth.model_picker.search_placeholder"), text: $searchText)
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
            return model.l10n.string("auth.model_picker.empty.title.no_search_results")
        }
        return model.authAccess.modelPickerEmptyTitle(l10n: model.l10n)
    }

    private var emptyDetail: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !model.availableModels.isEmpty {
            return model.l10n.string("auth.model_picker.empty.detail.no_search_results")
        }
        return model.authAccess.modelPickerEmptyDetail(l10n: model.l10n)
    }
}

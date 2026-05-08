import SwiftUI

struct NewThreadView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var prompt: String = ""
    @State private var selectedProjectId: ProjectID?
    @State private var selectedProviderId: ProviderInstanceID?
    @State private var selectedModel: String = ""
    @State private var runtimeMode: RuntimeMode = .fullAccess
    @State private var interactionMode: ProviderInteractionMode = .default
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var promptFocused: Bool

    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue

    private let maxChars = 120_000

    var body: some View {
        NavigationStack {
            ZStack {
                T3Color.surfaceGrouped.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                        .padding(.horizontal, T3Spacing.lg)
                        .padding(.top, T3Spacing.md)
                        .padding(.bottom, T3Spacing.lg)

                    ScrollView {
                        VStack(alignment: .leading, spacing: T3Spacing.xl) {
                            projectSection
                            messageSection
                            modelSection
                            modeSection
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(T3Typography.footnote)
                                    .foregroundStyle(T3Color.danger)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, T3Spacing.xs)
                            }
                        }
                        .padding(.horizontal, T3Spacing.lg)
                        .padding(.bottom, T3Spacing.xxxl)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationBarHidden(true)
            .task {
                await env.refreshServerConfig()
                applyInitialSelections()
            }
            .onChange(of: env.threadList.projects) { _, _ in applyInitialSelections() }
            .onChange(of: env.serverConfig?.providers) { _, _ in applyInitialSelections() }
            .onChange(of: selectedProviderId) { _, _ in
                selectedModel = resolvedModelForSelectedProvider()
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: T3Spacing.sm) {
            T3Style.ToolbarChip(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T3Color.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("New Thread")
                    .font(T3Typography.headline)
                    .foregroundStyle(T3Color.textPrimary)
                Text("Spin up a new conversation")
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textTertiary)
            }
            Spacer()
            createButton
        }
    }

    private var createButton: some View {
        Button {
            Task { await createThread() }
        } label: {
            Group {
                if isCreating {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Text("Create")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(minWidth: 64, minHeight: 36)
            .padding(.horizontal, T3Spacing.md)
            .background(canCreate ? AppAccent.color(for: accentRaw) : T3Color.surfaceMuted)
            .foregroundStyle(canCreate ? .white : T3Color.textTertiary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
    }

    // MARK: - Project

    @ViewBuilder
    private var projectSection: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            T3Style.SectionHeader(title: "Project")
            T3Style.Card(padding: T3Spacing.md) {
                if env.threadList.projects.isEmpty {
                    Text("No projects are available from the desktop server.")
                        .font(T3Typography.callout)
                        .foregroundStyle(T3Color.textSecondary)
                        .padding(.vertical, T3Spacing.sm)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedProject?.title ?? "Select project")
                                .font(T3Typography.body)
                                .foregroundStyle(T3Color.textPrimary)
                            if let project = selectedProject {
                                Text(project.workspaceRoot)
                                    .font(T3Typography.footnote)
                                    .foregroundStyle(T3Color.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Menu {
                            ForEach(env.threadList.projects) { project in
                                Button {
                                    selectedProjectId = project.id
                                } label: {
                                    if selectedProjectId == project.id {
                                        Label(project.title, systemImage: "checkmark")
                                    } else {
                                        Text(project.title)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(T3Color.textTertiary)
                                .frame(width: 32, height: 32)
                                .background(T3Color.surfaceMuted, in: Circle())
                        }
                    }
                    .padding(.vertical, T3Spacing.xs)
                }
            }
        }
    }

    // MARK: - Message

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            T3Style.SectionHeader(title: "Message")
            T3Style.Card(padding: T3Spacing.md) {
                VStack(alignment: .leading, spacing: T3Spacing.xs) {
                    ZStack(alignment: .topLeading) {
                        if prompt.isEmpty {
                            Text("Ask T3 Code…")
                                .foregroundStyle(T3Color.textTertiary)
                                .font(T3Typography.body)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $prompt)
                            .focused($promptFocused)
                            .frame(minHeight: 120, maxHeight: 220)
                            .scrollContentBackground(.hidden)
                            .font(T3Typography.body)
                    }
                    HStack {
                        Spacer()
                        Text("\(prompt.count) / \(maxChars)")
                            .font(T3Typography.caption)
                            .foregroundStyle(prompt.count > maxChars ? T3Color.danger : T3Color.textTertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            T3Style.SectionHeader(title: "Model")
            T3Style.Card(padding: T3Spacing.md) {
                VStack(spacing: 0) {
                    if usableProviders.isEmpty {
                        Text(providerEmptyMessage)
                            .font(T3Typography.callout)
                            .foregroundStyle(T3Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, T3Spacing.sm)
                    } else {
                        menuRow(title: "Provider",
                                value: selectedProvider?.label ?? "Choose") {
                            ForEach(usableProviders) { provider in
                                Button {
                                    selectedProviderId = provider.instanceId
                                } label: {
                                    if selectedProviderId == provider.instanceId {
                                        Label(provider.label, systemImage: "checkmark")
                                    } else {
                                        Text(provider.label)
                                    }
                                }
                            }
                        }
                        Divider().overlay(T3Color.separator)
                        menuRow(title: "Model",
                                value: selectedModel.isEmpty ? "Default" : selectedModel) {
                            ForEach(selectedProvider?.models ?? []) { model in
                                Button {
                                    selectedModel = model.slug
                                } label: {
                                    if selectedModel == model.slug {
                                        Label(model.label, systemImage: "checkmark")
                                    } else {
                                        Text(model.label)
                                    }
                                }
                            }
                            if (selectedProvider?.models ?? []).isEmpty {
                                Button("Default") { selectedModel = "" }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mode

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            T3Style.SectionHeader(title: "Mode")
            T3Style.Card {
                VStack(alignment: .leading, spacing: T3Spacing.lg) {
                    VStack(alignment: .leading, spacing: T3Spacing.sm) {
                        Text("Chat mode")
                            .font(T3Typography.callout)
                            .foregroundStyle(T3Color.textSecondary)
                        Picker("Chat mode", selection: $interactionMode) {
                            Text("Build").tag(ProviderInteractionMode.default)
                            Text("Plan").tag(ProviderInteractionMode.plan)
                        }
                        .pickerStyle(.segmented)
                        .disabled(selectedProvider?.showInteractionModeToggle == false)
                    }

                    Divider().overlay(T3Color.separator)

                    VStack(alignment: .leading, spacing: T3Spacing.sm) {
                        Text("Access")
                            .font(T3Typography.callout)
                            .foregroundStyle(T3Color.textSecondary)
                        Picker("Access", selection: $runtimeMode) {
                            Text("Supervised").tag(RuntimeMode.approvalRequired)
                            Text("Auto edits").tag(RuntimeMode.autoAcceptEdits)
                            Text("Full access").tag(RuntimeMode.fullAccess)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func menuRow<MenuContent: View>(
        title: String,
        value: String,
        @ViewBuilder menu: () -> MenuContent
    ) -> some View {
        HStack {
            Text(title)
                .font(T3Typography.body)
                .foregroundStyle(T3Color.textPrimary)
            Spacer()
            Menu {
                menu()
            } label: {
                HStack(spacing: T3Spacing.xs) {
                    Text(value)
                        .font(T3Typography.callout)
                        .foregroundStyle(T3Color.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(T3Color.textTertiary)
                }
                .padding(.horizontal, T3Spacing.md)
                .padding(.vertical, 6)
                .background(T3Color.surfaceMuted, in: Capsule())
                .overlay(Capsule().stroke(T3Color.separator, lineWidth: 0.5))
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, T3Spacing.xs)
    }

    private var usableProviders: [ServerProvider] {
        (env.serverConfig?.providers ?? [])
            .filter(\.isUsable)
            .sorted { $0.label < $1.label }
    }

    private var selectedProject: ProjectShell? {
        guard let selectedProjectId else { return env.threadList.projects.first }
        return env.threadList.project(id: selectedProjectId)
    }

    private var selectedProvider: ServerProvider? {
        guard let selectedProviderId else { return usableProviders.first }
        return usableProviders.first { $0.instanceId == selectedProviderId }
    }

    private var providerEmptyMessage: String {
        if let error = env.serverConfigError {
            return error
        }
        return env.serverConfig == nil
            ? "Loading providers…"
            : "No installed, authenticated providers are available."
    }

    private var canCreate: Bool {
        !isCreating
            && selectedProject != nil
            && selectedProvider != nil
            && !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && prompt.count <= maxChars
    }

    private func applyInitialSelections() {
        if selectedProjectId == nil {
            selectedProjectId = env.threadList.projects.first?.id
        }
        if selectedProviderId == nil {
            selectedProviderId = usableProviders.first?.instanceId
        }
        if selectedModel.isEmpty {
            selectedModel = resolvedModelForSelectedProvider()
        }
    }

    private func resolvedModelForSelectedProvider() -> String {
        selectedProvider?.defaultModel ?? ""
    }

    private func createThread() async {
        guard let client = env.client,
              let project = selectedProject,
              let provider = selectedProvider else { return }

        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let selection = project.defaultModelSelection?.instanceId == provider.instanceId
            && project.defaultModelSelection?.model == selectedModel
            ? project.defaultModelSelection!
            : ModelSelection(instanceId: provider.instanceId, model: selectedModel)

        await MainActor.run {
            isCreating = true
            errorMessage = nil
        }
        defer { Task { @MainActor in isCreating = false } }

        do {
            _ = try await client.createThreadAndStart(
                project: project,
                text: text,
                modelSelection: selection,
                runtimeMode: runtimeMode,
                interactionMode: interactionMode
            )
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

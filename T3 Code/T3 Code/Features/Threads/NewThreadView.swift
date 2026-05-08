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

    private let maxChars = 120_000

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    if env.threadList.projects.isEmpty {
                        Text("No projects are available from the desktop server.")
                            .foregroundStyle(T3Color.textSecondary)
                    } else {
                        Picker("Project", selection: projectSelection) {
                            ForEach(env.threadList.projects) { project in
                                VStack(alignment: .leading) {
                                    Text(project.title)
                                    Text(project.workspaceRoot)
                                }
                                .tag(Optional(project.id))
                            }
                        }
                    }
                }

                Section("Message") {
                    ZStack(alignment: .topLeading) {
                        if prompt.isEmpty {
                            Text("Ask T3 Code...")
                                .foregroundStyle(T3Color.textTertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .font(T3Typography.body)
                        }
                        TextEditor(text: $prompt)
                            .frame(minHeight: 96, maxHeight: 160)
                            .scrollContentBackground(.hidden)
                            .font(T3Typography.body)
                    }
                    Text("\(prompt.count) / \(maxChars)")
                        .font(T3Typography.caption)
                        .foregroundStyle(prompt.count > maxChars ? T3Color.danger : T3Color.textTertiary)
                }

                Section("Model") {
                    if usableProviders.isEmpty {
                        Text(providerEmptyMessage)
                            .foregroundStyle(T3Color.textSecondary)
                    } else {
                        Picker("Provider", selection: providerSelection) {
                            ForEach(usableProviders) { provider in
                                Text(provider.label).tag(Optional(provider.instanceId))
                            }
                        }

                        Picker("Model", selection: $selectedModel) {
                            ForEach(selectedProvider?.models ?? []) { model in
                                Text(model.label).tag(model.slug)
                            }
                            if selectedProvider?.models.isEmpty == true {
                                Text(selectedModel.isEmpty ? "Default" : selectedModel)
                                    .tag(selectedModel)
                            }
                        }
                    }
                }

                Section("Mode") {
                    Picker("Chat mode", selection: $interactionMode) {
                        Text("Build").tag(ProviderInteractionMode.default)
                        Text("Plan").tag(ProviderInteractionMode.plan)
                    }
                    .pickerStyle(.segmented)
                    .disabled(selectedProvider?.showInteractionModeToggle == false)

                    Picker("Access", selection: $runtimeMode) {
                        Text("Supervised").tag(RuntimeMode.approvalRequired)
                        Text("Auto edits").tag(RuntimeMode.autoAcceptEdits)
                        Text("Full access").tag(RuntimeMode.fullAccess)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(T3Color.danger)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(T3Color.surfaceGrouped)
            .toolbarBackground(T3Color.surfaceGrouped, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createThread() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!canCreate)
                }
            }
            .task {
                await env.refreshServerConfig()
                applyInitialSelections()
            }
            .onChange(of: env.threadList.projects) { _, _ in
                applyInitialSelections()
            }
            .onChange(of: env.serverConfig?.providers) { _, _ in
                applyInitialSelections()
            }
            .onChange(of: selectedProviderId) { _, _ in
                selectedModel = resolvedModelForSelectedProvider()
            }
        }
    }

    private var projectSelection: Binding<ProjectID?> {
        Binding(
            get: { selectedProjectId },
            set: { selectedProjectId = $0 }
        )
    }

    private var providerSelection: Binding<ProviderInstanceID?> {
        Binding(
            get: { selectedProviderId },
            set: { selectedProviderId = $0 }
        )
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
            ? "Loading providers..."
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

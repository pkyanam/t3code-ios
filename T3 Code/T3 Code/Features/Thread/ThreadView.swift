import SwiftUI

struct ThreadView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var store: ThreadStore
    @State private var isImplementingPlan: Bool = false
    @State private var showRenameSheet: Bool = false
    @State private var renameDraft: String = ""
    let threadShell: ThreadShell

    init(threadShell: ThreadShell) {
        self.threadShell = threadShell
        _store = State(initialValue: ThreadStore(threadId: threadShell.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            ThreadHeaderView(thread: resolvedThread,
                             project: env.threadList.project(id: threadShell.projectId),
                             session: store.session,
                             onBack: { dismiss() },
                             onRename: { showRenameSheet = true },
                             onSetInteractionMode: { mode in
                                 Task { await store.setInteractionMode(mode) }
                             },
                             onSetRuntimeMode: { mode in
                                 Task { await store.setRuntimeMode(mode) }
                             },
                             onArchive: archiveThread,
                             onUnarchive: unarchiveThread,
                             onDelete: deleteThread,
                             isArchived: threadShell.archivedAt != nil)
            MessageTimelineView(store: store, threadShell: threadShell)
            actionablePanels
            ComposerView(store: store)
        }
        .background(T3Color.surfaceGrouped)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard let client = env.client else { return }
            await store.start(client: client)
        }
        .onDisappear {
            Task { await store.stop() }
        }
        .sheet(isPresented: $showRenameSheet) {
            ThreadRenameSheet(initial: store.detail?.title ?? threadShell.title) { newTitle in
                showRenameSheet = false
                Task { await renameThread(newTitle) }
            } onCancel: {
                showRenameSheet = false
            }
            .presentationDetents([.height(220), .medium])
        }
    }

    @ViewBuilder
    private var actionablePanels: some View {
        VStack(spacing: T3Spacing.md) {
            if let plan = store.latestProposedPlan {
                ProposedPlanCard(plan: plan,
                                 isImplementing: isImplementingPlan) {
                    Task { await implementPlan(plan) }
                }
            }

            ForEach(store.pendingApprovals) { approval in
                PendingApprovalCard(approval: approval) { decision in
                    Task { await store.respondApproval(approval, decision: decision) }
                }
            }

            ForEach(store.pendingUserInputs) { input in
                PendingUserInputCard(pendingInput: input) { answers in
                    Task { await store.respondUserInput(input, answers: answers) }
                }
            }

            if let lastError = store.lastError {
                Text(lastError)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(T3Spacing.md)
                    .background(T3Color.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous))
            }
        }
        .padding(.horizontal, T3Spacing.lg)
        .padding(.bottom, store.pendingApprovals.isEmpty
                          && store.pendingUserInputs.isEmpty
                          && store.latestProposedPlan == nil
                          && store.lastError == nil ? 0 : T3Spacing.sm)
    }

    private var resolvedThread: ThreadHeaderView.ThreadDescriptor {
        let title = store.detail?.title ?? threadShell.title
        let model = store.detail?.modelSelection.model ?? threadShell.modelSelection.model
        let interaction = store.detail?.interactionMode ?? threadShell.interactionMode
        let runtime = store.detail?.runtimeMode ?? threadShell.runtimeMode
        let updated = store.detail?.updatedAt ?? threadShell.updatedAt
        return .init(title: title,
                     model: model,
                     interactionMode: interaction,
                     runtimeMode: runtime,
                     updatedAt: updated)
    }

    private func renameThread(_ newTitle: String) async {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != store.detail?.title else { return }
        guard let client = env.client else { return }
        do {
            try await client.renameThread(threadId: threadShell.id, title: trimmed)
        } catch {
            await MainActor.run { store.lastError = error.localizedDescription }
        }
    }

    private func archiveThread() {
        guard let client = env.client else { return }
        Task {
            do {
                try await client.archiveThread(threadId: threadShell.id)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { store.lastError = error.localizedDescription }
            }
        }
    }

    private func unarchiveThread() {
        guard let client = env.client else { return }
        Task {
            do {
                try await client.unarchiveThread(threadId: threadShell.id)
            } catch {
                await MainActor.run { store.lastError = error.localizedDescription }
            }
        }
    }

    private func deleteThread() {
        guard let client = env.client else { return }
        Task {
            do {
                try await client.deleteThread(threadId: threadShell.id)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { store.lastError = error.localizedDescription }
            }
        }
    }

    private func implementPlan(_ plan: ProposedPlan) async {
        guard !isImplementingPlan else { return }
        await MainActor.run { isImplementingPlan = true }
        defer { Task { @MainActor in isImplementingPlan = false } }
        await store.implementProposedPlan(plan)
    }
}

// MARK: - Thread Header

struct ThreadHeaderView: View {
    struct ThreadDescriptor {
        let title: String
        let model: String
        let interactionMode: ProviderInteractionMode
        let runtimeMode: RuntimeMode
        let updatedAt: Date
    }

    let thread: ThreadDescriptor
    let project: ProjectShell?
    let session: OrchestrationSession?
    let onBack: () -> Void
    let onRename: () -> Void
    let onSetInteractionMode: (ProviderInteractionMode) -> Void
    let onSetRuntimeMode: (RuntimeMode) -> Void
    let onArchive: () -> Void
    let onUnarchive: () -> Void
    let onDelete: () -> Void
    let isArchived: Bool

    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue
    @State private var confirmDelete: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: T3Spacing.md) {
            topRow
            titleBlock
        }
        .padding(.horizontal, T3Spacing.lg)
        .padding(.top, T3Spacing.md)
        .padding(.bottom, T3Spacing.md)
        .background(T3Color.surfaceGrouped)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(T3Color.separator)
                .frame(height: 0.5)
        }
        .confirmationDialog("Delete this thread?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This thread will be permanently removed from the desktop server.")
        }
    }

    private var topRow: some View {
        HStack(spacing: T3Spacing.sm) {
            T3Style.ToolbarChip(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(T3Color.textPrimary)
            }

            T3WordmarkLabel()

            Spacer(minLength: T3Spacing.sm)

            sessionStatePill

            actionsMenu
        }
    }

    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            Button {
                onRename()
            } label: {
                Label("Rename thread", systemImage: "pencil")
            }
            if isArchived {
                Button {
                    onUnarchive()
                } label: {
                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                }
            } else {
                Button {
                    onArchive()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            Divider()
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(T3Color.textPrimary)
                .frame(width: 38, height: 38)
                .background(T3Color.surfaceElevated, in: Circle())
                .overlay(Circle().stroke(T3Color.separator, lineWidth: 0.5))
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: T3Spacing.sm) {
                Text(thread.title)
                    .font(T3Typography.headline)
                    .foregroundStyle(T3Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .layoutPriority(1)

                if let project {
                    T3Style.Pill(text: project.title)
                }

                Spacer(minLength: 0)

                interactionModeMenu
            }

            HStack(spacing: T3Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(thread.model)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textSecondary)
                Text("·")
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textTertiary)
                runtimeModeMenu
                if let session, session.status == .running {
                    Text("·")
                        .font(T3Typography.footnote)
                        .foregroundStyle(T3Color.textTertiary)
                    Text("running")
                        .font(T3Typography.footnote)
                        .foregroundStyle(T3Color.warning)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var sessionStatePill: some View {
        if let session {
            switch session.status {
            case .running:
                T3Style.Pill(text: "Running",
                             systemImage: "circle.fill",
                             tint: T3Color.warning,
                             emphasized: true)
            case .error:
                T3Style.Pill(text: "Error",
                             systemImage: "exclamationmark.triangle.fill",
                             tint: T3Color.danger,
                             emphasized: true)
            default:
                EmptyView()
            }
        }
    }

    private var interactionModeMenu: some View {
        Menu {
            Button {
                onSetInteractionMode(.default)
            } label: {
                Label("Build", systemImage: thread.interactionMode == .default ? "checkmark" : "hammer")
            }
            Button {
                onSetInteractionMode(.plan)
            } label: {
                Label("Plan", systemImage: thread.interactionMode == .plan ? "checkmark" : "doc.plaintext")
            }
        } label: {
            interactionModeBadge
        }
    }

    private var interactionModeBadge: some View {
        let mode = thread.interactionMode
        let label = mode == .plan ? "PLAN" : "BUILD"
        let tint: Color = mode == .plan ? accentColor : T3Color.success
        return T3Style.Pill(text: label, tint: tint, emphasized: true)
    }

    private var runtimeModeMenu: some View {
        Menu {
            Button {
                onSetRuntimeMode(.approvalRequired)
            } label: {
                Label("Supervised",
                      systemImage: thread.runtimeMode == .approvalRequired ? "checkmark" : "checkmark.shield")
            }
            Button {
                onSetRuntimeMode(.autoAcceptEdits)
            } label: {
                Label("Auto edits",
                      systemImage: thread.runtimeMode == .autoAcceptEdits ? "checkmark" : "wand.and.stars")
            }
            Button {
                onSetRuntimeMode(.fullAccess)
            } label: {
                Label("Full access",
                      systemImage: thread.runtimeMode == .fullAccess ? "checkmark" : "lock.open")
            }
        } label: {
            HStack(spacing: 3) {
                Text(runtimeModeLabel)
                    .font(T3Typography.footnote)
                    .foregroundStyle(runtimeModeTint)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(T3Color.textTertiary)
            }
        }
    }

    private var runtimeModeLabel: String {
        switch thread.runtimeMode {
        case .approvalRequired: "supervised"
        case .autoAcceptEdits: "auto edits"
        case .fullAccess: "full access"
        }
    }

    private var runtimeModeTint: Color {
        switch thread.runtimeMode {
        case .approvalRequired: T3Color.warning
        case .autoAcceptEdits: T3Color.primary
        case .fullAccess: T3Color.success
        }
    }

    private var accentColor: Color {
        AppAccent.color(for: accentRaw)
    }
}

// MARK: - Rename Sheet

private struct ThreadRenameSheet: View {
    @State private var draft: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    init(initial: String,
         onSubmit: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: initial)
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: T3Spacing.lg) {
                TextField("Thread title", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { onSubmit(draft) }
                Spacer()
            }
            .padding(T3Spacing.lg)
            .navigationTitle("Rename thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSubmit(draft)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}

import SwiftUI

struct ThreadsListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showNewThread: Bool = false
    @State private var selectedProjectFilter: ProjectID? = nil
    @State private var pendingThreadAction: ThreadShell?
    @State private var pendingDeleteThread: ThreadShell?
    @State private var actionError: String?
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showNewThread) {
                    NewThreadView()
                        .environment(env)
                        .presentationDetents([.large])
                }
                .alert("Couldn't update thread",
                       isPresented: Binding(get: { actionError != nil },
                                            set: { if !$0 { actionError = nil } })) {
                    Button("OK", role: .cancel) { actionError = nil }
                } message: {
                    Text(actionError ?? "")
                }
                .confirmationDialog("Delete this thread?",
                                    isPresented: Binding(get: { pendingDeleteThread != nil },
                                                         set: { if !$0 { pendingDeleteThread = nil } }),
                                    titleVisibility: .visible,
                                    presenting: pendingDeleteThread) { thread in
                    Button("Delete", role: .destructive) {
                        let target = thread
                        pendingDeleteThread = nil
                        delete(thread: target)
                    }
                    Button("Cancel", role: .cancel) { pendingDeleteThread = nil }
                } message: { _ in
                    Text("This thread will be permanently removed from the desktop server.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if activeThreads.isEmpty && projectsWithoutThreads.isEmpty {
            VStack(spacing: 0) {
                customNavBar
                    .padding(.horizontal, T3Spacing.lg)
                    .padding(.top, T3Spacing.md)
                emptyState
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(T3Color.surfaceGrouped)
        } else {
            populatedList
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: T3Spacing.md) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 56, height: 56)
                .background(T3Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous)
                        .stroke(T3Color.separator, lineWidth: 0.5)
                )
            Text("No Threads")
                .font(T3Typography.title)
            Text(env.connectionStatus == .connected
                 ? emptyStateMessage
                 : "Waiting to connect to the T3 Code server…")
                .font(T3Typography.callout)
                .foregroundStyle(T3Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, T3Spacing.xl)
            if env.connectionStatus == .connected && !env.threadList.projects.isEmpty {
                Button {
                    showNewThread = true
                } label: {
                    Label("New Thread", systemImage: "plus")
                        .font(T3Typography.bodyEmphasis)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
            }
            if let detail = env.connectionStatus.detail {
                Text(detail)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.danger)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal, T3Spacing.xl)
            }
            Spacer()
        }
    }

    private var emptyStateMessage: String {
        env.threadList.projects.isEmpty
            ? "No projects are available from the desktop server yet."
            : "Create a mobile thread from one of your desktop projects."
    }

    // MARK: - Populated list

    private var populatedList: some View {
        VStack(spacing: 0) {
            customNavBar
                .padding(.horizontal, T3Spacing.lg)
                .padding(.top, T3Spacing.md)
                .padding(.bottom, T3Spacing.xs)

            overviewHeader
                .padding(.horizontal, T3Spacing.lg)
                .padding(.bottom, T3Spacing.xs)

            List {
                if !filteredEmptyProjects.isEmpty {
                    Section {
                        ForEach(filteredEmptyProjects) { project in
                            Button {
                                showNewThread = true
                            } label: {
                                EmptyProjectRowContent(project: project, accentColor: accentColor)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(T3Color.surfaceElevated)
                        }
                    } header: {
                        sectionHeader(title: "Projects")
                    }
                }

                ForEach(filteredGroupedThreads, id: \.0.id) { project, threads in
                    Section {
                        ForEach(threads, id: \.id) { thread in
                            NavigationLink {
                                ThreadView(threadShell: thread)
                                    .environment(env)
                            } label: {
                                ThreadRow(thread: thread)
                            }
                            .listRowBackground(T3Color.surfaceElevated)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteThread = thread
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    archive(thread: thread)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(T3Color.warning)
                            }
                            .contextMenu {
                                Button {
                                    archive(thread: thread)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                Button(role: .destructive) {
                                    pendingDeleteThread = thread
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        sectionHeader(title: project.title)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(T3Spacing.sm)
            .scrollContentBackground(.hidden)
            .background(T3Color.surfaceGrouped)
            .refreshable {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        .background(T3Color.surfaceGrouped)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title.uppercased())
            .font(T3Typography.caption)
            .tracking(0.6)
            .foregroundStyle(T3Color.textTertiary)
            .padding(.leading, -T3Spacing.xs)
    }

    // MARK: - Custom Navigation Bar

    private var customNavBar: some View {
        HStack(spacing: T3Spacing.sm) {
            T3WordmarkLabel()

            Spacer(minLength: T3Spacing.sm)

            Menu {
                Button {
                    selectedProjectFilter = nil
                } label: {
                    if selectedProjectFilter == nil {
                        Label("All projects", systemImage: "checkmark")
                    } else {
                        Text("All projects")
                    }
                }
                if !env.threadList.projects.isEmpty {
                    Divider()
                    ForEach(env.threadList.projects) { project in
                        Button {
                            selectedProjectFilter = project.id
                        } label: {
                            if selectedProjectFilter == project.id {
                                Label(project.title, systemImage: "checkmark")
                            } else {
                                Text(project.title)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 12, weight: .semibold))
                    Text(currentProjectFilterLabel)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(T3Color.textPrimary)
                .padding(.horizontal, T3Spacing.sm)
                .padding(.vertical, 7)
                .background(T3Color.surfaceElevated)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(T3Color.separator, lineWidth: 0.5))
            }

            T3Style.ToolbarChip(action: { showNewThread = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(env.threadList.projects.isEmpty || env.connectionStatus != .connected
                                     ? T3Color.textTertiary
                                     : T3Color.textPrimary)
            }
            .disabled(env.threadList.projects.isEmpty || env.connectionStatus != .connected)
        }
    }

    private var currentProjectFilterLabel: String {
        if let id = selectedProjectFilter,
           let project = env.threadList.project(id: id) {
            return project.title
        }
        return "Open"
    }

    // MARK: - Overview header

    private var overviewHeader: some View {
        HStack(alignment: .center) {
            Text(overviewSubtitle)
                .font(T3Typography.callout)
                .foregroundStyle(T3Color.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            ConnectionPill(state: env.connectionStatus)
        }
    }

    private var overviewSubtitle: String {
        let activeCount = activeThreads.count
        let projectCount = env.threadList.projects.count
        let threadWord = activeCount == 1 ? "thread" : "threads"
        let projectWord = projectCount == 1 ? "project" : "projects"
        return "\(activeCount) active \(threadWord) across \(projectCount) \(projectWord)"
    }

    // MARK: - Actions

    private func archive(thread: ThreadShell) {
        guard let client = env.client else { return }
        Task {
            do {
                try await client.archiveThread(threadId: thread.id)
            } catch {
                await MainActor.run { actionError = error.localizedDescription }
            }
        }
    }

    private func delete(thread: ThreadShell) {
        guard let client = env.client else { return }
        Task {
            do {
                try await client.deleteThread(threadId: thread.id)
            } catch {
                await MainActor.run { actionError = error.localizedDescription }
            }
        }
    }

    // MARK: - Filtered data

    private var activeThreads: [ThreadShell] {
        env.threadList.threads.filter { $0.archivedAt == nil }
    }

    private var groupedThreads: [(ProjectShell, [ThreadShell])] {
        var byProject: [ProjectID: [ThreadShell]] = [:]
        for t in activeThreads { byProject[t.projectId, default: []].append(t) }
        return env.threadList.projects.compactMap { project in
            guard let threads = byProject[project.id], !threads.isEmpty else { return nil }
            return (project, threads)
        }
    }

    private var filteredGroupedThreads: [(ProjectShell, [ThreadShell])] {
        guard let id = selectedProjectFilter else { return groupedThreads }
        return groupedThreads.filter { $0.0.id == id }
    }

    private var projectsWithoutThreads: [ProjectShell] {
        let projectIdsWithThreads = Set(activeThreads.map(\.projectId))
        return env.threadList.projects.filter { !projectIdsWithThreads.contains($0.id) }
    }

    private var filteredEmptyProjects: [ProjectShell] {
        guard let id = selectedProjectFilter else { return projectsWithoutThreads }
        return projectsWithoutThreads.filter { $0.id == id }
    }

    private var accentColor: Color {
        AppAccent.color(for: accentRaw)
    }
}

// MARK: - Empty Project Row

private struct EmptyProjectRowContent: View {
    let project: ProjectShell
    let accentColor: Color

    var body: some View {
        HStack(spacing: T3Spacing.md) {
            Image(systemName: "folder")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(T3Color.textTertiary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: T3Spacing.xs) {
                Text(project.title)
                    .font(T3Typography.headline)
                    .foregroundStyle(T3Color.textPrimary)
                    .lineLimit(1)
                Text(project.workspaceRoot)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: T3Spacing.md)
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 26, height: 26)
                .background(accentColor.opacity(0.16), in: Circle())
        }
        .padding(.vertical, T3Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

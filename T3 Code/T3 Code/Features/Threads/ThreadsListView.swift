import SwiftUI

struct ThreadsListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showNewThread: Bool = false
    @State private var selectedProjectFilter: ProjectID? = nil
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
        }
    }

    @ViewBuilder
    private var content: some View {
        if env.threadList.threads.isEmpty && projectsWithoutThreads.isEmpty {
            VStack(spacing: 0) {
                customNavBar
                    .padding(.horizontal, T3Spacing.lg)
                    .padding(.top, T3Spacing.md)
                emptyState
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(T3Color.surfaceGrouped)
        } else {
            threadList
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

    private var threadList: some View {
        VStack(spacing: 0) {
            customNavBar
                .padding(.horizontal, T3Spacing.lg)
                .padding(.top, T3Spacing.md)
                .padding(.bottom, T3Spacing.lg)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: T3Spacing.xl) {
                    overviewHeader

                    if !projectsWithoutThreads.isEmpty {
                        projectSection
                    }

                    ForEach(filteredGroupedThreads, id: \.0.id) { project, threads in
                        threadSection(project: project, threads: threads)
                    }
                }
                .padding(.horizontal, T3Spacing.lg)
                .padding(.bottom, T3Spacing.xxxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        .background(T3Color.surfaceGrouped)
    }

    // MARK: - Custom Navigation Bar

    private var customNavBar: some View {
        HStack(spacing: T3Spacing.sm) {
            T3WordmarkLabel()

            Spacer(minLength: T3Spacing.sm)

            // Project filter dropdown
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
        let activeCount = env.threadList.threads.filter { $0.archivedAt == nil }.count
        let projectCount = env.threadList.projects.count
        let threadWord = activeCount == 1 ? "thread" : "threads"
        let projectWord = projectCount == 1 ? "project" : "projects"
        return "\(activeCount) active \(threadWord) across \(projectCount) \(projectWord)"
    }

    // MARK: - Project section (projects without threads)

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            T3Style.SectionHeader(title: "Projects")
            VStack(spacing: 0) {
                ForEach(Array(filteredEmptyProjects.enumerated()), id: \.element.id) { index, project in
                    Button {
                        showNewThread = true
                    } label: {
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
                        .padding(.vertical, T3Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < filteredEmptyProjects.count - 1 {
                        Divider()
                            .overlay(T3Color.separator)
                            .padding(.leading, 38)
                    }
                }
            }
            .padding(.horizontal, T3Spacing.md)
            .background(T3Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                    .stroke(T3Color.separator, lineWidth: 0.5)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Thread sections (per project)

    private func threadSection(project: ProjectShell, threads: [ThreadShell]) -> some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            T3Style.SectionHeader(title: project.title)
            VStack(spacing: 0) {
                ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                    NavigationLink {
                        ThreadView(threadShell: thread)
                            .environment(env)
                    } label: {
                        ThreadRow(thread: thread)
                    }
                    .buttonStyle(.plain)

                    if index < threads.count - 1 {
                        Divider()
                            .overlay(T3Color.separator)
                            .padding(.leading, 38)
                    }
                }
            }
            .padding(.horizontal, T3Spacing.md)
            .background(T3Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                    .stroke(T3Color.separator, lineWidth: 0.5)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Filtered data

    private var groupedThreads: [(ProjectShell, [ThreadShell])] {
        let active = env.threadList.threads.filter { $0.archivedAt == nil }
        var byProject: [ProjectID: [ThreadShell]] = [:]
        for t in active { byProject[t.projectId, default: []].append(t) }
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
        let projectIdsWithThreads = Set(env.threadList.threads
            .filter { $0.archivedAt == nil }
            .map(\.projectId))
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

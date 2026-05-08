import SwiftUI

struct ThreadsListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showSettings: Bool = false
    @State private var showNewThread: Bool = false
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .environment(env)
                        .presentationDetents([.large])
                }
                .sheet(isPresented: $showNewThread) {
                    NewThreadView()
                        .environment(env)
                        .presentationDetents([.large])
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if env.threadList.threads.isEmpty {
            emptyState
        } else {
            threadList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            customNavBar
                .padding(.horizontal, T3Spacing.lg)
                .padding(.top, T3Spacing.lg)

            VStack(spacing: T3Spacing.md) {
                Spacer()
                Image(systemName: "terminal")
                    .font(.system(size: 28, weight: .medium))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T3Color.surfaceGrouped)
    }

    private var emptyStateMessage: String {
        env.threadList.projects.isEmpty
            ? "No projects are available from the desktop server yet."
            : "Create a mobile thread from one of your desktop projects."
    }

    private var threadList: some View {
        VStack(spacing: 0) {
            customNavBar
                .padding(.horizontal, T3Spacing.lg)
                .padding(.top, T3Spacing.lg)
                .padding(.bottom, T3Spacing.xl)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: T3Spacing.xl) {
                    overviewHeader

                    if !projectsWithoutThreads.isEmpty {
                        projectSection
                    }

                    ForEach(groupedThreads, id: \.0.id) { project, threads in
                        threadSection(project: project, threads: threads)
                    }
                }
                .padding(.horizontal, T3Spacing.lg)
                .padding(.bottom, T3Spacing.xxxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .refreshable {
                // Stream auto-refreshes via subscription; nothing to do here.
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        .background(T3Color.surfaceGrouped)
    }

    // MARK: - Custom Navigation Bar

    private var customNavBar: some View {
        HStack(spacing: T3Spacing.sm) {
            // Hamburger menu
            Button {
                showSettings = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(T3Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(T3Color.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(T3Color.separator, lineWidth: 0.5)
                    )
            }

            // Title
            HStack(spacing: 4) {
                Text("T3")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(T3Color.textPrimary)
                Text("Code")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(T3Color.textPrimary)
                Text("ALPHA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(T3Color.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(T3Color.surfaceElevated)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(T3Color.separator, lineWidth: 0.5)
                    )
            }

            Spacer()

            // + button
            Button {
                showNewThread = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(T3Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(T3Color.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(T3Color.separator, lineWidth: 0.5)
                    )
            }
            .disabled(env.threadList.projects.isEmpty || env.connectionStatus != .connected)

            // Open dropdown
            Menu {
                ForEach(env.threadList.projects) { project in
                    Button(project.title) {
                        // Open project action
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cube")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(T3Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(T3Color.surfaceElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(T3Color.separator, lineWidth: 0.5)
                )
            }

            // More options
            Menu {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                Button {
                    showNewThread = true
                } label: {
                    Label("New Thread", systemImage: "plus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(T3Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(T3Color.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(T3Color.separator, lineWidth: 0.5)
                    )
            }
        }
    }

    private var overviewHeader: some View {
        Text(overviewSubtitle)
            .font(T3Typography.callout)
            .foregroundStyle(T3Color.textSecondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, T3Spacing.sm)
    }

    private var overviewSubtitle: String {
        let activeCount = env.threadList.threads.filter { $0.archivedAt == nil }.count
        let projectCount = env.threadList.projects.count
        let threadWord = activeCount == 1 ? "thread" : "threads"
        let projectWord = projectCount == 1 ? "project" : "projects"
        return "\(activeCount) active \(threadWord) across \(projectCount) \(projectWord)"
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            sectionHeader("Projects")
            VStack(spacing: 0) {
                ForEach(Array(projectsWithoutThreads.enumerated()), id: \.element.id) { index, project in
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
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accentColor)
                                .frame(width: 28, height: 28)
                                .background(accentColor.opacity(0.14), in: Circle())
                        }
                        .padding(.vertical, T3Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < projectsWithoutThreads.count - 1 {
                        Divider()
                            .overlay(T3Color.separator)
                            .padding(.leading, 38)
                    }
                }
            }
            .padding(.horizontal, T3Spacing.md)
            .padding(.vertical, 0)
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

    private func threadSection(project: ProjectShell, threads: [ThreadShell]) -> some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            sectionHeader(project.title)
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
            .padding(.vertical, 0)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(T3Typography.caption)
            .foregroundStyle(T3Color.textTertiary)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupedThreads: [(ProjectShell, [ThreadShell])] {
        let active = env.threadList.threads.filter { $0.archivedAt == nil }
        var byProject: [ProjectID: [ThreadShell]] = [:]
        for t in active { byProject[t.projectId, default: []].append(t) }
        return env.threadList.projects.compactMap { project in
            guard let threads = byProject[project.id], !threads.isEmpty else { return nil }
            return (project, threads)
        }
    }

    private var projectsWithoutThreads: [ProjectShell] {
        let projectIdsWithThreads = Set(env.threadList.threads
            .filter { $0.archivedAt == nil }
            .map(\.projectId))
        return env.threadList.projects.filter { !projectIdsWithThreads.contains($0.id) }
    }

    private var accentColor: Color {
        AppAccent.color(for: accentRaw)
    }
}

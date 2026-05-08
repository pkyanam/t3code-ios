import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            ProjectsTabView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Projects")
                }
                .tag(0)

            PlanTabView()
                .tabItem {
                    Image(systemName: "checkmark.square")
                    Text("Plan")
                }
                .tag(1)

            ChatTabView()
                .tabItem {
                    Image(systemName: "bubble.left")
                    Text("Chat")
                }
                .tag(2)

            FilesTabView()
                .tabItem {
                    Image(systemName: "doc")
                    Text("Files")
                }
                .tag(3)

            SettingsTabView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(AppAccent.color(for: accentRaw))
    }
}

// MARK: - Projects Tab

struct ProjectsTabView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            ZStack {
                T3Color.surfaceGrouped.ignoresSafeArea()
                if env.threadList.projects.isEmpty {
                    emptyState
                } else {
                    projectsList
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: T3Spacing.md) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(T3Color.textTertiary)
            Text("No Projects")
                .font(T3Typography.title)
            Text("Connect to a T3 Code server to see your projects.")
                .font(T3Typography.callout)
                .foregroundStyle(T3Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, T3Spacing.xl)
            Spacer()
        }
    }

    private var projectsList: some View {
        ScrollView {
            LazyVStack(spacing: T3Spacing.md) {
                ForEach(env.threadList.projects) { project in
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
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(T3Color.textTertiary)
                    }
                    .padding(T3Spacing.lg)
                    .background(T3Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                            .stroke(T3Color.separator, lineWidth: 0.5)
                    )
                }
            }
            .padding(T3Spacing.lg)
        }
    }
}

// MARK: - Plan Tab

struct PlanTabView: View {
    var body: some View {
        ThreadsListView()
    }
}

// MARK: - Chat Tab

struct ChatTabView: View {
    @Environment(AppEnvironment.self) private var env

    private var activeThreads: [ThreadShell] {
        env.threadList.threads.filter { $0.archivedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                T3Color.surfaceGrouped.ignoresSafeArea()
                if activeThreads.isEmpty {
                    emptyState
                } else {
                    threadsList
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: T3Spacing.md) {
            Spacer()
            Image(systemName: "bubble.left")
                .font(.system(size: 32))
                .foregroundStyle(T3Color.textTertiary)
            Text("No Conversations")
                .font(T3Typography.title)
            Text("Create a new thread to start chatting.")
                .font(T3Typography.callout)
                .foregroundStyle(T3Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, T3Spacing.xl)
            Spacer()
        }
    }

    private var threadsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(activeThreads.enumerated()), id: \.element.id) { index, thread in
                    NavigationLink {
                        ThreadView(threadShell: thread)
                    } label: {
                        ThreadRow(thread: thread)
                    }
                    .buttonStyle(.plain)

                    if index < activeThreads.count - 1 {
                        Divider()
                            .overlay(T3Color.separator)
                            .padding(.leading, 38)
                    }
                }
            }
            .padding(.horizontal, T3Spacing.lg)
        }
    }
}

// MARK: - Files Tab

struct FilesTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                T3Color.surfaceGrouped.ignoresSafeArea()
                VStack(spacing: T3Spacing.md) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundStyle(T3Color.textTertiary)
                    Text("Files")
                        .font(T3Typography.title)
                    Text("File browsing coming soon.")
                        .font(T3Typography.callout)
                        .foregroundStyle(T3Color.textSecondary)
                    Spacer()
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    var body: some View {
        SettingsView(isModal: false)
    }
}

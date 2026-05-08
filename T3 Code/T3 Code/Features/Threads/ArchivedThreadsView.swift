import SwiftUI

struct ArchivedThreadsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var actionError: String?
    @State private var pendingDeleteThread: ThreadShell?

    var body: some View {
        ZStack {
            T3Color.surfaceGrouped.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, T3Spacing.lg)
                    .padding(.top, T3Spacing.md)
                    .padding(.bottom, T3Spacing.md)

                if archivedThreads.isEmpty {
                    emptyState
                } else {
                    archivedList
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: T3Spacing.sm) {
            T3Style.ToolbarChip(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(T3Color.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Archived")
                    .font(T3Typography.title)
                    .foregroundStyle(T3Color.textPrimary)
                Text("\(archivedThreads.count) thread\(archivedThreads.count == 1 ? "" : "s")")
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: T3Spacing.md) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(T3Color.textTertiary)
                .frame(width: 56, height: 56)
                .background(T3Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous)
                        .stroke(T3Color.separator, lineWidth: 0.5)
                )
            Text("No archived threads")
                .font(T3Typography.title)
            Text("Archive threads from the chat list to keep them around without cluttering your active conversations.")
                .font(T3Typography.callout)
                .foregroundStyle(T3Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, T3Spacing.xl)
            Spacer()
        }
    }

    // MARK: - List

    private var archivedList: some View {
        List {
            ForEach(archivedGrouped, id: \.0.id) { project, threads in
                Section {
                    ForEach(threads, id: \.id) { thread in
                        NavigationLink {
                            ThreadView(threadShell: thread)
                                .environment(env)
                        } label: {
                            ThreadRow(thread: thread)
                        }
                        .listRowBackground(T3Color.surfaceElevated)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                unarchive(thread: thread)
                            } label: {
                                Label("Unarchive", systemImage: "tray.and.arrow.up")
                            }
                            .tint(T3Color.success)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteThread = thread
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                unarchive(thread: thread)
                            } label: {
                                Label("Unarchive", systemImage: "tray.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                pendingDeleteThread = thread
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(project.title.uppercased())
                        .font(T3Typography.caption)
                        .tracking(0.6)
                        .foregroundStyle(T3Color.textTertiary)
                        .padding(.leading, -T3Spacing.xs)
                }
            }

            if !ungroupedArchived.isEmpty {
                Section {
                    ForEach(ungroupedArchived, id: \.id) { thread in
                        NavigationLink {
                            ThreadView(threadShell: thread)
                                .environment(env)
                        } label: {
                            ThreadRow(thread: thread)
                        }
                        .listRowBackground(T3Color.surfaceElevated)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                unarchive(thread: thread)
                            } label: {
                                Label("Unarchive", systemImage: "tray.and.arrow.up")
                            }
                            .tint(T3Color.success)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteThread = thread
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("UNKNOWN PROJECT")
                        .font(T3Typography.caption)
                        .tracking(0.6)
                        .foregroundStyle(T3Color.textTertiary)
                        .padding(.leading, -T3Spacing.xs)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(T3Color.surfaceGrouped)
    }

    // MARK: - Actions

    private func unarchive(thread: ThreadShell) {
        guard let client = env.client else { return }
        Task {
            do {
                try await client.unarchiveThread(threadId: thread.id)
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

    // MARK: - Data

    private var archivedThreads: [ThreadShell] {
        env.threadList.threads
            .filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? $0.updatedAt) > ($1.archivedAt ?? $1.updatedAt) }
    }

    private var archivedGrouped: [(ProjectShell, [ThreadShell])] {
        var byProject: [ProjectID: [ThreadShell]] = [:]
        for thread in archivedThreads { byProject[thread.projectId, default: []].append(thread) }
        return env.threadList.projects.compactMap { project in
            guard let threads = byProject[project.id], !threads.isEmpty else { return nil }
            return (project, threads)
        }
    }

    private var ungroupedArchived: [ThreadShell] {
        let projectIds = Set(env.threadList.projects.map(\.id))
        return archivedThreads.filter { !projectIds.contains($0.projectId) }
    }
}

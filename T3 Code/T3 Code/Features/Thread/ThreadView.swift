import SwiftUI

struct ThreadView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var store: ThreadStore
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
                             onBack: { dismiss() })
            MessageTimelineView(store: store, threadShell: threadShell)
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
    }

    private var resolvedThread: ThreadHeaderView.ThreadDescriptor {
        let title = store.detail?.title ?? threadShell.title
        let model = store.detail?.modelSelection.model ?? threadShell.modelSelection.model
        let interaction = store.detail?.interactionMode ?? threadShell.interactionMode
        let updated = store.detail?.updatedAt ?? threadShell.updatedAt
        return .init(title: title,
                     model: model,
                     interactionMode: interaction,
                     updatedAt: updated)
    }
}

// MARK: - Thread Header

struct ThreadHeaderView: View {
    struct ThreadDescriptor {
        let title: String
        let model: String
        let interactionMode: ProviderInteractionMode
        let updatedAt: Date
    }

    let thread: ThreadDescriptor
    let project: ProjectShell?
    let session: OrchestrationSession?
    let onBack: () -> Void

    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue

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

                modeBadge
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
                Text(thread.updatedAt, format: .dateTime.hour().minute().second())
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textTertiary)
                    .monospacedDigit()
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

    private var modeBadge: some View {
        let mode = thread.interactionMode
        let label = mode == .plan ? "PLAN" : "BUILD"
        let tint: Color = mode == .plan ? accentColor : T3Color.success
        return T3Style.Pill(text: label, tint: tint, emphasized: true)
    }

    private var accentColor: Color {
        AppAccent.color(for: accentRaw)
    }
}

import SwiftUI

struct ThreadView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var store: ThreadStore
    let threadShell: ThreadShell

    init(threadShell: ThreadShell) {
        self.threadShell = threadShell
        _store = State(initialValue: ThreadStore(threadId: threadShell.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            MessageTimelineView(store: store, threadShell: threadShell)
            ComposerView(store: store)
        }
        .background(T3Color.surfaceGrouped)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(T3Color.surfaceGrouped, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 3) {
                    Text(store.detail?.title ?? threadShell.title)
                        .font(T3Typography.headline)
                        .foregroundStyle(T3Color.textPrimary)
                        .lineLimit(1)
                    Text(modelLabel)
                        .font(T3Typography.caption)
                        .foregroundStyle(T3Color.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .task {
            guard let client = env.client else { return }
            await store.start(client: client)
        }
        .onDisappear {
            Task { await store.stop() }
        }
    }

    private var modelLabel: String {
        let model = store.detail?.modelSelection.model ?? threadShell.modelSelection.model
        let session = store.session?.status
        if let session, session == .running {
            return "\(model) · running"
        }
        return model
    }
}

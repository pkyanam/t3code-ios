import SwiftUI

struct MessageTimelineView: View {
    @Bindable var store: ThreadStore
    let threadShell: ThreadShell
    @AppStorage("transcriptDensity") private var transcriptDensityRaw: String = TranscriptDensity.comfortable.rawValue
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: messageSpacing) {
                    if store.messages.isEmpty {
                        emptyState.padding(.top, 96)
                    } else {
                        ForEach(store.messages) { message in
                            MessageBubble(role: message.role,
                                          text: message.text,
                                          isStreaming: message.streaming,
                                          timestamp: message.createdAt)
                                .id(message.id)
                        }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, T3Spacing.lg)
                .padding(.bottom, T3Spacing.xxl)
            }
            .background(T3Color.surfaceGrouped)
            .contentShape(Rectangle())
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.dismissKeyboard()
            }
            .onChange(of: store.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
            .onChange(of: store.messages.last?.text) { _, _ in
                proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
        }
    }

    private var density: TranscriptDensity {
        TranscriptDensity(rawValue: transcriptDensityRaw) ?? .comfortable
    }

    private var messageSpacing: CGFloat {
        density == .compact ? T3Spacing.sm : T3Spacing.md
    }

    private var horizontalPadding: CGFloat {
        density == .compact ? T3Spacing.lg : T3Spacing.xl
    }

    private var emptyState: some View {
        VStack(spacing: T3Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppAccent.color(for: accentRaw))
                .frame(width: 44, height: 44)
                .background(T3Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous))
            VStack(spacing: T3Spacing.xs) {
                Text("Ready")
                    .font(T3Typography.headline)
                    .foregroundStyle(T3Color.textPrimary)
                Text("Send a message to continue this thread.")
                    .font(T3Typography.callout)
                    .foregroundStyle(T3Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

import SwiftUI

struct MessageBubble: View {
    let role: MessageRole
    let text: String
    let isStreaming: Bool
    let timestamp: Date
    @AppStorage("transcriptDensity") private var transcriptDensityRaw: String = TranscriptDensity.comfortable.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            // Role header for non-user messages
            if role != .user {
                HStack {
                    Text(role == .system ? "SYSTEM" : "T3 CODE")
                        .font(T3Typography.caption)
                        .foregroundStyle(T3Color.textTertiary)
                    Spacer()
                }
            }

            // Message body
            bodyText
                .frame(maxWidth: .infinity, alignment: .leading)

            if isStreaming {
                StreamingDots()
                    .padding(.top, T3Spacing.xs)
            }

            // Timestamp
            HStack {
                Spacer()
                Text(timestamp, style: .time)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textTertiary)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                .fill(T3Color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                .stroke(T3Color.separator, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var bodyText: some View {
        if let attributed = try? AttributedString(markdown: text,
                                                  options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)),
           !text.isEmpty {
            Text(attributed)
                .font(textFont)
                .foregroundStyle(T3Color.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
        } else if text.isEmpty && isStreaming {
            EmptyView()
        } else {
            Text(text)
                .font(textFont)
                .foregroundStyle(T3Color.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
    }

    private var textFont: Font {
        if density == .compact {
            return text.contains("\n") ? T3Typography.footnote : T3Typography.callout
        }
        return text.contains("\n") ? T3Typography.callout : T3Typography.body
    }

    private var horizontalPadding: CGFloat {
        density == .compact ? T3Spacing.md : T3Spacing.lg
    }

    private var verticalPadding: CGFloat {
        density == .compact ? T3Spacing.md : T3Spacing.lg
    }

    private var density: TranscriptDensity {
        TranscriptDensity(rawValue: transcriptDensityRaw) ?? .comfortable
    }
}

import SwiftUI

struct MessageBubble: View {
    let role: MessageRole
    let text: String
    let isStreaming: Bool
    let timestamp: Date
    @AppStorage("transcriptDensity") private var transcriptDensityRaw: String = TranscriptDensity.comfortable.rawValue
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            if role != .user {
                roleHeader
            }

            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .markdown(let chunk):
                    markdownText(chunk)
                case .code(let code, let language):
                    CodeBlockView(code: code, language: language)
                }
            }

            if isStreaming {
                StreamingDots()
                    .padding(.top, T3Spacing.xs)
            }

            HStack(spacing: T3Spacing.xs) {
                Spacer()
                Text(timestamp, style: .time)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                .fill(role == .user ? T3Color.surfaceMuted : T3Color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                .stroke(T3Color.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Role header

    private var roleHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(roleColor)
                .frame(width: 6, height: 6)
            Text(roleLabel)
                .font(T3Typography.caption)
                .foregroundStyle(T3Color.textSecondary)
                .tracking(0.4)
            Spacer()
        }
    }

    private var roleLabel: String {
        switch role {
        case .system: "SYSTEM"
        case .assistant: "T3 CODE"
        case .user: "YOU"
        }
    }

    private var roleColor: Color {
        switch role {
        case .system: T3Color.textTertiary
        case .assistant: AppAccent.color(for: accentRaw)
        case .user: T3Color.textSecondary
        }
    }

    // MARK: - Markdown rendering with inline code styling

    @ViewBuilder
    private func markdownText(_ source: String) -> some View {
        if source.isEmpty {
            EmptyView()
        } else if let attributed = try? styledAttributedString(from: source) {
            Text(attributed)
                .font(textFont)
                .foregroundStyle(T3Color.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(source)
                .font(textFont)
                .foregroundStyle(T3Color.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func styledAttributedString(from source: String) throws -> AttributedString {
        var attributed = try AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )

        // Tint inline code with a subtle background and monospaced font.
        for run in attributed.runs {
            guard let intent = run.inlinePresentationIntent,
                  intent.contains(.code) else { continue }
            attributed[run.range].backgroundColor = T3Color.surfaceMuted
            attributed[run.range].foregroundColor = T3Color.textPrimary
            attributed[run.range].font = .system(.footnote, design: .monospaced).weight(.medium)
        }
        return attributed
    }

    // MARK: - Segment parsing (block code awareness)

    private enum Segment {
        case markdown(String)
        case code(String, language: String?)
    }

    private var segments: [Segment] {
        guard text.contains("```") else {
            return [.markdown(text)]
        }
        var result: [Segment] = []
        let parts = text.components(separatedBy: "```")
        for (index, part) in parts.enumerated() {
            if index.isMultiple(of: 2) {
                let trimmed = part
                if !trimmed.isEmpty {
                    result.append(.markdown(trimmed))
                }
            } else {
                var lang: String? = nil
                var body = part
                if let nl = body.firstIndex(of: "\n") {
                    let header = body[..<nl].trimmingCharacters(in: .whitespaces)
                    if !header.isEmpty,
                       header.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {
                        lang = header
                        body = String(body[body.index(after: nl)...])
                    }
                }
                let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                result.append(.code(trimmed, language: lang))
            }
        }
        return result
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

// MARK: - Code block

struct CodeBlockView: View {
    let code: String
    let language: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(code)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(T3Color.textPrimary)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, T3Spacing.md)
        .padding(.vertical, T3Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T3Color.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous)
                .stroke(T3Color.separator, lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if let language, !language.isEmpty {
                Text(language.lowercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(T3Color.textTertiary)
                    .tracking(0.4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .padding(.trailing, T3Spacing.sm)
                    .padding(.top, T3Spacing.sm)
            }
        }
    }
}

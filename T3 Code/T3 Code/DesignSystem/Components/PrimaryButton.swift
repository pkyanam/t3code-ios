import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: T3Spacing.sm) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(T3Color.onPrimary)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(T3Typography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(T3Color.onPrimary)
            .background(
                RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous)
                    .fill(T3Color.primary.opacity(isEnabled ? 1.0 : 0.45))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: T3Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(T3Typography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(T3Color.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous)
                    .fill(T3Color.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
    }
}

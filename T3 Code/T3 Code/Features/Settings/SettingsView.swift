import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    var isModal: Bool = true
    @State private var confirmSignOut: Bool = false
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue
    @AppStorage("transcriptDensity") private var transcriptDensityRaw: String = TranscriptDensity.comfortable.rawValue
    @AppStorage("composerSize") private var composerSizeRaw: String = ComposerSize.comfortable.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: T3Spacing.xl) {
                    customizationSection
                    serverSection
                    connectionSection
                    aboutSection
                }
                .padding(T3Spacing.lg)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(T3Color.surfaceGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .confirmationDialog("Sign out of this server?",
                                isPresented: $confirmSignOut,
                                titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    Task {
                        await env.signOut()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your bearer token will be removed from this device. You'll need to pair again with the desktop app.")
            }
        }
    }

    private var customizationSection: some View {
        SettingsSection(title: "Customize") {
            VStack(spacing: 0) {
                SettingsPickerRow(title: "Appearance", selection: $appearanceRaw) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.label).tag(appearance.rawValue)
                    }
                }
                Divider()
                SettingsPickerRow(title: "Accent", selection: $accentRaw) {
                    ForEach(AppAccent.allCases) { accent in
                        Label {
                            Text(accent.label)
                        } icon: {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 12, height: 12)
                        }
                        .tag(accent.rawValue)
                    }
                }
                Divider()
                SettingsPickerRow(title: "Transcript", selection: $transcriptDensityRaw) {
                    ForEach(TranscriptDensity.allCases) { density in
                        Text(density.label).tag(density.rawValue)
                    }
                }
                Divider()
                SettingsPickerRow(title: "Composer", selection: $composerSizeRaw) {
                    ForEach(ComposerSize.allCases) { size in
                        Text(size.label).tag(size.rawValue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var serverSection: some View {
        SettingsSection(title: "Server") {
            SettingsRow(title: "URL") {
                if case .configured(let url) = env.sessionState {
                    Text(url.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("-")
                }
            }
        }
    }

    private var connectionSection: some View {
        SettingsSection(title: "Connection") {
            SettingsRow(title: "Status") {
                ConnectionPill(state: env.connectionStatus)
            }
            if let detail = env.connectionStatus.detail {
                Divider()
                Text(detail)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, T3Spacing.sm)
            }
            Divider()
            Button(role: .destructive) {
                confirmSignOut = true
            } label: {
                Text("Sign out")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(T3Typography.body)
            .foregroundStyle(T3Color.danger)
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsRow(title: "Version") {
                Text(appVersion)
            }
            Divider()
            Link(destination: URL(string: "https://t3.codes")!) {
                SettingsRowLabel(title: "T3 Code on the web", accessory: "arrow.up.right")
            }
            .buttonStyle(.plain)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            Text(title)
                .font(T3Typography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(T3Color.textSecondary)
                .padding(.horizontal, T3Spacing.sm)
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, T3Spacing.md)
            .padding(.vertical, T3Spacing.sm)
            .background(T3Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous))
        }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: T3Spacing.md) {
            Text(title)
                .foregroundStyle(T3Color.textPrimary)
            Spacer(minLength: T3Spacing.md)
            accessory
                .foregroundStyle(T3Color.textSecondary)
        }
        .font(T3Typography.body)
        .frame(minHeight: 44)
    }
}

private struct SettingsPickerRow<Content: View>: View {
    let title: String
    @Binding var selection: String
    @ViewBuilder var content: Content

    var body: some View {
        Picker(selection: $selection) {
            content
        } label: {
            Text(title)
                .foregroundStyle(T3Color.textPrimary)
        }
        .font(T3Typography.body)
        .frame(minHeight: 44)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let accessory: String

    var body: some View {
        HStack(spacing: T3Spacing.md) {
            Text(title)
                .foregroundStyle(T3Color.primary)
            Spacer()
            Image(systemName: accessory)
                .font(T3Typography.caption)
                .foregroundStyle(T3Color.textTertiary)
        }
        .font(T3Typography.body)
        .frame(minHeight: 44)
    }
}

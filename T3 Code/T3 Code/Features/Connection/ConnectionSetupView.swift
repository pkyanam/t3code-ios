import SwiftUI

struct ConnectionSetupView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var serverURL: String = "http://"
    @State private var pairingToken: String = ""
    @State private var pasteAndParse: Bool = false
    @State private var isWorking: Bool = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    enum Field { case url, token }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: T3Spacing.xl) {
                    header
                    formCard
                    helpCard
                }
                .padding(T3Spacing.lg)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(T3Color.surfaceGrouped)
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            Text("Pair this iPhone with a T3 Code server.")
                .font(T3Typography.title)
            Text("Open the desktop app → Settings → Connections → Network access. Copy the pairing URL or enter the host and token below.")
                .font(T3Typography.callout)
                .foregroundStyle(T3Color.textSecondary)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: T3Spacing.md) {
            Text("Server")
                .font(T3Typography.headline)

            VStack(alignment: .leading, spacing: T3Spacing.xs) {
                Text("Server URL")
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.textSecondary)
                TextField("http://192.168.1.20:3773", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(T3Typography.body)
                    .focused($focused, equals: .url)
                    .padding(.horizontal, T3Spacing.md)
                    .frame(height: 44)
                    .background(T3Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous)
                            .stroke(T3Color.separator, lineWidth: 0.5)
                    )
            }

            VStack(alignment: .leading, spacing: T3Spacing.xs) {
                HStack {
                    Text("Pairing token")
                        .font(T3Typography.footnote)
                        .foregroundStyle(T3Color.textSecondary)
                    Spacer()
                    Button("Paste link") { pastePairingLink() }
                        .font(T3Typography.footnote)
                        .foregroundStyle(T3Color.primary)
                }
                TextField("PAIRCODE", text: $pairingToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(T3Typography.body)
                    .focused($focused, equals: .token)
                    .padding(.horizontal, T3Spacing.md)
                    .frame(height: 44)
                    .background(T3Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: T3Radius.md, style: .continuous)
                            .stroke(T3Color.separator, lineWidth: 0.5)
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(T3Typography.footnote)
                    .foregroundStyle(T3Color.danger)
            }

            PrimaryButton(title: "Connect",
                          systemImage: "link",
                          isLoading: isWorking,
                          isEnabled: canConnect) {
                Task { await connect() }
            }
            .padding(.top, T3Spacing.xs)
        }
        .padding(T3Spacing.lg)
        .background(T3Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous))
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: T3Spacing.sm) {
            Label("Tips", systemImage: "info.circle")
                .font(T3Typography.headline)
                .foregroundStyle(T3Color.textSecondary)

            VStack(alignment: .leading, spacing: T3Spacing.xs) {
                tipRow("Use a Tailscale or LAN host — the iPhone needs network reach to your Mac.")
                tipRow("Pairing tokens are one-time. After exchange, the iPhone keeps a session.")
                tipRow("HTTPS is required when pairing from an HTTPS browser; HTTP works direct from iOS.")
            }
            .font(T3Typography.footnote)
            .foregroundStyle(T3Color.textSecondary)
        }
        .padding(T3Spacing.lg)
        .background(T3Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous))
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: T3Spacing.sm) {
            Circle().fill(T3Color.primary).frame(width: 4, height: 4).padding(.top, 6)
            Text(text)
        }
    }

    private var canConnect: Bool {
        URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
            && !pairingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func pastePairingLink() {
        guard let raw = UIPasteboard.general.string else { return }
        if let parsed = PairingFlow.parsePairingURL(raw) {
            serverURL = PairingFlow.serverBaseURL(from: parsed.serverURL).absoluteString
            pairingToken = parsed.token
            errorMessage = nil
        } else if raw.hasPrefix("http"), let url = URL(string: raw) {
            serverURL = PairingFlow.serverBaseURL(from: url).absoluteString
        } else {
            pairingToken = raw
        }
    }

    private func connect() async {
        guard !isWorking else { return }
        guard let rawURL = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid server URL"
            return
        }
        let url = PairingFlow.serverBaseURL(from: rawURL)
        let token = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            errorMessage = "Pairing token required"
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            _ = try await PairingFlow.fetchEnvironment(serverURL: url)
            let pair = try await PairingFlow.exchangeToken(serverURL: url, oneTimeToken: token)
            await env.configure(serverURL: url, bearerToken: pair.bearerToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

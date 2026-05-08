import Foundation
import SwiftUI

@Observable
final class AppEnvironment {
    enum SessionState: Equatable {
        case unconfigured
        case configured(URL)
    }

    var sessionState: SessionState
    var connectionStatus: ConnectionState = .offline
    var threadList: ThreadListStore
    var serverConfig: ServerRuntimeConfig?
    var serverConfigError: String?
    private(set) var connection: T3Connection?
    private(set) var client: T3Client?
    private var statusTask: Task<Void, Never>?

    init() {
        self.threadList = ThreadListStore()
        if let raw = KeychainStore.read(.serverURL),
           let url = URL(string: raw),
           KeychainStore.read(.bearerToken) != nil {
            self.sessionState = .configured(url)
        } else {
            self.sessionState = .unconfigured
        }
    }

    func configure(serverURL: URL, bearerToken: String) async {
        KeychainStore.save(serverURL.absoluteString, for: .serverURL)
        KeychainStore.save(bearerToken, for: .bearerToken)
        sessionState = .configured(serverURL)
        await startClient(serverURL: serverURL, bearerToken: bearerToken)
    }

    func resumeIfConfigured() async {
        guard case .configured(let url) = sessionState,
              let token = KeychainStore.read(.bearerToken) else { return }
        await startClient(serverURL: url, bearerToken: token)
    }

    func signOut() async {
        statusTask?.cancel()
        statusTask = nil
        if let client { await client.stop() }
        client = nil
        connection = nil
        KeychainStore.delete(.bearerToken)
        KeychainStore.delete(.serverURL)
        sessionState = .unconfigured
        connectionStatus = .offline
        serverConfig = nil
        serverConfigError = nil
        threadList = ThreadListStore()
    }

    private func startClient(serverURL: URL, bearerToken: String) async {
        if let existing = client {
            await existing.stop()
        }
        let conn = T3Connection(config: .init(serverURL: serverURL, bearerToken: bearerToken))
        let cli = T3Client(connection: conn)
        connection = conn
        client = cli

        let env = self
        await cli.addStatusListener { status in
            Task { @MainActor in
                switch status {
                case .offline:    env.connectionStatus = .offline
                case .connecting: env.connectionStatus = .connecting
                case .connected:  env.connectionStatus = .connected
                case .error(let message): env.connectionStatus = .error(message)
                }
            }
        }

        let connected = await cli.start()
        if connected {
            await refreshServerConfig()
            await threadList.start(client: cli)
        }
    }

    func refreshServerConfig() async {
        guard let client else { return }
        do {
            let config = try await client.getServerConfig()
            await MainActor.run {
                self.serverConfig = config
                self.serverConfigError = nil
            }
        } catch {
            await MainActor.run {
                self.serverConfigError = error.localizedDescription
            }
        }
    }
}

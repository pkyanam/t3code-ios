import Foundation

struct ServerRuntimeConfig: Decodable, Sendable {
    let providers: [ServerProvider]
}

struct ServerProvider: Decodable, Hashable, Identifiable, Sendable {
    let instanceId: ProviderInstanceID
    let driver: String
    let displayName: String?
    let enabled: Bool
    let installed: Bool
    let status: String
    let auth: ServerProviderAuth
    let models: [ServerProviderModel]
    let showInteractionModeToggle: Bool?

    var id: ProviderInstanceID { instanceId }

    var isUsable: Bool {
        enabled && installed && auth.status != "unauthenticated"
    }

    var label: String {
        displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? displayName!
            : driver.providerDisplayName
    }
}

struct ServerProviderAuth: Decodable, Hashable, Sendable {
    let status: String
    let label: String?
    let email: String?
}

struct ServerProviderModel: Decodable, Hashable, Identifiable, Sendable {
    let slug: String
    let name: String
    let shortName: String?
    let isCustom: Bool

    var id: String { slug }
    var label: String { shortName ?? name }
}

extension ServerProvider {
    var defaultModel: String {
        models.first(where: { !$0.isCustom })?.slug
            ?? models.first?.slug
            ?? defaultModelSlug(for: driver)
    }

    func modelLabel(_ slug: String) -> String {
        models.first { $0.slug == slug }?.label ?? slug
    }

    private func defaultModelSlug(for driver: String) -> String {
        switch driver {
        case "claudeAgent":
            return "claude-sonnet-4-6"
        case "cursor":
            return "auto"
        case "opencode":
            return "openai/gpt-5"
        default:
            return "gpt-5.4"
        }
    }
}

private extension String {
    var providerDisplayName: String {
        replacingOccurrences(of: "([a-z])([A-Z])",
                              with: "$1 $2",
                              options: .regularExpression)
            .replacingOccurrences(of: "[-_]+",
                                  with: " ",
                                  options: .regularExpression)
            .capitalized
    }
}

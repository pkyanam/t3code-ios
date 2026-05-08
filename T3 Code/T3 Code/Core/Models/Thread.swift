import Foundation

enum RuntimeMode: String, Codable, Sendable {
    case approvalRequired = "approval-required"
    case autoAcceptEdits  = "auto-accept-edits"
    case fullAccess       = "full-access"
}

enum ProviderInteractionMode: String, Codable, Sendable {
    case `default`, plan
}

enum LatestTurnState: String, Codable, Sendable {
    case running, interrupted, completed, error
}

struct LatestTurn: Codable, Hashable, Sendable {
    let turnId: TurnID
    let state: LatestTurnState
    let requestedAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let assistantMessageId: MessageID?

    private enum CodingKeys: String, CodingKey {
        case turnId, state, requestedAt, startedAt, completedAt, assistantMessageId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        turnId = try c.decode(TurnID.self, forKey: .turnId)
        state = try c.decode(LatestTurnState.self, forKey: .state)
        requestedAt = try ISO8601Decoder.decodeDate(c, key: .requestedAt)
        startedAt = try (c.decodeIfPresent(String.self, forKey: .startedAt)).flatMap(ISO8601Decoder.parse)
        completedAt = try (c.decodeIfPresent(String.self, forKey: .completedAt)).flatMap(ISO8601Decoder.parse)
        assistantMessageId = try c.decodeIfPresent(MessageID.self, forKey: .assistantMessageId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(turnId, forKey: .turnId)
        try c.encode(state, forKey: .state)
        try c.encode(ISO8601Decoder.formatter.string(from: requestedAt), forKey: .requestedAt)
        if let startedAt { try c.encode(ISO8601Decoder.formatter.string(from: startedAt), forKey: .startedAt) }
        if let completedAt { try c.encode(ISO8601Decoder.formatter.string(from: completedAt), forKey: .completedAt) }
        try c.encodeIfPresent(assistantMessageId, forKey: .assistantMessageId)
    }
}

enum SessionStatus: String, Codable, Sendable {
    case idle, starting, running, ready, interrupted, stopped, error
}

struct OrchestrationSession: Codable, Hashable, Sendable {
    let threadId: ThreadID
    let status: SessionStatus
    let providerName: String?
    let providerInstanceId: ProviderInstanceID?
    let runtimeMode: RuntimeMode
    let activeTurnId: TurnID?
    let lastError: String?
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case threadId, status, providerName, providerInstanceId, runtimeMode, activeTurnId, lastError, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        threadId = try c.decode(ThreadID.self, forKey: .threadId)
        status = try c.decode(SessionStatus.self, forKey: .status)
        providerName = try c.decodeIfPresent(String.self, forKey: .providerName)
        providerInstanceId = try c.decodeIfPresent(ProviderInstanceID.self, forKey: .providerInstanceId)
        runtimeMode = (try? c.decode(RuntimeMode.self, forKey: .runtimeMode)) ?? .fullAccess
        activeTurnId = try c.decodeIfPresent(TurnID.self, forKey: .activeTurnId)
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
        updatedAt = try ISO8601Decoder.decodeDate(c, key: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(threadId, forKey: .threadId)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(providerName, forKey: .providerName)
        try c.encodeIfPresent(providerInstanceId, forKey: .providerInstanceId)
        try c.encode(runtimeMode, forKey: .runtimeMode)
        try c.encodeIfPresent(activeTurnId, forKey: .activeTurnId)
        try c.encodeIfPresent(lastError, forKey: .lastError)
        try c.encode(ISO8601Decoder.formatter.string(from: updatedAt), forKey: .updatedAt)
    }
}

struct ThreadShell: Codable, Hashable, Sendable, Identifiable {
    let id: ThreadID
    let projectId: ProjectID
    var title: String
    var modelSelection: ModelSelection
    var runtimeMode: RuntimeMode
    var interactionMode: ProviderInteractionMode
    var branch: String?
    var worktreePath: String?
    var latestTurn: LatestTurn?
    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var session: OrchestrationSession?
    var latestUserMessageAt: Date?
    var hasPendingApprovals: Bool
    var hasPendingUserInput: Bool
    var hasActionableProposedPlan: Bool

    private enum CodingKeys: String, CodingKey {
        case id, projectId, title, modelSelection, runtimeMode, interactionMode, branch,
             worktreePath, latestTurn, createdAt, updatedAt, archivedAt, session,
             latestUserMessageAt, hasPendingApprovals, hasPendingUserInput, hasActionableProposedPlan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ThreadID.self, forKey: .id)
        projectId = try c.decode(ProjectID.self, forKey: .projectId)
        title = try c.decode(String.self, forKey: .title)
        modelSelection = try c.decode(ModelSelection.self, forKey: .modelSelection)
        runtimeMode = try c.decode(RuntimeMode.self, forKey: .runtimeMode)
        interactionMode = (try? c.decode(ProviderInteractionMode.self, forKey: .interactionMode)) ?? .default
        branch = try c.decodeIfPresent(String.self, forKey: .branch)
        worktreePath = try c.decodeIfPresent(String.self, forKey: .worktreePath)
        latestTurn = try c.decodeIfPresent(LatestTurn.self, forKey: .latestTurn)
        createdAt = try ISO8601Decoder.decodeDate(c, key: .createdAt)
        updatedAt = try ISO8601Decoder.decodeDate(c, key: .updatedAt)
        archivedAt = (try c.decodeIfPresent(String.self, forKey: .archivedAt)).flatMap(ISO8601Decoder.parse)
        session = try c.decodeIfPresent(OrchestrationSession.self, forKey: .session)
        latestUserMessageAt = (try c.decodeIfPresent(String.self, forKey: .latestUserMessageAt))
            .flatMap(ISO8601Decoder.parse)
        hasPendingApprovals = (try? c.decode(Bool.self, forKey: .hasPendingApprovals)) ?? false
        hasPendingUserInput = (try? c.decode(Bool.self, forKey: .hasPendingUserInput)) ?? false
        hasActionableProposedPlan = (try? c.decode(Bool.self, forKey: .hasActionableProposedPlan)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(projectId, forKey: .projectId)
        try c.encode(title, forKey: .title)
        try c.encode(modelSelection, forKey: .modelSelection)
        try c.encode(runtimeMode, forKey: .runtimeMode)
        try c.encode(interactionMode, forKey: .interactionMode)
        try c.encodeIfPresent(branch, forKey: .branch)
        try c.encodeIfPresent(worktreePath, forKey: .worktreePath)
        try c.encodeIfPresent(latestTurn, forKey: .latestTurn)
        try c.encode(ISO8601Decoder.formatter.string(from: createdAt), forKey: .createdAt)
        try c.encode(ISO8601Decoder.formatter.string(from: updatedAt), forKey: .updatedAt)
        if let archivedAt { try c.encode(ISO8601Decoder.formatter.string(from: archivedAt), forKey: .archivedAt) }
        try c.encodeIfPresent(session, forKey: .session)
        if let latestUserMessageAt {
            try c.encode(ISO8601Decoder.formatter.string(from: latestUserMessageAt), forKey: .latestUserMessageAt)
        }
        try c.encode(hasPendingApprovals, forKey: .hasPendingApprovals)
        try c.encode(hasPendingUserInput, forKey: .hasPendingUserInput)
        try c.encode(hasActionableProposedPlan, forKey: .hasActionableProposedPlan)
    }
}

struct ThreadDetail: Hashable, Sendable, Identifiable {
    let id: ThreadID
    let projectId: ProjectID
    var title: String
    var modelSelection: ModelSelection
    var runtimeMode: RuntimeMode
    var interactionMode: ProviderInteractionMode
    var branch: String?
    var worktreePath: String?
    var latestTurn: LatestTurn?
    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var messages: [Message]
    var session: OrchestrationSession?
    var proposedPlans: [ProposedPlan]
    var activities: [ThreadActivity]
}

extension ThreadDetail {
    nonisolated static func decode(from any: Any) throws -> ThreadDetail {
        let data = try JSONSerialization.data(withJSONObject: any)
        guard let dict = any as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [],
                debugDescription: "ThreadDetail expected an object"))
        }
        let baseDict = dict.filter { key, _ in
            !["proposedPlans", "activities"].contains(key)
        }
        let baseData = try JSONSerialization.data(withJSONObject: baseDict)
        let decoder = JSONDecoder()
        let base = try decoder.decode(BaseThreadDetail.self, from: baseData)
        _ = data

        let proposedPlans: [ProposedPlan] = (dict["proposedPlans"] as? [[String: Any]] ?? [])
            .compactMap { ProposedPlan.decode(from: $0) }
        let activities: [ThreadActivity] = (dict["activities"] as? [[String: Any]] ?? [])
            .compactMap { ThreadActivity.decode(from: $0) }

        return ThreadDetail(
            id: base.id,
            projectId: base.projectId,
            title: base.title,
            modelSelection: base.modelSelection,
            runtimeMode: base.runtimeMode,
            interactionMode: base.interactionMode,
            branch: base.branch,
            worktreePath: base.worktreePath,
            latestTurn: base.latestTurn,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
            archivedAt: base.archivedAt,
            messages: base.messages.sorted { $0.createdAt < $1.createdAt },
            session: base.session,
            proposedPlans: proposedPlans,
            activities: activities
        )
    }
}

private struct BaseThreadDetail: Decodable {
    let id: ThreadID
    let projectId: ProjectID
    let title: String
    let modelSelection: ModelSelection
    let runtimeMode: RuntimeMode
    let interactionMode: ProviderInteractionMode
    let branch: String?
    let worktreePath: String?
    let latestTurn: LatestTurn?
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?
    let messages: [Message]
    let session: OrchestrationSession?

    private enum CodingKeys: String, CodingKey {
        case id, projectId, title, modelSelection, runtimeMode, interactionMode, branch,
             worktreePath, latestTurn, createdAt, updatedAt, archivedAt, messages, session
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ThreadID.self, forKey: .id)
        projectId = try c.decode(ProjectID.self, forKey: .projectId)
        title = try c.decode(String.self, forKey: .title)
        modelSelection = try c.decode(ModelSelection.self, forKey: .modelSelection)
        runtimeMode = try c.decode(RuntimeMode.self, forKey: .runtimeMode)
        interactionMode = (try? c.decode(ProviderInteractionMode.self, forKey: .interactionMode)) ?? .default
        branch = try c.decodeIfPresent(String.self, forKey: .branch)
        worktreePath = try c.decodeIfPresent(String.self, forKey: .worktreePath)
        latestTurn = try c.decodeIfPresent(LatestTurn.self, forKey: .latestTurn)
        createdAt = try ISO8601Decoder.decodeDate(c, key: .createdAt)
        updatedAt = try ISO8601Decoder.decodeDate(c, key: .updatedAt)
        archivedAt = (try c.decodeIfPresent(String.self, forKey: .archivedAt)).flatMap(ISO8601Decoder.parse)
        messages = (try? c.decode([Message].self, forKey: .messages)) ?? []
        session = try c.decodeIfPresent(OrchestrationSession.self, forKey: .session)
    }
}

struct ProjectShell: Codable, Hashable, Sendable, Identifiable {
    let id: ProjectID
    var title: String
    var workspaceRoot: String
    var defaultModelSelection: ModelSelection?
    let createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, title, workspaceRoot, defaultModelSelection, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ProjectID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        workspaceRoot = try c.decode(String.self, forKey: .workspaceRoot)
        defaultModelSelection = try c.decodeIfPresent(ModelSelection.self, forKey: .defaultModelSelection)
        createdAt = try ISO8601Decoder.decodeDate(c, key: .createdAt)
        updatedAt = try ISO8601Decoder.decodeDate(c, key: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(workspaceRoot, forKey: .workspaceRoot)
        try c.encodeIfPresent(defaultModelSelection, forKey: .defaultModelSelection)
        try c.encode(ISO8601Decoder.formatter.string(from: createdAt), forKey: .createdAt)
        try c.encode(ISO8601Decoder.formatter.string(from: updatedAt), forKey: .updatedAt)
    }
}

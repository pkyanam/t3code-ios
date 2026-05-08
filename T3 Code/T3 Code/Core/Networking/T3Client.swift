import Foundation

actor T3Client {
    private let connection: T3Connection
    private var pendingResponses: [String: CheckedContinuation<Any?, Error>] = [:]
    private var streamSubscribers: [String: (Any) -> Void] = [:]
    private var demuxTask: Task<Void, Never>?
    private var statusObserverTask: Task<Void, Never>?
    private(set) var status: T3Connection.ConnectionStatus = .offline
    private var statusListeners: [(T3Connection.ConnectionStatus) -> Void] = []

    init(connection: T3Connection) {
        self.connection = connection
    }

    @discardableResult
    func start() async -> Bool {
        let inbound = await connection.inboundStream()
        let status = await connection.statusStream()
        demuxTask = Task { [weak self] in
            for await msg in inbound {
                await self?.handle(msg)
            }
        }
        statusObserverTask = Task { [weak self] in
            for await s in status {
                await self?.update(status: s)
            }
        }
        return await connection.connect()
    }

    func stop() async {
        demuxTask?.cancel()
        statusObserverTask?.cancel()
        await connection.disconnect()
        pendingResponses.values.forEach { $0.resume(throwing: T3Error.notConnected) }
        pendingResponses.removeAll()
        streamSubscribers.removeAll()
    }

    func addStatusListener(_ listener: @escaping (T3Connection.ConnectionStatus) -> Void) {
        statusListeners.append(listener)
        listener(status)
    }

    private func update(status: T3Connection.ConnectionStatus) {
        self.status = status
        for listener in statusListeners {
            listener(status)
        }
    }

    private func handle(_ msg: EffectRPCMessage) async {
        switch msg {
        case let .exit(requestId, success, value, _, errorMessage):
            if let cont = pendingResponses.removeValue(forKey: requestId) {
                if success {
                    cont.resume(returning: value)
                } else {
                    cont.resume(throwing: T3Error.requestFailed(errorMessage ?? "unknown"))
                }
            }
            streamSubscribers.removeValue(forKey: requestId)
        case let .chunk(requestId, values):
            if let listener = streamSubscribers[requestId] {
                for v in values {
                    listener(v)
                }
                try? await connection.send([.ack(requestId: requestId)])
            }
        case .pong, .ping, .eof:
            break
        case let .defect(message):
            for cont in pendingResponses.values {
                cont.resume(throwing: T3Error.requestFailed(message))
            }
            pendingResponses.removeAll()
            streamSubscribers.removeAll()
        default:
            break
        }
    }

    func request(method: String, payload: Any) async throws -> Any? {
        let id = await connection.nextRequestId()
        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses[id] = continuation
            Task {
                do {
                    try await connection.send([
                        .request(id: id, tag: method, payload: payload, headers: [])
                    ])
                } catch {
                    pendingResponses.removeValue(forKey: id)?.resume(throwing: error)
                }
            }
        }
    }

    func subscribe(method: String,
                   payload: Any,
                   onValue: @escaping (Any) -> Void) async throws -> StreamSubscription {
        let id = await connection.nextRequestId()
        streamSubscribers[id] = onValue
        try await connection.send([
            .streamRequest(id: id, tag: method, payload: payload, headers: [])
        ])
        return StreamSubscription(client: self, requestId: id)
    }

    func cancel(requestId: String) async {
        streamSubscribers.removeValue(forKey: requestId)
        pendingResponses.removeValue(forKey: requestId)?
            .resume(throwing: CancellationError())
        try? await connection.send([
            .interrupt(requestId: requestId, interruptors: [])
        ])
    }
}

struct StreamSubscription: Sendable {
    private weak var client: T3Client?
    let requestId: String

    nonisolated init(client: T3Client, requestId: String) {
        self.client = client
        self.requestId = requestId
    }

    nonisolated func cancel() async {
        await client?.cancel(requestId: requestId)
    }
}

extension T3Client {
    func subscribeShell(onItem: @escaping (ShellStreamItem) -> Void)
    async throws -> StreamSubscription {
        try await subscribe(method: "orchestration.subscribeShell", payload: [String: Any]()) { value in
            do {
                let item = try ShellStreamItem.decode(from: value)
                onItem(item)
            } catch {
                NSLog("Failed to decode shell stream item: \(error)")
            }
        }
    }

    func subscribeThread(threadId: ThreadID,
                         onItem: @escaping (ThreadStreamItem) -> Void)
    async throws -> StreamSubscription {
        try await subscribe(method: "orchestration.subscribeThread",
                            payload: ["threadId": threadId.rawValue]) { value in
            do {
                let item = try ThreadStreamItem.decode(from: value)
                onItem(item)
            } catch {
                NSLog("Failed to decode thread stream item: \(error)")
            }
        }
    }

    func dispatchTurnStart(threadId: ThreadID,
                           text: String,
                           attachments: [UploadImage] = [],
                           modelSelection: ModelSelection?,
                           runtimeMode: RuntimeMode,
                           interactionMode: ProviderInteractionMode) async throws {
        let messageId = MessageID.newClientID().rawValue
        let commandId = CommandID.new().rawValue
        let now = ISO8601Decoder.formatter.string(from: Date())

        var payload: [String: Any] = [
            "type": "thread.turn.start",
            "commandId": commandId,
            "threadId": threadId.rawValue,
            "message": [
                "messageId": messageId,
                "role": "user",
                "text": text,
                "attachments": attachments.map { $0.encoded() }
            ],
            "runtimeMode": runtimeMode.rawValue,
            "interactionMode": interactionMode.rawValue,
            "createdAt": now
        ]
        if let modelSelection {
            payload["modelSelection"] = modelSelection.encoded
        }
        _ = try await request(method: "orchestration.dispatchCommand", payload: payload)
    }

    func createThreadAndStart(project: ProjectShell,
                              text: String,
                              attachments: [UploadImage] = [],
                              modelSelection: ModelSelection,
                              runtimeMode: RuntimeMode,
                              interactionMode: ProviderInteractionMode) async throws -> ThreadID {
        let threadId = ThreadID.new()
        let messageId = MessageID.newClientID().rawValue
        let commandId = CommandID.new().rawValue
        let now = ISO8601Decoder.formatter.string(from: Date())
        let titleSeed = Self.titleSeed(text: text, attachments: attachments)

        let payload: [String: Any] = [
            "type": "thread.turn.start",
            "commandId": commandId,
            "threadId": threadId.rawValue,
            "message": [
                "messageId": messageId,
                "role": "user",
                "text": text,
                "attachments": attachments.map { $0.encoded() }
            ],
            "modelSelection": modelSelection.encoded,
            "titleSeed": titleSeed,
            "runtimeMode": runtimeMode.rawValue,
            "interactionMode": interactionMode.rawValue,
            "bootstrap": [
                "createThread": [
                    "projectId": project.id.rawValue,
                    "title": titleSeed,
                    "modelSelection": modelSelection.encoded,
                    "runtimeMode": runtimeMode.rawValue,
                    "interactionMode": interactionMode.rawValue,
                    "branch": NSNull(),
                    "worktreePath": NSNull(),
                    "createdAt": now
                ]
            ],
            "createdAt": now
        ]

        _ = try await request(method: "orchestration.dispatchCommand", payload: payload)
        return threadId
    }

    func getServerConfig() async throws -> ServerRuntimeConfig {
        let value = try await request(method: "server.getConfig", payload: [String: Any]())
        guard let value else {
            throw T3Error.decodingFailed("Server returned an empty config response")
        }
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(ServerRuntimeConfig.self, from: data)
    }

    private static func titleSeed(text: String, attachments: [UploadImage]) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed: String
        if !trimmed.isEmpty {
            seed = trimmed
        } else if let first = attachments.first {
            seed = "Image: \(first.name)"
        } else {
            seed = "New thread"
        }
        if seed.count <= 80 {
            return seed
        }
        return String(seed.prefix(77)) + "..."
    }
}

struct UploadImage: Sendable {
    let name: String
    let mimeType: String
    let sizeBytes: Int
    let dataURL: String

    nonisolated func encoded() -> [String: Any] {
        [
            "type": "image",
            "name": name,
            "mimeType": mimeType,
            "sizeBytes": sizeBytes,
            "dataUrl": dataURL
        ]
    }
}

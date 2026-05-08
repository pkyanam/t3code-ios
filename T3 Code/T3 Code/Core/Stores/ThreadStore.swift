import Foundation
import Observation

@Observable
final class ThreadStore {
    let threadId: ThreadID
    var detail: ThreadDetail?
    var messages: [Message] = []
    var session: OrchestrationSession?
    var lastError: String?
    var isSending: Bool = false

    private var subscription: StreamSubscription?
    private weak var client: T3Client?

    init(threadId: ThreadID) {
        self.threadId = threadId
    }

    func start(client: T3Client) async {
        self.client = client
        subscription = try? await client.subscribeThread(threadId: threadId) { item in
            Task { @MainActor [weak self] in
                self?.handle(item: item)
            }
        }
    }

    func stop() async {
        if let sub = subscription { await sub.cancel() }
        subscription = nil
    }

    func sendMessage(text: String,
                     attachments: [UploadImage],
                     fallbackModelSelection: ModelSelection?) async {
        guard let client else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !attachments.isEmpty else { return }

        let resolvedSelection = detail?.modelSelection ?? fallbackModelSelection
        guard let modelSelection = resolvedSelection else {
            await MainActor.run { self.lastError = "No model selected" }
            return
        }

        await MainActor.run { self.isSending = true }
        defer { Task { @MainActor in self.isSending = false } }

        do {
            try await client.dispatchTurnStart(
                threadId: threadId,
                text: text,
                attachments: attachments,
                modelSelection: modelSelection,
                runtimeMode: detail?.runtimeMode ?? .fullAccess,
                interactionMode: detail?.interactionMode ?? .default
            )
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
        }
    }

    @MainActor
    private func handle(item: ThreadStreamItem) {
        switch item {
        case .snapshot(let detail, _):
            self.detail = detail
            self.messages = detail.messages.sorted { $0.createdAt < $1.createdAt }
            self.session = detail.session
        case .event(let event):
            apply(event)
        }
    }

    @MainActor
    private func apply(_ event: ThreadEvent) {
        switch event.type {
        case "thread.message-sent":
            guard let messageIdRaw = event.payload["messageId"] as? String,
                  let roleRaw = event.payload["role"] as? String,
                  let role = MessageRole(rawValue: roleRaw),
                  let text = event.payload["text"] as? String else { return }
            let createdAt = (event.payload["createdAt"] as? String).flatMap(ISO8601Decoder.parse) ?? Date()
            let updatedAt = (event.payload["updatedAt"] as? String).flatMap(ISO8601Decoder.parse) ?? createdAt
            let streaming = (event.payload["streaming"] as? Bool) ?? false
            let turnId = (event.payload["turnId"] as? String).map { TurnID(rawValue: $0) }
            let id = MessageID(rawValue: messageIdRaw)
            if let i = messages.firstIndex(where: { $0.id == id }) {
                messages[i].text = text
                messages[i].streaming = streaming
                messages[i].updatedAt = updatedAt
            } else {
                let msg = Message(id: id, role: role, text: text,
                                  attachments: nil, turnId: turnId,
                                  streaming: streaming, createdAt: createdAt,
                                  updatedAt: updatedAt)
                messages.append(msg)
                messages.sort { $0.createdAt < $1.createdAt }
            }
        case "thread.session-set":
            if let sessionDict = event.payload["session"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: sessionDict),
               let session = try? JSONDecoder().decode(OrchestrationSession.self, from: data) {
                self.session = session
            }
        case "thread.meta-updated":
            if var detail = self.detail {
                if let title = event.payload["title"] as? String { detail.title = title }
                self.detail = detail
            }
        default:
            break
        }
    }
}

extension Array where Element == Message {
    func mostRecentAssistantText() -> String? {
        last { $0.role == .assistant }?.text
    }
}

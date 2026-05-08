import SwiftUI
import PhotosUI

struct ComposerView: View {
    @Bindable var store: ThreadStore
    @State private var draft: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [LocalAttachment] = []
    @FocusState private var focused: Bool
    @AppStorage("composerSize") private var composerSizeRaw: String = ComposerSize.comfortable.rawValue
    @AppStorage("accent") private var accentRaw: String = AppAccent.blue.rawValue

    private let maxChars = 120_000
    private let maxAttachments = 8

    var body: some View {
        VStack(spacing: T3Spacing.sm) {
            if !attachments.isEmpty {
                attachmentRow
            }

            HStack(spacing: T3Spacing.md) {
                // Model selector
                Button {
                    // Model picker action
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .semibold))
                        Text(modelName)
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(T3Color.textSecondary)
                }

                // Text input
                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Ask anything, @tag files/folders, or use / to show available commands")
                            .foregroundStyle(T3Color.textTertiary)
                            .font(T3Typography.callout)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $draft)
                        .focused($focused)
                        .frame(height: editorHeight)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 0)
                        .padding(.vertical, 0)
                        .font(T3Typography.callout)
                }

                // Photos button
                PhotosPicker(selection: $pickerItems,
                             maxSelectionCount: maxAttachments,
                             matching: .images) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(attachments.count >= maxAttachments ? T3Color.textTertiary : T3Color.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .disabled(attachments.count >= maxAttachments)

                // Send button
                Button(action: send) {
                    Image(systemName: store.isSending ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(canSend ? Color.blue : T3Color.surfaceMuted)
                        .clipShape(Circle())
                }
                .disabled(!canSend || store.isSending)
            }
            .padding(.horizontal, T3Spacing.md)
            .padding(.vertical, T3Spacing.sm)
            .background(T3Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: T3Radius.lg, style: .continuous)
                    .stroke(focused ? accentColor.opacity(0.75) : T3Color.separator, lineWidth: focused ? 1 : 0.5)
            )
        }
        .padding(.horizontal, T3Spacing.lg)
        .padding(.top, T3Spacing.md)
        .padding(.bottom, T3Spacing.sm)
        .background(T3Color.surfaceGrouped)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
        .onChange(of: pickerItems) { _, items in
            Task { await loadAttachments(items) }
        }
    }

    private var modelName: String {
        store.detail?.modelSelection.model ?? "Claude Opus 4"
    }

    private var attachmentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: T3Spacing.sm) {
                ForEach(attachments) { attachment in
                    AttachmentChip(attachment: attachment) {
                        attachments.removeAll { $0.id == attachment.id }
                    }
                }
            }
            .padding(.horizontal, T3Spacing.md)
            .padding(.vertical, T3Spacing.sm)
        }
    }

    private var editorHeight: CGFloat {
        let lines = max(1, draft.components(separatedBy: .newlines).count)
        let textExtra = min(4, draft.count / 42)
        let visibleLines = min(composerSize.maxLines, max(1, lines + textExtra))
        return CGFloat(visibleLines) * 22 + 18
    }

    private var composerSize: ComposerSize {
        ComposerSize(rawValue: composerSizeRaw) ?? .comfortable
    }

    private var accentColor: Color {
        AppAccent.color(for: accentRaw)
    }

    private var canSend: Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!text.isEmpty || !attachments.isEmpty)
            && text.count <= maxChars
            && !store.isSending
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let uploads = attachments.map { $0.upload }
        draft = ""
        attachments = []
        pickerItems = []
        Task {
            await store.sendMessage(text: text,
                                    attachments: uploads,
                                    fallbackModelSelection: nil)
        }
    }

    private func loadAttachments(_ items: [PhotosPickerItem]) async {
        var loaded: [LocalAttachment] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            let name = "image-\(UUID().uuidString.prefix(6)).\(mime.split(separator: "/").last ?? "jpg")"
            let dataUrl = "data:\(mime);base64,\(data.base64EncodedString())"
            let upload = UploadImage(name: String(name),
                                     mimeType: mime,
                                     sizeBytes: data.count,
                                     dataURL: dataUrl)
            loaded.append(LocalAttachment(upload: upload, preview: data))
            if loaded.count >= maxAttachments { break }
        }
        await MainActor.run {
            attachments = loaded
        }
    }
}

struct LocalAttachment: Identifiable, Equatable {
    let id = UUID()
    let upload: UploadImage
    let preview: Data

    static func == (lhs: LocalAttachment, rhs: LocalAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

struct AttachmentChip: View {
    let attachment: LocalAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: attachment.preview) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: T3Radius.sm, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: T3Radius.sm)
                    .fill(T3Color.surfaceMuted)
                    .frame(width: 56, height: 56)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
        }
    }
}

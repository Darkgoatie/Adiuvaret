import SwiftUI
import DesignSystem
import ModelLibrary
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {
    let service: any ChatService
    @State private var draft = ""
    @FocusState private var focused: Bool
    @State private var editing: EditTarget?
    @State private var pending: [ChatFile] = []
    @Bindable private var launch = LaunchRouter.shared
    @State private var attachError: String?
    let openDrawer: () -> Void
    var turnFinished: () -> Void = {}
    var switchModel: (String) -> Void = { _ in }
    var openModels: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            if let banner = service.banner { BannerView(banner: banner).padding(.horizontal, Spacing.l).padding(.vertical, Spacing.s) }
            thread
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Composer(text: $draft, focused: $focused, isGenerating: service.isGenerating,
                     quickActions: AppSettings.shared.quickBarOn ? AppSettings.shared.shortcuts.filter { !$0.word.isEmpty } : [],
                     attachments: $pending, support: service.fileSupport, destination: service.fileDestination, error: $attachError,
                     send: { let t = draft; let files = pending; draft = ""; pending = []; Task { await service.send(t, attachments: files); turnFinished() } },
                     stop: service.stop)
        }
        .onAppear {
            if CommandLine.arguments.contains("-focus") { focused = true }
            takeIncomingFiles()
        }
        .onChange(of: launch.incomingFiles) { _, _ in takeIncomingFiles() }
        .onChange(of: launch.incomingError) { _, _ in takeIncomingFiles() }
        .onChange(of: service.isGenerating) { was, now in
            // VoiceOver users cannot see the stream finish, so say so; sighted users get a light tap.
            guard was, !now, case .assistant? = service.items.last else { return }
            AccessibilityNotification.Announcement(String(localized: "Reply ready")).post()
        }
        .sensoryFeedback(.success, trigger: service.isGenerating) { was, now in was && !now }
        .background(DS.Colors.background)
        .sheet(item: $editing) { target in
            EditMessageSheet(target: target, hasLater: hasItems(after: target.id)) { text in
                Task { await service.edit(target.id, text: text); turnFinished() }
            }
        }
    }

    private var chipKind: ModelPrivacyChip.Kind {
        if let (p, _) = Providers.parseModelID(service.modelID) { return .cloud(provider: p.name) }
        return service.modelID == ModelCatalog.appleID ? .onDevice : .localModel
    }

    /// Files shared to the app are added to this composer, up to the per-message limit; the rest are removed again.
    private func takeIncomingFiles() {
        if let e = launch.incomingError { attachError = e; launch.incomingError = nil }
        guard !launch.incomingFiles.isEmpty else { return }
        for f in launch.incomingFiles {
            if pending.count < AttachmentRules.maxPerMessage { pending.append(f) } else { AttachmentStore.remove([f]) }
        }
        launch.incomingFiles = []
    }

    private func hasItems(after id: UUID) -> Bool {
        guard let i = service.items.firstIndex(where: { $0.id == id }) else { return false }
        return i < service.items.count - 1
    }

    private func speedText(for item: ThreadItem) -> String? {
        guard AppSettings.shared.tokMeter, case .assistant(let id, _, false) = item else { return nil }
        return ReplyStats.shared.text(for: id)
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            Button(action: openDrawer) { Image(systemName: "line.3.horizontal").imageScale(.large).frame(width: 44, height: 44) }
                .accessibilityLabel(Text("Menu")).accessibilityIdentifier("chat.menu")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: service.title).font(DS.Typography.chatTitle).foregroundStyle(DS.Colors.textPrimary).lineLimit(2)
                modelMenu
            }
            Spacer(minLength: 0)
            if AppSettings.shared.contextRing {
                ContextRing(fraction: ContextMeter.fraction(used: contextUsed, window: contextWindow), used: contextUsed, window: contextWindow)
            }
            if WebSession.shared.hasPage {
                Button { WebSession.shared.panelVisible = true } label: { Image(systemName: "globe").imageScale(.large).frame(width: 44, height: 44) }
                    .accessibilityLabel(Text("Open the browser")).accessibilityIdentifier("chat.browser")
            }
            Menu {
                Button("Chat settings", systemImage: "slider.horizontal.3") {}
                Button("Pin", systemImage: "pin") {}
                Button("Export", systemImage: "square.and.arrow.up") {}
                Button("Delete", systemImage: "trash", role: .destructive) {}
            } label: { Image(systemName: "ellipsis").imageScale(.large).frame(width: 44, height: 44) }
                .accessibilityLabel(Text("More"))
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(.horizontal, Spacing.s)
        .padding(.bottom, Spacing.xs)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var contextWindow: Int { ContextMeter.window(for: service.modelID) }

    private var contextUsed: Int {
        var total = ContextMeter.overheadTokens
        for item in service.items {
            switch item {
            case .user(_, let t), .assistant(_, let t, _): total += ContextMeter.estimateTokens(t)
            default: break
            }
        }
        return total
    }

    private var modelMenu: some View {
        Menu {
            ForEach(ModelSettings.shared.choices) { choice in
                Button { switchModel(choice.id) } label: {
                    if choice.id == service.modelID { Label(choice.name, systemImage: "checkmark") } else { Text(verbatim: choice.name) }
                }
            }
            if !ModelSettings.shared.cloudChoices.isEmpty {
                Section(String(localized: "Online, sent to the provider")) {
                    ForEach(ModelSettings.shared.cloudChoices) { choice in
                        Button { switchModel(choice.id) } label: {
                            if choice.id == service.modelID { Label(choice.name, systemImage: "checkmark") } else { Label(choice.name, systemImage: "cloud") }
                        }
                    }
                }
            }
            Divider()
            Button("Manage models", systemImage: "cpu", action: openModels)
        } label: {
            HStack(spacing: Spacing.xs) {
                ModelPrivacyChip(model: service.modelName, kind: chipKind, prominent: false, themed: true)
                ModelStatusDot(state: ModelSettings.shared.loadState(service.modelID))
                Image(systemName: "chevron.down").imageScale(.small).foregroundStyle(DS.Colors.textSecondary).accessibilityHidden(true)
            }
            .frame(minHeight: 28)
        }
        .disabled(service.isGenerating)
        .accessibilityLabel(Text("Model: \(service.modelName)")).accessibilityHint(Text("Choose a different model"))
        .accessibilityIdentifier("chat.model")
        .task(id: service.modelID) { ModelSettings.shared.preload(service.modelID) }
    }

    @ViewBuilder private var thread: some View {
        if service.items.isEmpty {
            ScrollView { EmptyChat(pick: { t in Task { await service.send(t); turnFinished() } }).padding(.top, Spacing.xl) }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.l) {
                        ForEach(service.items) { item in
                            ItemView(item: item, service: service, speed: speedText(for: item))
                                .equatable()
                                .messageActions(item, service: service, editing: $editing, saved: turnFinished)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, Spacing.l).padding(.vertical, Spacing.m)
                }
                .scrollDismissesKeyboard(.interactively)
                .modifier(ThreadScrolling(proxy: proxy, service: service))
            }
        }
    }
}

/// Keeps the newest message in view. From iOS 18 the thread follows streaming text only while it was already at the bottom, so reading history is
/// never interrupted. On iOS 17 there is no way to measure that, so it scrolls to each new message and leaves streaming text where it is.
private struct ThreadScrolling: ViewModifier {
    let proxy: ScrollViewProxy
    let service: any ChatService

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .onScrollGeometryChange(for: ScrollEdges.self) { g in
                    ScrollEdges(offset: g.contentOffset.y, content: g.contentSize.height, container: g.containerSize.height)
                } action: { old, new in
                    // Follow new text only when the view was already at the bottom before it grew.
                    if new.content > old.content, old.isAtBottom, let last = service.items.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: service.items.count) { _, _ in
                    // A message the user just sent always shows.
                    if let last = service.items.last, case .user = last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
        } else {
            content
                .onAppear { if let last = service.items.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                .onChange(of: service.items.count) { _, _ in
                    if let last = service.items.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
        }
    }
}

private struct ScrollEdges: Equatable {
    var offset: CGFloat
    var content: CGFloat
    var container: CGFloat
    var isAtBottom: Bool { offset + container >= content - 40 }
}

private struct ItemView: View, Equatable {
    let item: ThreadItem
    let service: any ChatService
    /// A snapshot of what the row shows, a plain string so it can be compared from any thread.
    let key: String
    let speed: String?

    init(item: ThreadItem, service: any ChatService, speed: String? = nil) {
        self.item = item; self.service = service; self.speed = speed; self.key = item.renderKey + (speed ?? "") + ThemeStore.shared.theme.rawValue + ButtonEffectStore.shared.effect.rawValue
    }

    /// Two rows are the same when their content is, so a streaming reply redraws only itself instead of every earlier message.
    nonisolated static func == (a: ItemView, b: ItemView) -> Bool { a.key == b.key }

    var body: some View {
        switch item {
        case .user(_, let t): MessageBubble(role: .user, text: t)
        case .userFiles(_, let files): AttachmentRow(files: files)
        case .assistant(_, let t, let s):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                MessageBubble(role: .assistant, text: t, isStreaming: s)
                if let speed { SpeedLabel(text: speed) }
            }
        case .tool(_, let p, let t, let d): ToolProgressRow(phase: p, title: t, details: d)
        case .action(let id, let p, let t, let d, let o):
            ActionCard(phase: p, title: t, detail: d, openTitle: o, onUndo: { service.undo(id) })
        case .approval(let id, let p, let t, let rows):
            ApprovalCard(phase: p, title: t, rows: rows, actionsEnabled: service.banner != .killSwitch,
                         onApprove: { service.approve(id) }, onDeny: { service.deny(id) })
        case .draft(_, let k, let to, let t): DraftCard(kind: k, recipient: to, text: t)
        case .memory(let id, let t): MemoryChip(text: t, onUndo: { service.undo(id) }, onWhy: {})
        case .skillOffer(let id, let p, let t): SkillOfferCard(phase: p, title: t, onSave: { service.approve(id) }, onDismiss: { service.deny(id) })
        case .error(_, let t): ErrorMessageRow(message: t, onRetry: { Task { await service.retry() } })
        }
    }
}

private struct BannerView: View {
    let banner: ChatBanner
    var body: some View {
        switch banner {
        case .appleIntelligenceUnavailable: SystemBanner(kind: .error, message: String(localized: "Apple Intelligence isn't turned on, so I can't answer yet."), actionTitle: String(localized: "Open Settings"))
        case .noModel: SystemBanner(kind: .warning, message: String(localized: "There is no model to answer with yet. Connect an online model in Settings, Providers, or download one in Models."))
        case .offline: SystemBanner(kind: .info, message: String(localized: "You're offline. Everything I do still stays on your iPhone."))
        case .thermal: SystemBanner(kind: .warning, message: String(localized: "Your iPhone is warm, so I'll answer more slowly."))
        case .killSwitch: SystemBanner(kind: .warning, message: String(localized: "Actions are switched off. I can talk, but I won't change anything."))
        }
    }
}

private struct EmptyChat: View {
    let pick: (String) -> Void
    private let suggestions = [
        String(localized: "What's on my calendar today?"), String(localized: "Remind me to call mom at 6"),
        String(localized: "Summarize my week"), String(localized: "Draft a message to Ana"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Hi Halit, what can I take off your plate?").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
            VStack(spacing: Spacing.s) {
                ForEach(suggestions, id: \.self) { s in
                    Button { pick(s) } label: { Text(verbatim: s).frame(maxWidth: .infinity, alignment: .leading) }
                        .buttonStyle(DSButtonStyle(.secondary))
                }
            }
        }
        .padding(.horizontal, Spacing.l)
    }
}

struct Composer: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let isGenerating: Bool
    let quickActions: [QuickShortcut]
    @Binding var attachments: [ChatFile]
    let support: AttachmentSupport
    let destination: String?
    @Binding var error: String?
    let send: () -> Void
    let stop: () -> Void

    @State private var pickingFile = false
    @State private var pickingPhoto = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var takingPhoto = false

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty || !attachments.isEmpty }

    private func add(_ a: ChatFile) {
        guard attachments.count < AttachmentRules.maxPerMessage else { AttachmentStore.remove([a]); error = String(localized: "You can attach up to \(AttachmentRules.maxPerMessage) files."); return }
        attachments.append(a); error = nil
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            do { add(try AttachmentStore.importFile(url)) } catch { self.error = (error as? AttachmentError)?.message ?? AttachmentError.unreadable.message }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let a = AttachmentStore.importPhoto(data: data) { add(a) }
            else { error = AttachmentError.unreadable.message }
        }
        photoItems = []
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            if !attachments.isEmpty || error != nil {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if !attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.s) {
                                ForEach(attachments) { a in
                                    AttachmentChip(attachment: a, onRemove: { attachments.removeAll { $0.id == a.id }; AttachmentStore.remove([a]) })
                                }
                            }
                        }
                    }
                    if let note = fileNote { Text(verbatim: note).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
                    if let error { Text(verbatim: error).font(DS.Typography.caption).foregroundStyle(DS.Colors.danger) }
                }
                .padding(.horizontal, Spacing.l).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !quickActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        ForEach(quickActions) { a in
                            Button(a.word) { text = a.prompt; focused.wrappedValue = true }.buttonStyle(DSButtonStyle(.secondary)).font(DS.Typography.footnote)
                        }
                    }.padding(.horizontal, Spacing.l)
                }
            }
            HStack(alignment: .bottom, spacing: Spacing.s) {
                Menu {
                    Button(String(localized: "Photo library"), systemImage: "photo.on.rectangle") { pickingPhoto = true }
                    Button(String(localized: "Take a photo"), systemImage: "camera") { takingPhoto = true }
                    Button(String(localized: "Choose a file"), systemImage: "doc") { pickingFile = true }
                } label: { Image(systemName: "plus").imageScale(.large).foregroundStyle(DS.Colors.textPrimary).frame(width: 44, height: 44).background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m)) }
                    .accessibilityLabel(Text("Attach")).accessibilityIdentifier("composer.attach")
                    .photosPicker(isPresented: $pickingPhoto, selection: $photoItems, maxSelectionCount: AttachmentRules.maxPerMessage, matching: .images)
                    .onChange(of: photoItems) { _, items in Task { await importPhotos(items) } }
                    .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.item], allowsMultipleSelection: true, onCompletion: importFiles)
                    .fullScreenCover(isPresented: $takingPhoto) {
                        CameraPicker(isPresented: $takingPhoto) { data in if let a = AttachmentStore.importPhoto(data: data) { add(a) } }.ignoresSafeArea()
                    }
                TextField(String(localized: "Message Adiuvaret"), text: $text, axis: .vertical)
                    .font(DS.Typography.body).lineLimit(1...6).focused(focused)
                    .padding(.horizontal, Spacing.m).padding(.vertical, Spacing.m)
                    .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.l))
                    .overlay(RoundedRectangle(cornerRadius: Radius.l).stroke(DS.Colors.separator, lineWidth: 0.5))
                    .accessibilityIdentifier("composer.field")
                Button(action: isGenerating ? stop : send) {
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up").imageScale(.large).fontWeight(.semibold).frame(width: 44, height: 44)
                        .foregroundStyle(DS.Colors.onAccent).background { EffectBackground(cornerRadius: Radius.m, flat: DS.Colors.accent, active: isGenerating || canSend) }
                }
                .disabled(!isGenerating && !canSend)
                .opacity(!isGenerating && !canSend ? 0.4 : 1)
                .accessibilityLabel(Text(isGenerating ? "Stop" : "Send")).accessibilityIdentifier("composer.send")
                .sensoryFeedback(.impact(weight: .light), trigger: isGenerating)
            }
            .padding(.horizontal, Spacing.l)
        }
        .padding(.vertical, Spacing.s)
        .background(DS.Colors.background)
    }

    /// Tells the user, before sending, what this model will and will not do with the files, and where they go.
    private var fileNote: String? {
        guard !attachments.isEmpty else { return nil }
        var parts: [String] = []
        if attachments.contains(where: { $0.kind == .image }), !support.images {
            parts.append(String(localized: "This model can't view pictures. Pick another model to send them."))
        }
        if let destination { parts.append(String(localized: "Attached files are sent to \(destination).")) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

/// The camera, as a full-screen picker. Returns JPEG data.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let picked: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) { parent.picked(data) }
            parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isPresented = false }
    }
}

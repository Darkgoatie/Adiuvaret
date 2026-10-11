import SwiftUI
import DesignSystem
import ModelLibrary

struct ChatView: View {
    let service: any ChatService
    @State private var draft = ""
    @FocusState private var focused: Bool
    @State private var editing: EditTarget?
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
                     quickActions: service.items.isEmpty ? [] : quick,
                     send: { let t = draft; draft = ""; Task { await service.send(t); turnFinished() } },
                     stop: service.stop)
        }
        .onAppear { if CommandLine.arguments.contains("-focus") { focused = true } }
        .background(DS.Colors.background)
        .sheet(item: $editing) { target in
            EditMessageSheet(target: target, hasLater: hasItems(after: target.id)) { text in
                Task { await service.edit(target.id, text: text); turnFinished() }
            }
        }
    }

    private var chipKind: ModelPrivacyChip.Kind {
        if let (p, _) = Providers.parseModelID(service.modelID) { return .cloud(provider: p.name) }
        return service.modelID == "apple" ? .onDevice : .localModel
    }

    private func hasItems(after id: UUID) -> Bool {
        guard let i = service.items.firstIndex(where: { $0.id == id }) else { return false }
        return i < service.items.count - 1
    }

    private var quick: [String] {
        [String(localized: "Today"), String(localized: "Add reminder"), String(localized: "Draft message"), String(localized: "Find a time")]
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
                ModelPrivacyChip(model: service.modelName, kind: chipKind, prominent: false)
                ModelStatusDot(state: ModelSettings.shared.loadState(service.modelID))
                Image(systemName: "chevron.down").imageScale(.small).foregroundStyle(DS.Colors.textSecondary)
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
                            ItemView(item: item, service: service)
                                .messageActions(item, service: service, editing: $editing, saved: turnFinished)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, Spacing.l).padding(.vertical, Spacing.m)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .onChange(of: service.items.count) { _, _ in
                    if let last = service.items.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
        }
    }
}

private struct ItemView: View {
    let item: ThreadItem
    let service: any ChatService

    var body: some View {
        switch item {
        case .user(_, let t): MessageBubble(role: .user, text: t)
        case .assistant(_, let t, let s): MessageBubble(role: .assistant, text: t, isStreaming: s)
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
    let quickActions: [String]
    let send: () -> Void
    let stop: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s) {
            if !quickActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        ForEach(quickActions, id: \.self) { a in
                            Button(a) { text = a }.buttonStyle(DSButtonStyle(.secondary)).font(DS.Typography.footnote)
                        }
                    }.padding(.horizontal, Spacing.l)
                }
            }
            HStack(alignment: .bottom, spacing: Spacing.s) {
                Menu {
                    Button("Attach clipboard", systemImage: "doc.on.clipboard") {}
                    Button("Start a note", systemImage: "note.text.badge.plus") {}
                } label: { Image(systemName: "plus").imageScale(.large).foregroundStyle(DS.Colors.textPrimary).frame(width: 44, height: 44).background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m)) }
                    .accessibilityLabel(Text("Add"))
                TextField(String(localized: "Message Adiuvaret"), text: $text, axis: .vertical)
                    .font(DS.Typography.body).lineLimit(1...6).focused(focused)
                    .padding(.horizontal, Spacing.m).padding(.vertical, Spacing.m)
                    .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.l))
                    .overlay(RoundedRectangle(cornerRadius: Radius.l).stroke(DS.Colors.separator, lineWidth: 0.5))
                    .accessibilityIdentifier("composer.field")
                Button(action: isGenerating ? stop : send) {
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up").imageScale(.large).fontWeight(.semibold).frame(width: 44, height: 44)
                        .foregroundStyle(DS.Colors.onAccent).background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: Radius.m))
                }
                .disabled(!isGenerating && text.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(!isGenerating && text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .accessibilityLabel(Text(isGenerating ? "Stop" : "Send")).accessibilityIdentifier("composer.send")
                .sensoryFeedback(.impact(weight: .light), trigger: isGenerating)
            }
            .padding(.horizontal, Spacing.l)
        }
        .padding(.vertical, Spacing.s)
        .background(DS.Colors.background)
    }
}

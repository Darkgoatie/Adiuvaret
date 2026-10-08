import SwiftUI
import WebKit
import DesignSystem

/// The browser the assistant uses. Always in the view tree so pages keep running; shown full screen on request,
/// so the user can watch, sign in or solve a CAPTCHA themselves.
struct WebPanel: View {
    let session = WebSession.shared

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if let move = session.blocked { blockedBar(move) }
            WebViewHost(webView: session.webView)
                .overlay(alignment: .top) { if session.isLoading { ProgressView().progressViewStyle(.linear).tint(DS.Colors.accent) } }
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .opacity(session.panelVisible ? 1 : 0)
        .allowsHitTesting(session.panelVisible)
        .accessibilityHidden(!session.panelVisible)
        .animation(.easeOut(duration: 0.2), value: session.panelVisible)
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.s) {
            Button { session.goBack() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .disabled(!session.canGoBack).accessibilityLabel(Text("Back")).accessibilityIdentifier("web.back")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill").imageScale(.small).foregroundStyle(DS.Colors.accentText)
                    Text(verbatim: session.host).font(DS.Typography.subheadline).lineLimit(1)
                }
                Text(session.agentActing ? String(localized: "Adiuvaret is using this page") : session.title)
                    .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { session.reload() } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }
                .accessibilityLabel(Text("Reload")).accessibilityIdentifier("web.reload")
            Button("Done") { session.panelVisible = false }
                .font(DS.Typography.body).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
                .accessibilityIdentifier("web.done")
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(.horizontal, Spacing.s)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func blockedBar(_ move: WebSession.BlockedMove) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("This page wants to go to \(move.host). I stayed here because that site is not part of this task.")
                .font(DS.Typography.caption)
            HStack(spacing: Spacing.l) {
                Button("Allow \(move.host)") { session.allowBlockedMove() }.foregroundStyle(DS.Colors.accentText)
                Button("Stay here") { session.dismissBlockedMove() }.foregroundStyle(DS.Colors.textSecondary)
            }
            .font(DS.Typography.body).frame(minHeight: 44)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surfaceRaised)
    }
}

private struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview("Browser") { WebPanel() }

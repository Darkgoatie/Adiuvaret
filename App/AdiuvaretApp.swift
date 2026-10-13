import SwiftUI
import DesignSystem
import Diagnostics
import UserNotifications

@main
struct AdiuvaretApp: App {
    init() {
        DesignSystemFonts.register()
        DownloadKeepAlive.registerAll()
        BriefingHub.registerBackground()
        UNUserNotificationCenter.current().delegate = BriefingNotificationDelegate.shared
        let info = Bundle.main.infoDictionary
        DiagnosticsLog.shared.record("launch", "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))")
    }

    var body: some Scene {
        WindowGroup {
            if CommandLine.arguments.contains("-gallery") {
                NavigationStack { DesignGallery() }
            } else {
                RootView()
            }
        }
    }
}

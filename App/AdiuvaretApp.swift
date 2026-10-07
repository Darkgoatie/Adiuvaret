import SwiftUI
import DesignSystem

@main
struct AdiuvaretApp: App {
    init() { DesignSystemFonts.register() }

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

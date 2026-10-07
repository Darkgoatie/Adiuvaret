import SwiftUI
import DesignSystem

@main
struct AdiuvaretApp: App {
    init() { DesignSystemFonts.register() }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}

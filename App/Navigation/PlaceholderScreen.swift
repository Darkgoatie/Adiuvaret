import SwiftUI
import DesignSystem

/// Stands in for destinations that later tasks build.
struct PlaceholderScreen: View {
    let title: String
    let icon: String
    var body: some View {
        EmptyState(icon: icon, title: title, message: String(localized: "This part of Adiuvaret is still being built."))
            .frame(maxHeight: .infinity)
            .background(DS.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

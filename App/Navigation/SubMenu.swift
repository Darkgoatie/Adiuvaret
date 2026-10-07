import SwiftUI
import DesignSystem

/// A list of sub-screens opened from the drawer's Advanced and Settings rows.
struct SubMenu<Extra: View>: View {
    let title: String
    let items: [SubItem]
    let extra: Extra

    init(title: String, items: [SubItem], @ViewBuilder extra: () -> Extra) {
        self.title = title; self.items = items; self.extra = extra()
    }

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item.route) {
                    Label { Text(verbatim: item.title).font(DS.Typography.body) } icon: { Image(systemName: item.symbol) }
                        .frame(minHeight: 44)
                }
            }
            extra
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension SubMenu where Extra == EmptyView {
    init(title: String, items: [SubItem]) { self.init(title: title, items: items) { EmptyView() } }
}

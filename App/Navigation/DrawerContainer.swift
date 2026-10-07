import SwiftUI
import DesignSystem

/// Slide-over drawer: edge drag or menu button opens it, dimmed overlay or drag closes it.
struct DrawerContainer<Content: View, Drawer: View>: View {
    @Binding var isOpen: Bool
    let content: Content
    let drawer: Drawer
    @GestureState private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isOpen: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder drawer: () -> Drawer) {
        _isOpen = isOpen; self.content = content(); self.drawer = drawer()
    }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.86, 360)
            let offset = max(-width, min(0, (isOpen ? 0 : -width) + drag))
            ZStack(alignment: .leading) {
                content
                    .accessibilityHidden(isOpen)
                    .disabled(isOpen)
                if offset > -width {
                    Color.black.opacity(0.35 * (1 + Double(offset / width)))
                        .ignoresSafeArea(.container)
                        .onTapGesture { close() }
                        .accessibilityHidden(true)
                }
                drawer
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .background(DS.Colors.background.ignoresSafeArea(.container))
                    .offset(x: offset)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityHidden(!isOpen)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .updating($drag) { v, state, _ in
                        let fromEdge = !isOpen && v.startLocation.x < 24
                        if isOpen || fromEdge { state = v.translation.width }
                    }
                    .onEnded { v in
                        let fromEdge = !isOpen && v.startLocation.x < 24
                        if isOpen, v.translation.width < -width / 3 { close() }
                        else if fromEdge, v.translation.width > width / 3 { open() }
                    }
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isOpen)
        }
    }

    private func close() { isOpen = false }
    private func open() { isOpen = true }
}

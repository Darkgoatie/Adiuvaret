import SwiftUI
import DesignSystem

/// Slide-over drawer: edge drag or menu button opens it, dimmed overlay or drag closes it.
/// The chat is the base view so the system keyboard layout applies to it directly.
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
        content
            .accessibilityHidden(isOpen)
            .disabled(isOpen)
            .overlay { layer }
            .simultaneousGesture(openGesture)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isOpen)
    }

    private var layer: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.86, 360)
            let offset = max(-width, min(0, (isOpen ? 0 : -width) + drag))
            ZStack(alignment: .leading) {
                if offset > -width {
                    Color.black.opacity(0.35 * (1 + Double(offset / width)))
                        .ignoresSafeArea()
                        .onTapGesture { isOpen = false }
                        .accessibilityHidden(true)
                }
                drawer
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .background(DS.Colors.background.ignoresSafeArea())
                    .offset(x: offset)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityHidden(!isOpen)
                    .gesture(closeGesture(width: width))
            }
        }
        .ignoresSafeArea(.keyboard)
        .allowsHitTesting(isOpen || drag > 0)
    }

    private var openGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($drag) { v, state, _ in
                if !isOpen, v.startLocation.x < 24 { state = max(0, v.translation.width) }
            }
            .onEnded { v in
                if !isOpen, v.startLocation.x < 24, v.translation.width > 100 { isOpen = true }
            }
    }

    private func closeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($drag) { v, state, _ in if isOpen { state = min(0, v.translation.width) } }
            .onEnded { v in if isOpen, v.translation.width < -width / 3 { isOpen = false } }
    }
}

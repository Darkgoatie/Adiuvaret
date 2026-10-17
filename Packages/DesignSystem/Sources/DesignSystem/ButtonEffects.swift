import SwiftUI
import Observation

/// How filled (primary) buttons are painted. Flat is the original look and the default.
public enum ButtonEffect: String, CaseIterable, Identifiable, Sendable {
    case flat, gradient, glow

    public var id: String { rawValue }
    public static let `default`: ButtonEffect = .flat

    public var title: String {
        switch self {
        case .flat: "Flat"
        case .gradient: "Gradient"
        case .glow: "Gradient with glow"
        }
    }

    /// An unknown or missing stored value gives the default.
    public static func resolve(_ raw: String?) -> ButtonEffect { raw.flatMap(ButtonEffect.init(rawValue:)) ?? .default }
}

/// The chosen button effect. Observable, so open screens repaint when it changes. Only set from the Theme screen.
@Observable
public final class ButtonEffectStore: @unchecked Sendable {
    public static let shared = ButtonEffectStore()
    public static let key = "settings.buttonEffect"

    public var effect: ButtonEffect {
        didSet { UserDefaults.standard.set(effect.rawValue, forKey: Self.key) }
    }

    private init() { effect = ButtonEffect.resolve(UserDefaults.standard.string(forKey: Self.key)) }
}

/// The numbers behind a slow-moving gradient: a gradient six times as wide as the button slides from one end to the other and back.
public enum GradientMath {
    public static let period: Double = 16
    public static let widthFactor: Double = 6

    /// 0 at the start, 1 half a period later, back to 0 at the end of the period; constant speed (a triangle wave).
    public static func phase(at time: Double, period: Double = period) -> Double {
        guard period > 0 else { return 0 }
        var x = time.truncatingRemainder(dividingBy: period) / period
        if x < 0 { x += 1 }
        return x < 0.5 ? x * 2 : (1 - x) * 2
    }

    /// Start and end of a CSS-style gradient line at `angle` degrees over a box, in unit coordinates of that box (they may lie outside 0...1).
    public struct Line: Equatable, Sendable { public let sx, sy, ex, ey: Double }

    public static func line(width: Double, height: Double, angle: Double = -45) -> Line {
        let a = angle * .pi / 180
        let dx = sin(a), dy = -cos(a)
        let length = abs(width * sin(a)) + abs(height * cos(a))
        let cx = width / 2, cy = height / 2
        guard width > 0, height > 0 else { return Line(sx: 0, sy: 0.5, ex: 1, ey: 0.5) }
        return Line(sx: (cx - dx * length / 2) / width, sy: (cy - dy * length / 2) / height,
                    ex: (cx + dx * length / 2) / width, ey: (cy + dy * length / 2) / height)
    }

    /// How far the wide gradient is shifted left inside a button of `visible` width at a given phase.
    public static func shift(visible: Double, phase: Double, factor: Double = widthFactor) -> Double {
        -(visible * factor - visible) * phase
    }
}

/// The gradient colours, for places that paint a static gradient (a ring, a stroke).
public enum EffectColors {
    public static var gradient: LinearGradient {
        LinearGradient(colors: MovingGradient.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A rounded background that follows the chosen effect. `active` false paints the flat colour.
public struct EffectBackground: View {
    public let cornerRadius: CGFloat
    public let flat: Color
    public let active: Bool
    public init(cornerRadius: CGFloat, flat: Color, active: Bool = true) {
        self.cornerRadius = cornerRadius; self.flat = flat; self.active = active
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        switch active ? ButtonEffectStore.shared.effect : .flat {
        case .flat:
            shape.fill(flat)
        case .gradient:
            MovingGradient().clipShape(shape)
        case .glow:
            MovingGradient().clipShape(shape)
                .background { MovingGradient().clipShape(shape).blur(radius: 12).opacity(0.8).offset(y: 7) }
        }
    }
}

public extension View {
    /// Text or an icon in `flat` colour, or filled with the moving gradient when a gradient effect is chosen.
    func effectForeground(flat: Color) -> some View {
        modifier(EffectForeground(flat: flat))
    }
}

private struct EffectForeground: ViewModifier {
    let flat: Color
    func body(content: Content) -> some View {
        if ButtonEffectStore.shared.effect == .flat {
            content.foregroundStyle(flat)
        } else {
            content.foregroundStyle(.clear).overlay { MovingGradient().mask { content } }
        }
    }
}

/// The four-colour gradient that slides slowly behind a button label. Standing still when Reduce Motion is on.
public struct MovingGradient: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public static let colors: [Color] = [
        Color(red: 1.0, green: 0.651, blue: 0.239),   // #FFA63D
        Color(red: 1.0, green: 0.239, blue: 0.467),   // #FF3D77
        Color(red: 0.2, green: 0.541, blue: 1.0),     // #338AFF
        Color(red: 0.235, green: 0.941, blue: 0.773), // #3CF0C5
    ]

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let phase = reduceMotion ? 0.3 : GradientMath.phase(at: context.date.timeIntervalSinceReferenceDate)
                let wide = geo.size.width * GradientMath.widthFactor
                let line = GradientMath.line(width: wide, height: geo.size.height)
                LinearGradient(colors: Self.colors, startPoint: UnitPoint(x: line.sx, y: line.sy), endPoint: UnitPoint(x: line.ex, y: line.ey))
                    .frame(width: wide, height: geo.size.height)
                    .offset(x: GradientMath.shift(visible: geo.size.width, phase: phase))
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

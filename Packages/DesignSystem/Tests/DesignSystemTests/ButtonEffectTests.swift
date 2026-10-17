import Testing
@testable import DesignSystem

@Suite struct ButtonEffectTests {
    @Test func flatIsTheDefaultAndOriginalLook() {
        #expect(ButtonEffect.default == .flat && ButtonEffect.allCases.first == .flat)
        #expect(ButtonEffect.resolve(nil) == .flat && ButtonEffect.resolve("junk") == .flat)
        for e in ButtonEffect.allCases { #expect(ButtonEffect.resolve(e.rawValue) == e) }
        #expect(Set(ButtonEffect.allCases.map(\.title)).count == ButtonEffect.allCases.count)
    }

    @Test func phaseGoesOutAndBackAtConstantSpeed() {
        #expect(GradientMath.phase(at: 0) == 0)
        #expect(GradientMath.phase(at: 8) == 1)
        #expect(GradientMath.phase(at: 16) == 0)
        #expect(abs(GradientMath.phase(at: 4) - 0.5) < 1e-9 && abs(GradientMath.phase(at: 12) - 0.5) < 1e-9)
        #expect(abs(GradientMath.phase(at: 20) - GradientMath.phase(at: 4)) < 1e-9)
        for t in stride(from: -40.0, through: 40.0, by: 0.7) {
            let p = GradientMath.phase(at: t)
            #expect(p >= 0 && p <= 1, Comment(rawValue: "\(t)"))
        }
        #expect(GradientMath.phase(at: 5, period: 0) == 0)
    }

    @Test func shiftSlidesThroughTheWholeWideGradient() {
        #expect(GradientMath.shift(visible: 300, phase: 0) == 0)
        #expect(GradientMath.shift(visible: 300, phase: 1) == -1500)
        #expect(GradientMath.shift(visible: 300, phase: 0.5) == -750)
    }

    @Test func gradientLineMatchesTheCSSAngle() {
        let l = GradientMath.line(width: 1800, height: 100)
        #expect(abs(l.sx - 0.7638888889) < 1e-6 && abs(l.ex - 0.2361111111) < 1e-6)
        #expect(abs(l.sy - 5.25) < 1e-6 && abs(l.ey - -4.25) < 1e-6)
        let flat = GradientMath.line(width: 100, height: 100, angle: 90)
        #expect(abs(flat.sx) < 1e-9 && abs(flat.ex - 1) < 1e-9 && abs(flat.sy - 0.5) < 1e-9 && abs(flat.ey - 0.5) < 1e-9)
        #expect(GradientMath.line(width: 0, height: 10) == GradientMath.Line(sx: 0, sy: 0.5, ex: 1, ey: 0.5))
    }

    @Test func darkLabelStaysReadableOnEveryGradientColour() {
        let colours: [UInt32] = [0xFFA63D, 0xFF3D77, 0x338AFF, 0x3CF0C5]
        let label = RGB(hex: 0x10201A)
        for c in colours { #expect(label.contrast(with: RGB(hex: c)) >= 4.5, Comment(rawValue: String(c, radix: 16))) }
    }
}

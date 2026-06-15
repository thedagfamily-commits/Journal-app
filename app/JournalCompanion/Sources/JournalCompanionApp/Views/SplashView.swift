import SwiftUI

/// Full-screen "Plasma Bloom" shader background, ported from the
/// `shaders.js` wallpaper prototype (design_notes.md "liquid glass" splash
/// direction). Drawn behind onboarding/splash content; tap to ripple.
struct PlasmaBloomBackground: View {
    let startDate: Date

    @State private var touch = CGPoint(x: 0.5, y: 0.55)
    @State private var touchActive: Float = 0
    @State private var ripple = SIMD4<Float>(0.5, 0.55, -10, 0)

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let size = proxy.size
                let time = Float(timeline.date.timeIntervalSince(startDate))

                Rectangle()
                    .fill(.white)
                    .colorEffect(
                        ShaderLibrary.plasmaBloom(
                            .float2(Float(size.width), Float(size.height)),
                            .float(time),
                            .float2(Float(touch.x), Float(touch.y)),
                            .float(touchActive),
                            .float4(ripple.x, ripple.y, ripple.z, ripple.w)
                        )
                    )
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let nx = Float(value.location.x / max(size.width, 1))
                                let ny = Float(value.location.y / max(size.height, 1))
                                touch = CGPoint(x: CGFloat(nx), y: CGFloat(ny))
                                if touchActive == 0 {
                                    ripple = SIMD4(nx, ny, time, 1.0)
                                }
                                touchActive = 1
                            }
                            .onEnded { _ in
                                touchActive = 0
                            }
                    )
            }
        }
    }
}

/// Splash / onboarding entry screen: the morphing Plasma Bloom background
/// persists while the user reads the welcome message and continues into the
/// app (design_notes.md: "onboarding feels like already being inside the
/// space rather than a loading screen before the app starts").
struct SplashView: View {
    var onContinue: () -> Void

    @State private var startDate = Date()

    var body: some View {
        ZStack {
            PlasmaBloomBackground(startDate: startDate)

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 6) {
                    Text("Journal Companion")
                        .font(.system(.largeTitle, design: .serif, weight: .medium))
                    Text("a quiet place to notice your days")
                        .font(.system(.body, design: .serif))
                        .italic()
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                }
                .glassEffect(.regular.interactive(), in: Capsule())
                .padding(.bottom, 48)
            }
        }
        .foregroundStyle(Color(red: 0.2, green: 0.15, blue: 0.11))
    }
}

#Preview {
    SplashView(onContinue: {})
}

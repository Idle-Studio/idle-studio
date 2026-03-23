import SwiftUI

// MARK: - EraAtmosphereBackground

/// Full-screen background layer for GameplayScreen.
///
/// Layers (bottom → top):
///   1. Era artwork image — blurred, opacity scales with `totalUnitCount`
///   2. Dark readability gradient — always present
///   3. Ambient particles — Canvas + TimelineView, no SwiftUI view allocation
///
/// Pure View — no `@State`, no `@Observable`. All particle animation is driven by
/// deterministic math on `TimelineView` time so the render path has zero state mutations.
public struct EraAtmosphereBackground: View {

    // MARK: - Inputs

    public let artworkAsset: String
    public let primaryColor: Color
    public let secondaryColor: Color
    public let totalUnitCount: Int

    public init(
        artworkAsset: String,
        primaryColor: Color,
        secondaryColor: Color,
        totalUnitCount: Int
    ) {
        self.artworkAsset = artworkAsset
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.totalUnitCount = totalUnitCount
    }

    // MARK: - Derived values

    /// 6% at 0 units → 32% at 200+ units. Animated with easeInOut when it changes.
    private var artworkOpacity: Double {
        0.06 + (Double(min(totalUnitCount, 200)) / 200.0) * 0.26
    }

    /// 6 particles at 0 units → 40 at 600+ units.
    private var particleCount: Int {
        min(6 + totalUnitCount / 15, 40)
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1 — era artwork
                Image(artworkAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: 22)
                    .opacity(artworkOpacity)
                    .animation(.easeInOut(duration: 1.8), value: artworkOpacity)

                // Layer 2 — readability gradient
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.72), location: 0),
                        .init(color: .black.opacity(0.42), location: 0.45),
                        .init(color: .black.opacity(0.78), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Layer 3 — ambient particles
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    Canvas { ctx, size in
                        drawParticles(
                            count: particleCount,
                            context: ctx,
                            size: size,
                            time: context.date.timeIntervalSinceReferenceDate
                        )
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: - Particle rendering

    /// Deterministic per-frame particle draw. No heap allocation beyond the GraphicsContext copy.
    private func drawParticles(
        count: Int,
        context: GraphicsContext,
        size: CGSize,
        time: Double
    ) {
        guard count > 0 else { return }
        let cycleSeconds = 14.0

        for i in 0..<count {
            let normalizedSeed = Double(i) / Double(count)

            // Horizontal: fixed column + slow sine wobble
            let x = size.width * normalizedSeed
                  + sin(time * 0.35 + normalizedSeed * .pi * 3.7) * 16.0

            // Vertical: bottom→top, 14s cycle, phase-staggered per seed
            let phased = (time / cycleSeconds + normalizedSeed)
                .truncatingRemainder(dividingBy: 1.0)
            let y = size.height * (1.0 - phased)

            // Fade in at bottom (first 8%), fade out at top (last 15%)
            let fadeBottom = phased < 0.08 ? phased / 0.08 : 1.0
            let fadeTop    = phased > 0.85 ? (1.0 - phased) / 0.15 : 1.0
            let alpha      = fadeBottom * fadeTop * 0.75

            guard alpha > 0.01 else { continue }

            // Particle radius varies per seed (2.5 – 5.5pt)
            let radius = CGFloat(2.5 + Double(i % 6) * 0.5)
            let rect = CGRect(x: x - radius, y: y - radius,
                              width: radius * 2, height: radius * 2)

            // 2:1 ratio primary:secondary
            let color = i % 3 == 2 ? secondaryColor : primaryColor

            var ctx = context
            ctx.opacity = alpha
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}

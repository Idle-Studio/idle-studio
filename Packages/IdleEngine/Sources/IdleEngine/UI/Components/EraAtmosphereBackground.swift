import SwiftUI

// MARK: - EraAtmosphereBackground

/// Full-screen background layer for GameplayScreen.
///
/// Layers (bottom → top):
///   1. Era artwork image — blurred, opacity scales with `totalUnitCount`
///   2. Dark readability gradient — always present
///   3. Ambient particles — Canvas + TimelineView, no SwiftUI view allocation
///
/// All particle animation is driven by deterministic math on `TimelineView` time — the only
/// state is the pause gating, which stops the render loop entirely when the view is off-screen,
/// the scene is inactive, Low Power Mode is on, or Reduce Motion is enabled.
public struct EraAtmosphereBackground: View {

    // MARK: - Inputs

    public let artworkAsset: String
    public let primaryColor: Color
    public let secondaryColor: Color
    public let totalUnitCount: Int

    // MARK: - Pause gating

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

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

    /// The particle loop is the single most expensive thing on the gameplay screen.
    /// Stop it whenever it can't be seen or shouldn't be running.
    private var particlesPaused: Bool {
        reduceMotion || isLowPower || scenePhase != .active || !isVisible
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
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.8), value: artworkOpacity)

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

                // Layer 3 — ambient particles. 20fps is indistinguishable from 30 for a
                // slow ambient drift and cuts the frame budget by a third.
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: particlesPaused)) { context in
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
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onReceive(
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
        ) { _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    // MARK: - Particle rendering

    /// Number of alpha steps particles are quantised into. Alpha has to be folded into the
    /// fill colour rather than set via `ctx.opacity`, because mutating the context forces one
    /// `GraphicsContext` copy and one `fill` per particle. Quantising bounds the fill count at
    /// `2 × alphaSteps` (8) regardless of particle count, instead of one per particle (40).
    private static let alphaSteps = 4

    /// Deterministic per-frame particle draw. Particles are accumulated into at most 8 batched
    /// `Path`s (2 colours × 4 alpha steps) and flushed with one `fill` each.
    private func drawParticles(
        count: Int,
        context: GraphicsContext,
        size: CGSize,
        time: Double
    ) {
        guard count > 0 else { return }
        let cycleSeconds = 14.0
        let steps        = Self.alphaSteps
        let maxAlpha     = 0.75

        // Index = colorIndex * steps + alphaStep. Primary occupies 0..<steps, secondary the rest.
        var batches = [Path](repeating: Path(), count: 2 * steps)

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
            let alpha      = fadeBottom * fadeTop * maxAlpha

            guard alpha > 0.01 else { continue }

            // Particle radius varies per seed (2.5 – 5.5pt)
            let radius = CGFloat(2.5 + Double(i % 6) * 0.5)
            let rect = CGRect(x: x - radius, y: y - radius,
                              width: radius * 2, height: radius * 2)

            // 2:1 ratio primary:secondary
            let colorIndex = i % 3 == 2 ? 1 : 0
            // Quantise into `steps` buckets — bucket k renders at alpha (k + 1) / steps.
            let step = min(steps - 1, max(0, Int(alpha / maxAlpha * Double(steps) - 0.000_001)))

            batches[colorIndex * steps + step].addEllipse(in: rect)
        }

        // Flush — one fill per non-empty batch.
        for (index, path) in batches.enumerated() where !path.isEmpty {
            let color = index < steps ? primaryColor : secondaryColor
            let alpha = maxAlpha * Double(index % steps + 1) / Double(steps)
            context.fill(path, with: .color(color.opacity(alpha)))
        }
    }
}

// MARK: - Equatable

extension EraAtmosphereBackground: Equatable {
    public nonisolated static func == (lhs: EraAtmosphereBackground, rhs: EraAtmosphereBackground) -> Bool {
        lhs.artworkAsset == rhs.artworkAsset &&
        lhs.primaryColor == rhs.primaryColor &&
        lhs.secondaryColor == rhs.secondaryColor &&
        lhs.totalUnitCount == rhs.totalUnitCount
    }
}

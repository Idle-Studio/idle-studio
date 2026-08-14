import SwiftUI

/// A "+N gold" label that floats up and fades out when tapping the main tap zone.
/// Spawned by `GameplayScreen` on each tap — removed after the animation completes.
public struct FloatingParticle: View {
    public let text: String
    public let color: Color
    public let origin: CGPoint

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: String, color: Color, origin: CGPoint) {
        self.text = text
        self.color = color
        self.origin = origin
    }

    public var body: some View {
        Text(text)
            .font(Typography.headline.weight(.bold))
            .foregroundStyle(color)
            .offset(y: offset)
            .opacity(opacity)
            .position(origin)
            .onAppear {
                if reduceMotion {
                    withAnimation(.linear(duration: 0.15)) { opacity = 0 }
                } else {
                    withAnimation(.easeOut(duration: 1.2)) {
                        offset  = -80
                        opacity = 0
                    }
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Particle System

/// Manages a pool of in-flight particles. Add to a `ZStack` overlay.
///
/// The pool is capped and swept from a single timer task. The previous implementation spawned
/// one `Task` per particle with an unbounded pool — an idle player tapping 5–10×/sec kept
/// dozens of sleeping tasks alive, each doing an O(n) `removeAll` on wake.
@Observable
@MainActor
public final class ParticleSystem {
    public struct Particle: Identifiable {
        public let id = UUID()
        public let text: String
        public let color: Color
        public let origin: CGPoint
        /// When this particle should be swept. Matches the 1.2s float animation plus a small margin.
        let expiresAt: Date
    }

    /// Beyond this, particles overlap into an unreadable smear anyway.
    private static let maxParticles = 12
    private static let lifetime: TimeInterval = 1.4

    public private(set) var particles: [Particle] = []

    @ObservationIgnored private var sweepTask: Task<Void, Never>?

    public init() {}

    deinit { sweepTask?.cancel() }

    public func emit(text: String, color: Color, at point: CGPoint) {
        let now = Date()
        // Prune expired entries on the way in — keeps the common case allocation-free.
        particles.removeAll { $0.expiresAt <= now }

        let jitter = CGFloat.random(in: -20...20)
        let p = Particle(
            text: text,
            color: color,
            origin: CGPoint(x: point.x + jitter, y: point.y),
            expiresAt: now + Self.lifetime
        )

        // Drop the oldest when full rather than growing without bound.
        if particles.count >= Self.maxParticles {
            particles.removeFirst(particles.count - Self.maxParticles + 1)
        }
        particles.append(p)

        startSweepIfNeeded()
    }

    /// One repeating sweep for the whole pool, running only while particles are in flight.
    private func startSweepIfNeeded() {
        guard sweepTask == nil else { return }
        sweepTask = Task { [weak self] in
            while let self, !self.particles.isEmpty {
                try? await Task.sleep(for: .seconds(0.25))
                guard !Task.isCancelled else { break }
                let now = Date()
                self.particles.removeAll { $0.expiresAt <= now }
            }
            self?.sweepTask = nil
        }
    }
}

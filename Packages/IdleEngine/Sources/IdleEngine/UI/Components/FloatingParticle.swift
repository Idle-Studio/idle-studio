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
            .shadow(color: .black.opacity(0.5), radius: 1)
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
@Observable
@MainActor
public final class ParticleSystem {
    public struct Particle: Identifiable {
        public let id = UUID()
        public let text: String
        public let color: Color
        public let origin: CGPoint
    }

    public private(set) var particles: [Particle] = []

    public init() {}

    public func emit(text: String, color: Color, at point: CGPoint) {
        let jitter = CGFloat.random(in: -20...20)
        let p = Particle(text: text, color: color, origin: CGPoint(x: point.x + jitter, y: point.y))
        particles.append(p)
        // Remove after animation completes
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            particles.removeAll { $0.id == p.id }
        }
    }
}

import SwiftUI

/// A horizontal progress bar. Used for milestone construction timers,
/// level advance progress, and prestige token fill.
public struct ProgressBar: View {
    /// 0.0 – 1.0
    public let progress: Double
    public let tint: Color

    @ScaledMetric private var height: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progress: Double, tint: Color) {
        self.progress = progress
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * min(1, max(0, progress))))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

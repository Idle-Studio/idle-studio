import SwiftUI

/// Bottom sheet shown on app launch when offline income has accumulated.
/// Copy comes from `theme.copy.offlineSheet`. Can offer a rewarded-ad doubler.
public struct OfflineIncomeSheet: View {
    public let result: OfflineResult
    public let onCollect: () -> Void
    public var onDoubleWithAd: (() -> Void)?

    @Environment(\.theme) private var theme
    @State private var appeared = false

    public init(result: OfflineResult, onCollect: @escaping () -> Void, onDoubleWithAd: (() -> Void)? = nil) {
        self.result = result
        self.onCollect = onCollect
        self.onDoubleWithAd = onDoubleWithAd
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Central content
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 52))
                    .foregroundStyle(theme.goldAccentColor)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: appeared)

                // Headline + body
                VStack(spacing: 6) {
                    Text(theme.copy.offlineSheet.title)
                        .font(Typography.title)
                        .foregroundStyle(theme.textPrimaryColor)
                        .multilineTextAlignment(.center)

                    Text(theme.copy.offlineSheet.body)
                        .font(Typography.body)
                        .foregroundStyle(theme.textSecondaryColor)
                        .multilineTextAlignment(.center)
                }

                // Amount earned
                earnedAmounts

                if result.wasCapped {
                    Text(String(format: theme.copy.offlineSheet.capNote, Int(result.effectiveDuration / 3600)))
                        .font(Typography.caption)
                        .foregroundStyle(theme.textSecondaryColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Buttons pinned to bottom
            VStack(spacing: 12) {
                Button(action: onCollect) {
                    Text(theme.copy.offlineSheet.collectButton)
                        .font(Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.goldAccentColor)
                        .foregroundStyle(.black)
                        .clipShape(.rect(cornerRadius: 14))
                }

                if let doubleAction = onDoubleWithAd {
                    Button(action: doubleAction) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text(theme.copy.offlineSheet.doubleButton)
                        }
                        .font(Typography.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.surfaceElevatedColor)
                        .foregroundStyle(theme.textPrimaryColor)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .onAppear { appeared = true }
    }

    private var earnedAmounts: some View {
        let nonZero = result.earnedResources.amounts
            .filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(nonZero, id: \.key) { key, value in
                VStack(spacing: 4) {
                    Text(value.idleFormatted())
                        .font(nonZero.count <= 2 ? Typography.hero : Typography.display)
                        .foregroundStyle(theme.goldAccentColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(key.capitalized)
                        .font(Typography.caption)
                        .foregroundStyle(theme.textSecondaryColor)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.3).delay(0.15), value: appeared)
    }
}

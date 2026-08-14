import SwiftUI

// MARK: - PrestigeSheet

/// Confirmation sheet shown when the player taps the prestige button.
/// Displays token preview, production multiplier, and what persists/resets.
public struct PrestigeSheet: View {
    public let tokensPreview: Decimal
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    @Environment(\.theme) private var theme

    public init(tokensPreview: Decimal, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.tokensPreview = tokensPreview
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    private var copy: ThemeCopy.PrestigeSheetCopy { theme.copy.prestigeSheet }

    private var newMultiplier: Decimal {
        EconomyCalculator.prestigeMultiplier(tokens: tokensPreview)
    }

    public var body: some View {
        ScrollView {
                VStack(spacing: 28) {
                    // Icon + Title
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#7B2FBE"), Color(hex: "#3A0CA3")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: "#7B2FBE").opacity(0.6), radius: 16, y: 4)

                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }

                        Text(copy.title)
                            .font(Typography.display)
                            .foregroundStyle(theme.textPrimaryColor)

                        Text(copy.subtitle)
                            .font(Typography.body)
                            .foregroundStyle(theme.textSecondaryColor)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Reset warning card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy.description)
                            .font(Typography.body)
                            .foregroundStyle(theme.textSecondaryColor)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            Text(copy.persistsNote)
                                .font(Typography.caption)
                                .foregroundStyle(theme.textSecondaryColor)
                        }
                    }
                    .padding(16)
                    .background(cardBackground(cornerRadius: 14))

                    // Token + Multiplier stats
                    HStack(spacing: 12) {
                        statCard(
                            label: copy.tokensLabel,
                            value: "+\(tokensPreview.idleFormatted())",
                            icon: "hexagon.fill",
                            color: Color(hex: "#7B2FBE")
                        )
                        statCard(
                            label: copy.multiplierLabel,
                            value: "\(newMultiplier.formatted(.number.precision(.fractionLength(2))))×",
                            icon: "bolt.fill",
                            color: theme.goldAccentColor
                        )
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: onConfirm) {
                            Text(copy.confirmButton)
                                .font(Typography.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#7B2FBE"), Color(hex: "#3A0CA3")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(.rect(cornerRadius: 14))
                        }

                        Button(action: onCancel) {
                            Text(copy.cancelButton)
                                .font(Typography.body)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(cardBackground(cornerRadius: 14))
                                .foregroundStyle(theme.textSecondaryColor)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private func statCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(Typography.title)
                .foregroundStyle(color)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBackground(cornerRadius: 14))
    }

    @ViewBuilder
    private func cardBackground(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, macOS 26, *) {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius).fill(theme.surfaceColor)
        }
    }
}

// MARK: - PrestigeSuccessScreen

/// Full-screen celebration shown after the player confirms prestige.
public struct PrestigeSuccessScreen: View {
    public let onDismiss: () -> Void
    @Environment(\.theme) private var theme

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A0533"), Color(hex: "#0D0D1A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Crown icon with glow
                ZStack {
                    Circle()
                        .fill(Color(hex: "#7B2FBE").opacity(0.2))
                        .frame(width: 130, height: 130)
                        .blur(radius: 20)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#7B2FBE"), Color(hex: "#3A0CA3")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Color(hex: "#7B2FBE").opacity(0.8), radius: 20)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 12) {
                    Text("New Empire Founded")
                        .font(Typography.display)
                        .foregroundStyle(.white)

                    Text("A new age of civilization begins.\nYour legacy grows stronger.")
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(action: onDismiss) {
                    Text("Begin Again")
                        .font(Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#7B2FBE"), Color(hex: "#3A0CA3")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}


import SwiftUI
import StoreKit
import UserNotifications

// MARK: - OnboardingFlow

/// Full-screen first-launch onboarding. Shown until the user completes it.
/// Completion is persisted via `UserDefaults["onboarding_completed_<gameID>"]`.
///
/// Three pages:
///   0 — Welcome:       Hero era artwork + app tagline + "Begin" CTA.
///   1 — Notifications: Pre-alert soft ask. "Enable" triggers the iOS system prompt;
///                      "Not Now" advances without showing it.
///   2 — Paywall:       Monthly + annual subscription cards.
///                      Completing or skipping marks onboarding as done.
///
/// Reusable: lives in the engine. Any new game adds `onboardingCopy` to its JSON
/// and a `heroArtworkAsset` image in its bundle — zero Swift changes required.
public struct OnboardingFlow: View {
    let gameID: String
    var onComplete: () -> Void

    @Environment(\.theme) private var theme
    @State private var vm: OnboardingViewModel

    public init(gameID: String, onComplete: @escaping () -> Void) {
        self.gameID = gameID
        self.onComplete = onComplete
        _vm = State(initialValue: OnboardingViewModel(gameID: gameID))
    }

    public var body: some View {
        ZStack {
            // Shared atmospheric background — fixed, never transitions between pages.
            EraAtmosphereBackground(
                artworkAsset: theme.copy.onboardingCopy.heroArtworkAsset,
                primaryColor: theme.goldAccentColor,
                secondaryColor: theme.surfaceElevatedColor,
                totalUnitCount: 120
            )

            // Page content — each page owns its dot indicator + buttons so nothing overlaps.
            ZStack {
                if vm.currentPage == 0 {
                    OnboardingWelcomePage(vm: vm)
                        .transition(pageTransition)
                }
                if vm.currentPage == 1 {
                    OnboardingNotificationsPage(vm: vm)
                        .transition(pageTransition)
                }
                if vm.currentPage == 2 {
                    OnboardingPaywallPage(vm: vm)
                        .transition(pageTransition)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: vm.currentPage)
        }
        // Force dark scheme — background is always dark, text must always be light.
        .preferredColorScheme(.dark)
        .onAppear {
            vm.setup(theme: theme, onComplete: onComplete)
        }
        .interactiveDismissDisabled()
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - OnboardingViewModel

@Observable
@MainActor
final class OnboardingViewModel {
    var currentPage = 0
    var isRequestingNotification = false
    var isPurchasing = false
    var isRestoring = false
    var paywallState: PaywallState = .loading

    private(set) var gameID: String
    private var theme: AppTheme = .placeholder
    private var _onComplete: () -> Void = {}

    enum PaywallState {
        case loading
        case loaded(monthly: Product?, annual: Product?)
        case failed
    }

    init(gameID: String) {
        self.gameID = gameID
    }

    func setup(theme: AppTheme, onComplete: @escaping () -> Void) {
        self.theme = theme
        self._onComplete = onComplete
    }

    // MARK: - Navigation

    func advance() {
        if currentPage < 2 {
            currentPage += 1
        } else {
            markComplete()
        }
    }

    // MARK: - Notifications (Page 1)

    /// Requests system notification authorization and then advances.
    /// Called directly on @MainActor so UNUserNotificationCenter sees the active app context.
    func requestNotifications() async {
        isRequestingNotification = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        isRequestingNotification = false
        advance()
    }

    func skipNotifications() {
        advance()
    }

    // MARK: - Paywall (Page 2)

    func loadPaywallProducts() async {
        paywallState = .loading
        do {
            guard let themePackage = await GameEngine.shared.currentTheme else {
                paywallState = .failed
                return
            }
            let iap = themePackage.iapProducts
            let ids = [iap.premiumPass, iap.premiumPassAnnual].compactMap { $0 }
            guard !ids.isEmpty else {
                paywallState = .failed
                return
            }
            let products = try await Product.products(for: Set(ids))
            let monthly = products.first { $0.id == iap.premiumPass }
            let annual  = products.first { $0.id == iap.premiumPassAnnual }
            paywallState = .loaded(monthly: monthly, annual: annual)
        } catch {
            paywallState = .failed
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        let transaction = try? await LiveStoreKitService().purchase(product)
        isPurchasing = false
        if transaction != nil { markComplete() }
    }

    func restorePurchases() async {
        isRestoring = true
        // Routed through the coordinator so the result reflects every ad-free and premium
        // product. This used to call two single-product lookups — `premiumPass` and
        // `removeAds` only — so a returning annual subscriber or Patron Pack owner restored
        // successfully and was still shown the paywall.
        _ = await PurchaseCoordinator.shared.restorePurchases()
        isRestoring = false
        if EntitlementStore.shared.isAdFree || EntitlementStore.shared.hasPremiumPass {
            markComplete()
        }
    }

    func skipPaywall() {
        markComplete()
    }

    // MARK: - Completion

    private func markComplete() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed_\(gameID)")
        _onComplete()
    }
}

// MARK: - Page 0: Welcome

private struct OnboardingWelcomePage: View {
    let vm: OnboardingViewModel

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var imageScale: CGFloat = 0.88
    @State private var imageOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero era image — full-width with horizontal padding matching buttons
            let asset = theme.copy.onboardingCopy.heroArtworkAsset
            if !asset.isEmpty {
                Image(asset)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(.rect(cornerRadius: 20))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(.rect(cornerRadius: 20))
                    )
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
                    .padding(.horizontal, 24)
                    .scaleEffect(imageScale)
                    .opacity(imageOpacity)
            }

            // Title + tagline — always white text (preferredColorScheme .dark guaranteed)
            VStack(spacing: 10) {
                Text(theme.copy.onboardingCopy.welcomeTitle)
                    .font(Typography.display)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(theme.copy.onboardingCopy.welcomeTagline)
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .opacity(textOpacity)

            Spacer(minLength: 32)

            // Dot indicator above button — never overlaps
            PageDotIndicator(count: 3, current: 0)
                .padding(.bottom, 16)

            OnboardingPrimaryButton(label: theme.copy.onboardingCopy.beginButton) {
                vm.advance()
            }
        }
        .onAppear {
            guard !reduceMotion else {
                imageScale = 1; imageOpacity = 1; textOpacity = 1
                return
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                imageScale = 1
                imageOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                textOpacity = 1
            }
        }
    }
}

// MARK: - Page 1: Notifications Pre-Alert

private struct OnboardingNotificationsPage: View {
    let vm: OnboardingViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Bell icon with gold gradient circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.goldAccentColor, theme.goldAccentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .padding(.bottom, 24)

            VStack(spacing: 8) {
                Text(theme.copy.notificationPermission.title)
                    .font(Typography.display)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(theme.copy.notificationPermission.body)
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            // Bullet points card — same 24pt inset as buttons
            if !theme.copy.notificationPermission.bulletPoints.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(theme.copy.notificationPermission.bulletPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.goldAccentColor)
                                .font(.body)
                            Text(point)
                                .font(Typography.body)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            Spacer(minLength: 32)

            // Dot indicator above buttons — never overlaps secondary button
            PageDotIndicator(count: 3, current: 1)
                .padding(.bottom, 16)

            OnboardingPrimaryButton(
                label: theme.copy.notificationPermission.enableButton,
                isLoading: vm.isRequestingNotification
            ) {
                Task { await vm.requestNotifications() }
            }

            Button {
                vm.skipNotifications()
            } label: {
                Text(theme.copy.notificationPermission.laterButton)
                    .font(Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Page 2: Paywall

private struct OnboardingPaywallPage: View {
    let vm: OnboardingViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Title + subtitle — fixed at top
                VStack(spacing: 8) {
                    Text(theme.copy.onboardingCopy.paywallTitle)
                        .font(Typography.display)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(theme.copy.onboardingCopy.paywallSubtitle)
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)

                // Scrollable centered content below subtitle
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 28)

                        // Bullet points
                        if !theme.copy.onboardingCopy.paywallBulletPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(theme.copy.onboardingCopy.paywallBulletPoints, id: \.self) { point in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(theme.goldAccentColor)
                                            .font(.body)
                                        Text(point)
                                            .font(Typography.body)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 14))
                            .padding(.horizontal, 24)
                        }

                        // Product cards or loading/error states
                        switch vm.paywallState {
                        case .loading:
                            ProgressView()
                                .tint(theme.goldAccentColor)
                                .padding(.vertical, 40)

                        case .loaded(let monthly, let annual):
                            VStack(spacing: 12) {
                                if let annual {
                                    ProductCard(
                                        product: annual,
                                        label: theme.copy.onboardingCopy.paywallAnnualLabel,
                                        badge: theme.copy.onboardingCopy.paywallBestValueBadge,
                                        isHighlighted: true,
                                        isLoading: vm.isPurchasing
                                    ) { Task { await vm.purchase(annual) } }
                                }
                                if let monthly {
                                    ProductCard(
                                        product: monthly,
                                        label: theme.copy.onboardingCopy.paywallMonthlyLabel,
                                        badge: nil,
                                        isHighlighted: false,
                                        isLoading: vm.isPurchasing
                                    ) { Task { await vm.purchase(monthly) } }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)

                            // App Store Guideline 3.1.2 requires an auto-renew disclosure in
                            // the binary, not only in the store listing. Nothing in the app
                            // stated it anywhere.
                            Text(Self.autoRenewDisclosure)
                                .font(Typography.caption)
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.top, 12)

                            // `paywallSkipButton` ("Start for Free") is defined in every
                            // theme JSON, decoded, and was rendered nowhere. The only exit
                            // was a 14pt ✕ at 70% opacity on a modal that also sets
                            // `.interactiveDismissDisabled()` — exactly the hard-paywall
                            // pattern App Review flags.
                            Button {
                                vm.skipPaywall()
                            } label: {
                                Text(theme.copy.onboardingCopy.paywallSkipButton)
                                    .font(Typography.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(.white.opacity(0.14), in: Capsule())
                            }
                            .disabled(vm.isPurchasing || vm.isRestoring)
                            .padding(.horizontal, 24)
                            .padding(.top, 14)

                            Button {
                                Task { await vm.restorePurchases() }
                            } label: {
                                Group {
                                    if vm.isRestoring {
                                        ProgressView()
                                            .tint(.white.opacity(0.6))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text(theme.copy.onboardingCopy.paywallRestoreButton)
                                    }
                                }
                                .font(Typography.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(minHeight: 44)
                            }
                            .disabled(vm.isPurchasing || vm.isRestoring)
                            .padding(.top, 4)

                        case .failed:
                            VStack(spacing: 14) {
                                Text(theme.copy.onboardingCopy.paywallNoProductsMessage)
                                    .font(Typography.body)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .multilineTextAlignment(.center)

                                Button {
                                    Task { await vm.loadPaywallProducts() }
                                } label: {
                                    Text("Retry")
                                        .font(Typography.subheadline)
                                        .foregroundStyle(theme.goldAccentColor)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                        }

                        Spacer(minLength: 28)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                // Dot indicator + policy links pinned at bottom
                PageDotIndicator(count: 3, current: 2)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                PolicyLinks(
                    privacyPolicyURL: theme.copy.privacyPolicyURL,
                    termsOfUseURL: theme.copy.termsOfUseURL
                )
                .padding(.bottom, 20)
            }

            // Dismiss button — top-right corner
            Button {
                vm.skipPaywall()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.18))
                    .clipShape(.circle)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(Text("Close and continue for free"))
            .disabled(vm.isPurchasing || vm.isRestoring)
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .task {
            await vm.loadPaywallProducts()
        }
    }
}

// MARK: - ProductCard

/// Auto-renew terms required in-binary by App Store Guideline 3.1.2.
extension OnboardingPaywallPage {
    static let autoRenewDisclosure = String(localized: """
        Payment is charged to your Apple Account at confirmation of purchase. \
        Subscriptions renew automatically unless cancelled at least 24 hours before the end \
        of the current period. Manage or cancel anytime in your Apple Account settings.
        """)
}

private struct ProductCard: View {
    let product: Product
    let label: String
    let badge: String?
    let isHighlighted: Bool
    let isLoading: Bool
    let onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(Typography.headline)
                            .foregroundStyle(isHighlighted ? Color.black : .white)

                        if let badge {
                            Text(badge)
                                .font(Typography.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isHighlighted ? Color.black.opacity(0.18) : theme.goldAccentColor)
                                .foregroundStyle(Color.black)
                                .clipShape(.capsule)
                        }
                    }

                    let desc = product.description
                    if !desc.isEmpty {
                        Text(desc)
                            .font(Typography.subheadline)
                            .foregroundStyle(isHighlighted ? Color.black.opacity(0.65) : .white.opacity(0.6))
                    }
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(isHighlighted ? .black : theme.goldAccentColor)
                } else {
                    Text(product.displayPrice)
                        .font(Typography.headline)
                        .foregroundStyle(isHighlighted ? Color.black : theme.goldAccentColor)
                }
            }
            .padding(16)
            .background(isHighlighted ? theme.goldAccentColor : .white.opacity(0.1))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHighlighted ? Color.clear : theme.goldAccentColor.opacity(0.4), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

// MARK: - Page Dot Indicator

private struct PageDotIndicator: View {
    let count: Int
    let current: Int

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? theme.goldAccentColor : Color.white.opacity(0.3))
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

// MARK: - Primary Button

private struct OnboardingPrimaryButton: View {
    let label: String
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(label)
                        .font(Typography.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.goldAccentColor)
            .foregroundStyle(.black)
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(isLoading)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

// MARK: - Policy Links

/// "Terms of Use · Privacy Policy" line used on subscription paywalls.
/// Renders nothing if both URLs are empty.
public struct PolicyLinks: View {
    let privacyPolicyURL: String
    let termsOfUseURL: String

    public var body: some View {
        let touURL = URL(string: termsOfUseURL)
        let ppURL  = URL(string: privacyPolicyURL)
        if touURL != nil || ppURL != nil {
            HStack(spacing: 6) {
                if let url = touURL {
                    Link("Terms of Use", destination: url)
                }
                if touURL != nil && ppURL != nil {
                    Text("·").foregroundStyle(.white.opacity(0.35))
                }
                if let url = ppURL {
                    Link("Privacy Policy", destination: url)
                }
            }
            .font(Typography.caption)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.bottom, 4)
        }
    }
}

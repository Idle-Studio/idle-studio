import SwiftUI
import StoreKit
import UserNotifications
import GameKit
#if os(iOS)
import UIKit
#endif

/// Settings screen. All copy from theme; cross-promo card from Remote Config.
public struct SettingsScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.adService) private var adService
    @State private var viewModel = SettingsViewModel()
    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                List {
                    notificationsSection
                    soundSection
                    accountSection
                    aboutSection
                    #if DEBUG
                    devSection
                    #endif
                }
                .scrollContentBackground(.hidden)
                .background(theme.backgroundColor)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .toolbarBackground(theme.surfaceColor, for: .navigationBar)
            #endif
            .task { await viewModel.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await viewModel.load() } }
            }
            #if os(iOS)
            .manageSubscriptionsSheet(isPresented: $viewModel.showManageSubscriptions)
            #endif
            .alert("Delete your saved game?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    Task { await viewModel.deleteAllData() }
                }
            } message: {
                Text("This permanently erases your progress on this device and in iCloud. Purchases are not affected and can be restored. This cannot be undone.")
            }
            .sheet(isPresented: $viewModel.showGameCenterSignIn) {
                if let controller = viewModel.gameCenterViewController {
                    GameCenterAuthView(controller: controller)
                }
            }
        }
    }

    // MARK: - Sections

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $viewModel.notificationsEnabled) {
                Label("Notifications", systemImage: "bell.fill")
                    .foregroundStyle(theme.textPrimaryColor)
            }
            .tint(theme.goldAccentColor)
            .onChange(of: viewModel.notificationsEnabled) { _, enabled in
                viewModel.toggleNotifications(enabled)
            }
        } header: {
            sectionHeader("Notifications & Sound")
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var soundSection: some View {
        Section {
            Toggle(isOn: $viewModel.soundEnabled) {
                Label("Sound", systemImage: "speaker.wave.2.fill")
                    .foregroundStyle(theme.textPrimaryColor)
            }
            .tint(theme.goldAccentColor)
            .onChange(of: viewModel.soundEnabled) { _, on in viewModel.toggleSound(on) }

            Toggle(isOn: $viewModel.hapticsEnabled) {
                Label("Haptics", systemImage: "waveform")
                    .foregroundStyle(theme.textPrimaryColor)
            }
            .tint(theme.goldAccentColor)
            .onChange(of: viewModel.hapticsEnabled) { _, on in viewModel.toggleHaptics(on) }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var accountSection: some View {
        Section {
            Button {
                viewModel.restorePurchases()
            } label: {
                HStack {
                    switch viewModel.restoreStatus {
                    case .idle:
                        Label("Restore Purchases", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(theme.textPrimaryColor)
                    case .restoring:
                        Label("Restoring…", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(theme.textSecondaryColor)
                        Spacer()
                        ProgressView().tint(theme.textSecondaryColor)
                    // The old implementation swallowed the error with `try?` and then
                    // unconditionally showed a green "Purchases Restored" checkmark — so a
                    // failed sync, and having nothing to restore, both reported success.
                    case .restored(let count):
                        Label(
                            count > 0
                                ? "\(count) purchase\(count == 1 ? "" : "s") restored"
                                : "No purchases found",
                            systemImage: count > 0 ? "checkmark.circle.fill" : "info.circle"
                        )
                        .foregroundStyle(count > 0 ? .green : theme.textSecondaryColor)
                    case .failed(let reason):
                        Label(reason, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .frame(minHeight: 44)
            }
            .disabled(viewModel.restoreStatus == .restoring)
            .accessibilityLabel(Text("Restore purchases"))

            if viewModel.showsManageSubscriptions {
                Button {
                    viewModel.showManageSubscriptions = true
                } label: {
                    Label("Manage Subscription", systemImage: "creditcard")
                        .foregroundStyle(theme.textPrimaryColor)
                        .frame(minHeight: 44)
                }
            }

            if !viewModel.isGameCenterAuthenticated {
                Button {
                    viewModel.signInWithGameCenter()
                } label: {
                    Label("Sign in to Game Center", systemImage: "gamecontroller.fill")
                        .foregroundStyle(theme.textPrimaryColor)
                        .frame(minHeight: 44)
                }
            } else {
                HStack {
                    Label("Game Center", systemImage: "gamecontroller.fill")
                        .foregroundStyle(theme.textPrimaryColor)
                    Spacer()
                    Text(viewModel.gameCenterPlayerName)
                        .font(Typography.caption)
                        .foregroundStyle(theme.textSecondaryColor)
                }
                .frame(minHeight: 44)
            }

            // Google requires a re-entry point wherever the consent form was shown.
            if adService.isPrivacyOptionsRequired {
                Button {
                    Task { await adService.presentPrivacyOptions() }
                } label: {
                    Label("Ad Privacy Options", systemImage: "hand.raised.fill")
                        .foregroundStyle(theme.textPrimaryColor)
                        .frame(minHeight: 44)
                }
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    /// Legal links, a support path, and data deletion.
    ///
    /// This section previously contained only a version number. App Store Guidelines 3.1.2
    /// and 5.1.1(i) both require a functional Privacy Policy link reachable *inside* the app
    /// for anything selling subscriptions; the only place these rendered was the one-time
    /// onboarding paywall and a Shop section gated on products loading. There was also no
    /// in-app support path of any kind and no way to delete synced data (GDPR Art. 17).
    private var aboutSection: some View {
        Section {
            if let url = viewModel.privacyPolicyURL {
                Link(destination: url) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                        .foregroundStyle(theme.textPrimaryColor)
                        .frame(minHeight: 44)
                }
            }
            if let url = viewModel.termsOfUseURL {
                Link(destination: url) {
                    Label("Terms of Use", systemImage: "doc.text")
                        .foregroundStyle(theme.textPrimaryColor)
                        .frame(minHeight: 44)
                }
            }
            if let url = viewModel.supportURL {
                Link(destination: url) {
                    Label("Contact Support", systemImage: "envelope")
                        .foregroundStyle(theme.textPrimaryColor)
                        .frame(minHeight: 44)
                }
            }

            Button(role: .destructive) {
                viewModel.showDeleteConfirmation = true
            } label: {
                Label("Delete My Data", systemImage: "trash")
                    .foregroundStyle(.red)
                    .frame(minHeight: 44)
            }

            HStack {
                Label("Version", systemImage: "info.circle")
                    .foregroundStyle(theme.textPrimaryColor)
                Spacer()
                Text(viewModel.versionDisplay)
                    .font(Typography.caption)
                    .foregroundStyle(theme.textSecondaryColor)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("App version \(viewModel.versionDisplay)"))
        } header: {
            sectionHeader("About")
        }
        .listRowBackground(theme.surfaceColor)
    }

    #if DEBUG
    private var devSection: some View {
        Section {
            #if targetEnvironment(simulator)
            Toggle(isOn: $viewModel.devFastForwardEnabled) {
                Label("Fast Forward (×1000)", systemImage: "forward.fill")
                    .foregroundStyle(theme.textPrimaryColor)
            }
            .tint(.orange)
            .onChange(of: viewModel.devFastForwardEnabled) { _, on in
                GameEngine.devFastForwardEnabled = on
            }
            #endif

            Button {
                viewModel.resetOnboarding()
            } label: {
                Label(
                    viewModel.onboardingResetConfirmed ? "Reset — Relaunch to See It" : "Reset Onboarding",
                    systemImage: viewModel.onboardingResetConfirmed ? "checkmark.circle" : "arrow.counterclockwise.circle"
                )
                .foregroundStyle(viewModel.onboardingResetConfirmed ? theme.textSecondaryColor : .orange)
            }
            .disabled(viewModel.onboardingResetConfirmed)
        } header: {
            sectionHeader("Developer")
        } footer: {
            Text("Debug builds only — not included in release builds.")
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor)
        }
        .listRowBackground(theme.surfaceColor)
    }
    #endif

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(theme.textSecondaryColor)
            .textCase(nil)
    }
}

// MARK: - SettingsViewModel

@Observable
@MainActor
final class SettingsViewModel {
    var notificationsEnabled = false
    var soundEnabled = true
    var hapticsEnabled = true
    var appVersion = ""
    var buildNumber = ""
    var restoreStatus: RestoreStatus = .idle
    var showManageSubscriptions = false
    var showDeleteConfirmation = false
    var showGameCenterSignIn = false
    var isGameCenterAuthenticated = false
    var gameCenterPlayerName = ""
    var showsManageSubscriptions = false
    private(set) var privacyPolicyURL: URL?
    private(set) var termsOfUseURL: URL?
    private(set) var supportURL: URL?
    @ObservationIgnored private(set) var gameCenterViewController: UIViewControllerBox?

    /// Shown in About and pre-filled into the support email, so a bug report arrives with
    /// the build already identified.
    var versionDisplay: String { buildNumber.isEmpty ? appVersion : "\(appVersion) (\(buildNumber))" }

    enum RestoreStatus: Equatable {
        case idle
        case restoring
        case restored(count: Int)
        case failed(String)
    }

    #if targetEnvironment(simulator)
    var devFastForwardEnabled = GameEngine.devFastForwardEnabled
    #endif
    #if DEBUG
    var onboardingResetConfirmed = false
    #endif

    func load() async {
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        if let theme = await GameEngine.shared.currentTheme {
            privacyPolicyURL = URL(string: theme.copy.privacyPolicyURL)
            termsOfUseURL = URL(string: theme.copy.termsOfUseURL)
            supportURL = Self.supportLink(theme: theme, version: versionDisplay)
            showsManageSubscriptions =
                theme.iapProducts.premiumPass != nil || theme.iapProducts.premiumPassAnnual != nil
        }

        isGameCenterAuthenticated = GKLocalPlayer.local.isAuthenticated
        gameCenterPlayerName = GKLocalPlayer.local.displayName
        // Only override defaults if the key has been explicitly set before.
        if UserDefaults.standard.object(forKey: "sound_enabled") != nil {
            soundEnabled = UserDefaults.standard.bool(forKey: "sound_enabled")
        }
        if UserDefaults.standard.object(forKey: "haptics_enabled") != nil {
            hapticsEnabled = UserDefaults.standard.bool(forKey: "haptics_enabled")
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    func toggleNotifications(_ on: Bool) {
        if on {
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                if settings.authorizationStatus == .denied {
                    // Permission was previously denied — iOS won't show the prompt again.
                    // Send the user to the app's page in Settings to enable it manually.
                    notificationsEnabled = false
                    #if os(iOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                    #endif
                } else {
                    let granted = (try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                    notificationsEnabled = granted
                }
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    func toggleSound(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "sound_enabled")
        Task {
            if !on {
                AudioService.shared.stopAmbient()
            } else {
                guard let state = await GameEngine.shared.currentState,
                      let theme = await GameEngine.shared.currentTheme,
                      let asset = theme.level(id: state.currentLevelID)?.soundAsset else { return }
                AudioService.shared.playAmbient(asset: asset)
            }
        }
    }

    func toggleHaptics(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "haptics_enabled")
    }

    func restorePurchases() {
        Task {
            restoreStatus = .restoring
            switch await PurchaseCoordinator.shared.restorePurchases() {
            case .success(let count):
                restoreStatus = .restored(count: count)
            case .failure(let error):
                restoreStatus = .failed(error.localizedDescription)
            }
            try? await Task.sleep(for: .seconds(4))
            restoreStatus = .idle
        }
    }

    /// Permanently erases local and iCloud game data. Backs GDPR Art. 17 ("right to erasure")
    /// with something the player can actually do themselves.
    func deleteAllData() async {
        guard let theme = await GameEngine.shared.currentTheme else { return }
        do {
            let service = try SwiftDataPersistenceService()
            try await service.deleteAll(gameID: theme.gameID)
            UserDefaults.standard.removeObject(forKey: "onboarding_completed_\(theme.gameID)")
            UserDefaults.standard.removeObject(forKey: "lastActiveDate")
            UserDefaults.standard.removeObject(forKey: "granted_transaction_ids_\(theme.gameID)")
        } catch {
            Analytics.record(.saveFailed(reason: "delete failed: \(error)"))
        }
    }

    /// A mailto: link pre-populated with the build identifier, so support requests arrive
    /// with the version already attached.
    private static func supportLink(theme: any ThemePackage, version: String) -> URL? {
        guard let raw = theme.copy.supportURL, !raw.isEmpty else { return nil }
        guard raw.hasPrefix("mailto:") else { return URL(string: raw) }
        var components = URLComponents(string: raw)
        let subject = "\(theme.displayName) support (v\(version))"
        var items = components?.queryItems ?? []
        items.append(URLQueryItem(name: "subject", value: subject))
        components?.queryItems = items
        return components?.url
    }

    #if DEBUG
    func resetOnboarding() {
        Task {
            guard let theme = await GameEngine.shared.currentTheme else { return }
            UserDefaults.standard.removeObject(forKey: "onboarding_completed_\(theme.gameID)")
            onboardingResetConfirmed = true
        }
    }
    #endif

    /// Presents Game Center's sign-in flow.
    ///
    /// This used to assign an `authenticateHandler` that posted `.gameCenterAuthRequired`
    /// with the view controller — and nothing anywhere observed that notification. The
    /// controller went into the void, the button did nothing, and there was no path in the
    /// entire app to sign in, so the Leaderboard tab stayed permanently empty.
    func signInWithGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    self.gameCenterViewController = UIViewControllerBox(controller: viewController)
                    self.showGameCenterSignIn = true
                } else {
                    self.showGameCenterSignIn = false
                    self.isGameCenterAuthenticated = GKLocalPlayer.local.isAuthenticated
                    self.gameCenterPlayerName = GKLocalPlayer.local.displayName
                }
            }
        }
    }
}

// MARK: - Game Center Presentation

#if os(iOS)
/// Wrapper so the authentication controller can be carried in `@Observable` state.
@MainActor
final class UIViewControllerBox {
    let controller: UIViewController
    init(controller: UIViewController) { self.controller = controller }
}

/// Presents Game Center's sign-in controller inside a SwiftUI sheet.
struct GameCenterAuthView: UIViewControllerRepresentable {
    let controller: UIViewControllerBox

    func makeUIViewController(context: Context) -> UIViewController { controller.controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#else
@MainActor
final class UIViewControllerBox {
    init(controller: Any) {}
}

struct GameCenterAuthView: View {
    let controller: UIViewControllerBox
    var body: some View { EmptyView() }
}
#endif

// MARK: - Notification Names

public extension Notification.Name {
    static let gameCenterAuthRequired = Notification.Name("IdleEngine.gameCenterAuthRequired")
}

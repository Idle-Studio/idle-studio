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
                    case .done:
                        Label("Purchases Restored", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .disabled(viewModel.restoreStatus == .restoring)

            Button {
                viewModel.signInWithGameCenter()
            } label: {
                Label("Game Center", systemImage: "gamecontroller.fill")
                    .foregroundStyle(theme.textPrimaryColor)
            }
        }
        .listRowBackground(theme.surfaceColor)
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                    .foregroundStyle(theme.textPrimaryColor)
                Spacer()
                Text(viewModel.appVersion)
                    .font(Typography.caption)
                    .foregroundStyle(theme.textSecondaryColor)
            }
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
    var restoreStatus: RestoreStatus = .idle

    enum RestoreStatus: Equatable { case idle, restoring, done }

    #if targetEnvironment(simulator)
    var devFastForwardEnabled = GameEngine.devFastForwardEnabled
    #endif
    #if DEBUG
    var onboardingResetConfirmed = false
    #endif

    func load() async {
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
            try? await AppStore.sync()
            restoreStatus = .done
            try? await Task.sleep(for: .seconds(3))
            restoreStatus = .idle
        }
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

    func signInWithGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            guard error == nil else { return }
            if viewController != nil {
                // A view controller needs to be presented — post a notification
                // so the root view can pick it up and present it.
                NotificationCenter.default.post(
                    name: .gameCenterAuthRequired,
                    object: viewController
                )
            }
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let gameCenterAuthRequired = Notification.Name("IdleEngine.gameCenterAuthRequired")
}

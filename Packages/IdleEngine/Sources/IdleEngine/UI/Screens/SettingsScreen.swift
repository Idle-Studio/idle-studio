import SwiftUI
import StoreKit
import UserNotifications
import GameKit

/// Settings screen. All copy from theme; cross-promo card from Remote Config.
public struct SettingsScreen: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SettingsViewModel()
    @AppStorage("appearanceScheme") private var appearanceScheme = "dark"

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                List {
                    appearanceSection
                    notificationsSection
                    soundSection
                    accountSection
                    aboutSection
                    #if targetEnvironment(simulator)
                    devSection
                    #endif
                }
                .scrollContentBackground(.hidden)
                .background(theme.backgroundColor)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .toolbarBackground(theme.surfaceColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .task { await viewModel.load() }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section {
            Picker(selection: $appearanceScheme) {
                Text("System").tag("system")
                Text("Dark").tag("dark")
                Text("Light").tag("light")
            } label: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
                    .foregroundStyle(theme.textPrimaryColor)
            }
            .tint(theme.goldAccentColor)
        } header: {
            sectionHeader("Display")
        }
        .listRowBackground(theme.surfaceColor)
    }

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
                Label("Restore Purchases", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(theme.textPrimaryColor)
            }

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

    #if targetEnvironment(simulator)
    private var devSection: some View {
        Section {
            Toggle(isOn: $viewModel.devFastForwardEnabled) {
                Label("Fast Forward (×1000)", systemImage: "forward.fill")
                    .foregroundStyle(theme.textPrimaryColor)
            }
            .tint(.orange)
            .onChange(of: viewModel.devFastForwardEnabled) { _, on in
                GameEngine.devFastForwardEnabled = on
            }
        } header: {
            sectionHeader("Developer")
        } footer: {
            Text("Simulator only — not included in release builds.")
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
    #if targetEnvironment(simulator)
    var devFastForwardEnabled = GameEngine.devFastForwardEnabled
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
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
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
        Task { try? await AppStore.sync() }
    }

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

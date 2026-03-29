import SwiftUI

// MARK: - GameplayViewModel

@Observable
@MainActor
public final class GameplayViewModel {
    public private(set) var state: GameState = .initial(firstLevelID: "")
    public private(set) var currentUnits: [ThemeUnit] = []
    // Stored + guarded so views don't re-render when these rarely-changing values are stable.
    public private(set) var currentEraUpgrades: [ThemeEraUpgrade] = []
    public private(set) var productionRate: ResourceBundle = .zero
    public private(set) var eraCostMultiplier: Decimal = 1
    public private(set) var allMilestonesCompleted: Bool = false
    /// Pre-computed canAfford flag per unit ID. Updated once per tick with equality guard.
    public private(set) var unitAffordability: [String: Bool] = [:]
    /// Pre-computed gold cost per unit ID. Updated once per tick with equality guard.
    public private(set) var unitCosts: [String: Decimal] = [:]
    /// Pre-computed unit counts per unit ID. Changes only when units are purchased.
    public private(set) var unitCounts: [String: Int] = [:]
    /// Pre-computed canAfford flag per upgrade ID.
    public private(set) var upgradeAffordability: [String: Bool] = [:]

    @ObservationIgnored nonisolated(unsafe) private var streamTask: Task<Void, Never>?
    private var theme: (any ThemePackage)?

    public init() {}
    deinit { streamTask?.cancel() }

    func start() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            let loadedTheme = await GameEngine.shared.currentTheme
            self?.theme = loadedTheme
            self?.updateCurrentUnits()
            for await newState in GameEngine.shared.stateStream() {
                guard let self else { break }
                if newState != state { state = newState }
                updateCurrentUnits()
                updateCachedValues()
            }
        }
    }

    var currentLevel: ThemeLevel? {
        theme?.level(id: state.currentLevelID)
    }

    func purchase(unitID: String, quantity: Int) {
        Task { try? await GameEngine.shared.purchaseUnit(id: unitID, quantity: quantity) }
    }

    func purchaseEraUpgrade(id: String) {
        Task { try? await GameEngine.shared.purchaseEraUpgrade(id: id) }
    }

    func advanceLevel() {
        Task { try? await GameEngine.shared.advanceLevel() }
    }

    var currentMilestones: [ThemeMilestone] {
        theme?.level(id: state.currentLevelID)?.milestones ?? []
    }

    func milestoneCardState(for milestone: ThemeMilestone) -> MilestoneCard.MilestoneState {
        if state.completedMilestoneIDs.contains(milestone.id) { return .completed }
        if state.inProgressMilestoneID == milestone.id,
           let endDate = state.milestoneConstructionEndDate {
            let remaining = max(0, endDate.timeIntervalSinceNow)
            let progress = milestone.constructionSeconds > 0 ? 1.0 - (remaining / Double(milestone.constructionSeconds)) : 1.0
            return .underConstruction(progress: progress)
        }
        return state.resources.canAfford(milestone.requirements) ? .available(milestone.requirements) : .locked(milestone.requirements)
    }

    func remainingConstructionTime(for milestone: ThemeMilestone) -> String? {
        guard state.inProgressMilestoneID == milestone.id,
              let endDate = state.milestoneConstructionEndDate else { return nil }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        guard remaining > 0 else { return nil }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    func startMilestone(id: String) {
        Task { try? await GameEngine.shared.startMilestone(id: id) }
    }

    func skipMilestoneConstruction(id: String) {
        Task { try? await GameEngine.shared.completeMilestone(id: id) }
    }

    var isLastLevel: Bool {
        guard let theme else { return false }
        return theme.nextLevel(after: state.currentLevelID) == nil
    }

    var nextLevelName: String? {
        guard let theme else { return nil }
        return theme.nextLevel(after: state.currentLevelID)?.displayName
    }

    var eraGoldProgress: Double {
        guard let level = currentLevel else { return 0 }
        let required = level.advanceRequirement["gold"]
        guard required > 0 else { return 1.0 }
        let ratio = state.resources["gold"] / required
        return min(1.0, (ratio as NSDecimalNumber).doubleValue)
    }

    var eraGoldRequirement: Decimal {
        currentLevel?.advanceRequirement["gold"] ?? 0
    }

    var canPrestige: Bool {
        guard let theme else { return false }
        return PrestigeSystem.canPrestige(state: state, theme: theme)
    }

    var prestigeGateMilestoneName: String? {
        guard let theme,
              let gateID = theme.prestigeRequirementMilestoneID,
              !state.completedMilestoneIDs.contains(gateID) else { return nil }
        return theme.allMilestones.first(where: { $0.id == gateID })?.displayName
    }

    var tokensPreview: Decimal {
        PrestigeSystem.tokensEarned(from: state)
    }

    func prestige() {
        Task { try? await GameEngine.shared.prestige() }
    }

    func tap() {
        Task { try? await GameEngine.shared.manualTap() }
    }

    private func updateCurrentUnits() {
        guard let theme else { return }
        let levelUnits = theme.level(id: state.currentLevelID)?.units ?? []
        // Only reassign when the unit set actually changes (era advance), not every tick.
        if levelUnits.map(\.id) != currentUnits.map(\.id) {
            currentUnits = levelUnits
        }
        let levelUpgrades = theme.level(id: state.currentLevelID)?.eraUpgrades ?? []
        if levelUpgrades.map(\.id) != currentEraUpgrades.map(\.id) {
            currentEraUpgrades = levelUpgrades
        }
    }

    /// Moves all expensive per-tick computations out of the view body.
    /// Each assignment is guarded by equality so @Observable only fires when values truly change.
    private func updateCachedValues() {
        // Production rate — only changes when units are purchased or upgrades bought.
        let newRate = EconomyCalculator.productionRate(state: state, units: currentUnits, eraUpgrades: currentEraUpgrades)
        if newRate != productionRate { productionRate = newRate }

        // Cost multiplier — only changes when upgrades are purchased.
        let newMult = EconomyCalculator.eraCostMultiplier(purchasedIDs: state.purchasedUpgradeIDs, upgrades: currentEraUpgrades)
        if newMult != eraCostMultiplier { eraCostMultiplier = newMult }

        // allMilestonesCompleted — changes only when a milestone is built.
        let milestones = currentMilestones
        let newAllDone = milestones.allSatisfy { state.completedMilestoneIDs.contains($0.id) }
        if newAllDone != allMilestonesCompleted { allMilestonesCompleted = newAllDone }

        // Unit counts — changes only when a unit is purchased.
        if state.unitCounts != unitCounts { unitCounts = state.unitCounts }

        // Unit affordability and costs — changes when gold crosses a cost threshold.
        var newAffordability: [String: Bool] = [:]
        var newCosts: [String: Decimal] = [:]
        for unit in currentUnits {
            let count = state.unitCount(id: unit.id)
            let cost = EconomyCalculator.unitCost(unit: unit, currentCount: count, discountMultiplier: newMult)
            newAffordability[unit.id] = state.resources.canAfford(cost)
            newCosts[unit.id] = cost["gold"]
        }
        if newAffordability != unitAffordability { unitAffordability = newAffordability }
        if newCosts != unitCosts { unitCosts = newCosts }

        // Upgrade affordability — changes when gold crosses an upgrade cost threshold.
        var newUpgradeAffordability: [String: Bool] = [:]
        for upgrade in currentEraUpgrades {
            newUpgradeAffordability[upgrade.id] = state.resources.canAfford(upgrade.cost)
        }
        if newUpgradeAffordability != upgradeAffordability { upgradeAffordability = newUpgradeAffordability }
    }
}

// MARK: - GameplayScreen

public struct GameplayScreen: View {
    @Bindable var viewModel: GameplayViewModel

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.adService) private var adService
    @State private var particles = ParticleSystem()
    @State private var tapScale: CGFloat = 1.0
    @State private var tapGlow: Double = 0
    @State private var tapBounceTask: Task<Void, Never>?
    @State private var showPrestigeSheet = false

    public init(viewModel: GameplayViewModel) {
        self.viewModel = viewModel
    }

    private var totalUnitCount: Int {
        viewModel.state.unitCounts.values.reduce(0, +)
    }

    public var body: some View {
        ZStack {
            if let level = currentLevel {
                EraAtmosphereBackground(
                    artworkAsset: level.artworkAsset,
                    primaryColor: theme.levelPrimaryColor(for: viewModel.state.currentLevelID),
                    secondaryColor: theme.levelSecondaryColor(for: viewModel.state.currentLevelID),
                    totalUnitCount: totalUnitCount
                )
                .id(level.id)
                .transition(.opacity.animation(reduceMotion ? nil : .easeInOut(duration: 1.2)))
            } else {
                theme.backgroundColor.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ResourceBar(
                    resources: viewModel.state.resources,
                    productionRate: viewModel.productionRate,
                    currentLevelID: viewModel.state.currentLevelID
                )
                .equatable()
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        // Era progress card — shown until both conditions are met
                        if !viewModel.isLastLevel,
                           let nextName = viewModel.nextLevelName,
                           !(viewModel.allMilestonesCompleted && viewModel.eraGoldProgress >= 1.0) {
                            eraProgressCard(nextName: nextName)
                        }

                        // Inline wonder card (one per era)
                        if let wonder = viewModel.currentMilestones.first {
                            inlineWonderCard(wonder)
                        }

                        // Prestige button (last level) OR level advance button
                        if viewModel.isLastLevel {
                            prestigeButton
                        } else if let current = currentLevel,
                                  viewModel.state.resources.canAfford(current.advanceRequirement),
                                  viewModel.allMilestonesCompleted {
                            levelAdvanceButton(level: current)
                        }

                        // Era Upgrades section (when current era has upgrades)
                        if !viewModel.currentEraUpgrades.isEmpty {
                            eraUpgradesSection
                        }

                        // Units — use pre-computed ViewModel dicts so EconomyCalculator is
                        // never called inside the view body. .equatable() short-circuits
                        // UnitCard.body when inputs haven't changed (most ticks).
                        ForEach(viewModel.currentUnits) { unit in
                            UnitCard(
                                unit: unit,
                                ownedCount: viewModel.unitCounts[unit.id] ?? 0,
                                canAfford: viewModel.unitAffordability[unit.id] ?? false,
                                discountMultiplier: viewModel.eraCostMultiplier,
                                onPurchase: { qty in viewModel.purchase(unitID: unit.id, quantity: qty) }
                            )
                            .equatable()
                        }
                    }
                    .padding()
                }

                // Tap zone fixed above tab bar
                tapZone
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            // Floating particles overlay
            ForEach(particles.particles) { p in
                FloatingParticle(text: p.text, color: p.color, origin: p.origin)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iapRewardReceived)) { note in
            let coins = note.userInfo?["gold"] as? Decimal ?? 0
            if !reduceMotion { triggerCoinRain(amount: coins) }
        }
        .sheet(isPresented: $showPrestigeSheet) {
            PrestigeSheet(tokensPreview: viewModel.tokensPreview) {
                showPrestigeSheet = false
                viewModel.prestige()
            } onCancel: {
                showPrestigeSheet = false
            }
            .environment(\.theme, theme)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func eraProgressCard(nextName: String) -> some View {
        let goldProgress = viewModel.eraGoldProgress
        let milestoneDone = viewModel.allMilestonesCompleted
        let overallProgress = milestoneDone ? goldProgress : goldProgress * 0.5
        let accent = eraAccentColor

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress to \(nextName)")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondaryColor)
                Spacer()
                Text("\(Int(overallProgress * 100))%")
                    .font(Typography.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(accent)
            }

            ProgressBar(progress: overallProgress, tint: accent)

            HStack(spacing: 16) {
                // Gold requirement
                Label {
                    Text("\(viewModel.state.resources["gold"].idleFormatted()) / \(viewModel.eraGoldRequirement.idleFormatted())")
                        .font(Typography.caption.monospacedDigit())
                        .foregroundStyle(goldProgress >= 1.0 ? accent : theme.textSecondaryColor)
                } icon: {
                    Image(systemName: goldProgress >= 1.0 ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(goldProgress >= 1.0 ? accent : theme.textSecondaryColor)
                }

                Spacer()

                // Milestone requirement
                Label {
                    Text(milestoneDone ? "\(theme.copy.milestoneNoun) done" : "Build \(theme.copy.milestoneNoun)")
                        .font(Typography.caption)
                        .foregroundStyle(milestoneDone ? accent : theme.textSecondaryColor)
                } icon: {
                    Image(systemName: milestoneDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(milestoneDone ? accent : theme.textSecondaryColor)
                }
            }
        }
        .padding(12)
        .background(theme.surfaceColor)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func inlineWonderCard(_ wonder: ThemeMilestone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(theme.copy.milestoneNoun)
                .font(Typography.caption)
                .foregroundStyle(theme.textSecondaryColor)
                .padding(.horizontal, 4)

            MilestoneCard(
                milestone: wonder,
                state: viewModel.milestoneCardState(for: wonder),
                onStart: { viewModel.startMilestone(id: wonder.id) }
            )

            if let timeLeft = viewModel.remainingConstructionTime(for: wonder) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.caption)
                        Text(timeLeft)
                            .font(Typography.caption.monospacedDigit())
                    }
                    .foregroundStyle(theme.goldAccentColor)

                    if !adService.adsRemoved {
                        Spacer()
                        Button {
                            Task {
                                let reward = try? await adService.showRewardedAd(placement: .skipMilestone)
                                if reward != nil {
                                    viewModel.skipMilestoneConstruction(id: wonder.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                Text("Skip")
                            }
                            .font(Typography.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.surfaceElevatedColor)
                            .foregroundStyle(theme.textPrimaryColor)
                            .clipShape(.capsule)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var eraAccentColor: Color {
        theme.levelPrimaryColor(for: viewModel.state.currentLevelID)
    }

    private var tapZone: some View {
        GeometryReader { geo in
            ZStack {
                // Era artwork as tap zone background
                if let asset = currentLevel?.artworkAsset {
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .clipShape(.rect(cornerRadius: 20))
                }

                // Era gradient tint at 65% opacity — preserves readability + era color identity
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [
                            theme.levelPrimaryColor(for: viewModel.state.currentLevelID).opacity(0.65),
                            theme.levelSecondaryColor(for: viewModel.state.currentLevelID).opacity(0.65),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 180)

                // Glow overlay that flashes on tap
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(tapGlow))
                    .frame(height: 180)
                    .allowsHitTesting(false)

                VStack(spacing: 8) {
                    Text(theme.copy.levelNoun)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(currentLevel?.displayName ?? "")
                        .font(Typography.display)
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 180)
            .scaleEffect(tapScale)
            .contentShape(.rect)
            .onTapGesture { location in
                let earned = max(1, viewModel.productionRate["gold"])
                if !reduceMotion {
                    let tapPoint = CGPoint(
                        x: location.x,
                        y: location.y + geo.frame(in: .global).minY
                    )
                    particles.emit(
                        text: "+\(earned.idleFormatted())",
                        color: theme.goldAccentColor,
                        at: tapPoint
                    )
                }
                viewModel.tap()
                HapticsService.impact(.light)
                if !reduceMotion { animateTap() }
            }
        }
        .frame(height: 180)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Tap to earn \(theme.primaryCurrency)")
    }

    private func animateTap() {
        tapBounceTask?.cancel()
        withAnimation(.spring(response: 0.1, dampingFraction: 0.7)) {
            tapScale = 0.94
            tapGlow = 0.15
        }
        tapBounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.38)) {
                tapScale = 1.0
                tapGlow = 0
            }
        }
    }

    @ViewBuilder
    private var eraUpgradesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Era Upgrades")
                .font(Typography.headline)
                .foregroundStyle(theme.textPrimaryColor)
                .padding(.horizontal, 4)

            ForEach(viewModel.currentEraUpgrades) { upgrade in
                EraUpgradeCard(
                    upgrade: upgrade,
                    isPurchased: viewModel.state.purchasedUpgradeIDs.contains(upgrade.id),
                    canAfford: viewModel.upgradeAffordability[upgrade.id] ?? false,
                    onPurchase: { viewModel.purchaseEraUpgrade(id: upgrade.id) }
                )
                .equatable()
            }
        }
    }

    @ViewBuilder
    private var prestigeButton: some View {
        let active = viewModel.canPrestige
        Button {
            if active {
                showPrestigeSheet = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: active ? "crown.fill" : "lock.fill")
                    .font(.body.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.copy.prestigeTitle)
                        .font(Typography.headline)
                    if let hint = viewModel.prestigeGateMilestoneName {
                        Text(String(format: theme.copy.prestigeSheet.lockedHint, hint))
                            .font(Typography.caption)
                            .opacity(0.75)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                active
                ? LinearGradient(colors: [Color(hex: "#7B2FBE"), Color(hex: "#3A0CA3")], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [theme.surfaceColor, theme.surfaceColor], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(active ? .white : theme.textSecondaryColor)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(active ? Color.clear : theme.textSecondaryColor.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel(active ? theme.copy.prestigeTitle : "Prestige locked")
    }

    private func levelAdvanceButton(level: ThemeLevel) -> some View {
        Button(action: viewModel.advanceLevel) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text(theme.copy.advanceVerb)
                    .font(Typography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.goldAccentColor)
            .foregroundStyle(.black)
            .clipShape(.rect(cornerRadius: 14))
        }
        .accessibilityLabel("\(theme.copy.advanceVerb) to the next \(theme.copy.levelNoun)")
    }

    private var currentLevel: ThemeLevel? {
        viewModel.currentLevel
    }

    private func triggerCoinRain(amount: Decimal) {
        let label = "+\(amount.idleFormatted())"
        let screenWidth = UIScreen.main.bounds.width
        for i in 0..<8 {
            let x = screenWidth * CGFloat(i + 1) / 9.0
            let y = CGFloat.random(in: 140...360)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) {
                particles.emit(text: label, color: theme.goldAccentColor, at: CGPoint(x: x, y: y))
            }
        }
    }
}

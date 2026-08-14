import Foundation
import Testing
@testable import IdleEngine

/// Validates the JSON that actually ships, not a mock.
///
/// Nothing in CI previously decoded a real theme through `JSONThemePackage`; the only check
/// was a Python snippet asserting seven top-level keys existed. A theme that parses as JSON
/// but fails Swift `Decodable`, or that violates an engine invariant, shipped green — and the
/// only gate left was `GameEngine.loadTheme` running on the player's device after review.
@Suite("Shipped themes")
struct ShippedThemeTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // IdleEngineTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // IdleEngine
        .deletingLastPathComponent()  // Packages
        .deletingLastPathComponent()  // repo root

    static func themeURL(_ game: String, _ file: String) -> URL {
        repoRoot.appending(path: "games/\(game)/\(file)")
    }

    @Test("idle-civilizations decodes and passes validation")
    func civilizationsIsValid() throws {
        let url = Self.themeURL("idle-civilizations", "idle-civilizations.json")
        let data = try Data(contentsOf: url)
        let theme = try JSONDecoder().decode(JSONThemePackage.self, from: data)

        #expect(theme.gameID == "idle-civilizations")
        #expect(theme.levels.count == 8)
        #expect(theme.allUnits.count == 40)
        #expect(theme.allMilestones.count == 8)
        #expect(theme.achievements.count == 30)

        try ThemeValidator.validate(theme)
    }

    /// Wonders promise ×1.75 through ×3.0 across the eight eras. `ThemeMilestone.bonuses`
    /// was declared, authored, and read by nothing, so building one granted no production
    /// at all — roughly ×787.5 of advertised output that never existed.
    @Test("Completing every wonder actually multiplies production")
    func milestoneBonusesApply() throws {
        let url = Self.themeURL("idle-civilizations", "idle-civilizations.json")
        let theme = try JSONDecoder().decode(JSONThemePackage.self, from: try Data(contentsOf: url))
        let milestones = theme.allMilestones

        #expect(milestones.contains { !$0.bonuses.isEmpty }, "No milestone declares a bonus")

        let none = EconomyCalculator.milestoneBonuses(completedIDs: [], milestones: milestones)
        #expect(none.globalMultipliers.isEmpty)

        let all = EconomyCalculator.milestoneBonuses(
            completedIDs: Set(milestones.map(\.id)), milestones: milestones
        )
        let goldMultiplier = all.globalMultipliers[theme.primaryCurrency] ?? 1
        #expect(goldMultiplier > 1, "Completed wonders grant no production multiplier")

        // Same state, with and without the wonders completed.
        let unit = theme.allUnits[0]
        let state = GameState.initial(firstLevelID: theme.levels[0].id)
            .purchasing(unitID: unit.id, quantity: 10, cost: .zero)
        let base = EconomyCalculator.productionRate(state: state, units: theme.allUnits)
        let boosted = EconomyCalculator.productionRate(
            state: state, units: theme.allUnits, milestoneBonuses: all
        )
        #expect(boosted[theme.primaryCurrency] > base[theme.primaryCurrency])
    }
}

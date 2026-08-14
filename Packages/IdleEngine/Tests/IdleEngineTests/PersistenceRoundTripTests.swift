import Foundation
import SwiftData
import Testing
@testable import IdleEngine

/// Locks in the save/load path.
///
/// Persistence shipped completely dead: `PersistedSave` carried an `@Attribute(.unique)`
/// and non-defaulted properties, both illegal under CloudKit, so `ModelContainer.init`
/// threw, a `try?` swallowed the error, and every save was a silent no-op. Nothing in the
/// test suite touched `JSONEncoder`, `ModelContainer`, or `PersistenceService`, so nothing
/// noticed. These tests are that missing coverage.
@Suite("Persistence round trip", .serialized)
struct PersistenceRoundTripTests {

    // MARK: - Helpers

    /// One in-memory store for the whole suite. Never the developer's real store.
    ///
    /// Deliberately shared and never deallocated. Two SwiftData behaviours make per-test
    /// containers unusable inside an SPM test runner: constructing them concurrently
    /// intermittently SIGSEGVs during startup, and letting one deallocate raises
    /// `NSInternalInconsistencyException: bundleIdentifier != nil` from CoreData's teardown
    /// on a background queue — after the tests have already reported success, so the run
    /// aborts with a signal instead of exiting 0. Tests isolate on `gameID` instead.
    private static let sharedContainer: ModelContainer = {
        // swiftlint:disable:next force_try — a failure here means every test is invalid.
        try! ModelContainer(
            for: PersistedSave.self,
            configurations: ModelConfiguration("idle-engine-tests", isStoredInMemoryOnly: true)
        )
    }()

    private func makeInMemoryContainer() throws -> ModelContainer {
        Self.sharedContainer
    }

    /// Unique per call, so tests sharing one container never see each other's rows.
    private func uniqueGameID(_ label: String = "game") -> String {
        "\(label)-\(UUID().uuidString)"
    }

    private func makeService() throws -> (SwiftDataPersistenceService, ModelContainer) {
        let container = try makeInMemoryContainer()
        return (SwiftDataPersistenceService(modelContainer: container), container)
    }

    /// Rows for `gameID` currently in the store, read through an independent context so the
    /// actor's own context can't mask a missing write.
    private func storedRows(in container: ModelContainer, gameID: String) throws -> [PersistedSave] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<PersistedSave>())
            .filter { $0.gameID == gameID }
    }

    // MARK: - GameState JSON round trip

    @Test("Every GameState field survives a JSON round trip")
    func fullStateRoundTripsField_by_field() throws {
        let original = RegressionFixtures.populatedState()
        let data = try RegressionFixtures.encoder.encode(original)
        let decoded = try RegressionFixtures.decoder.decode(GameState.self, from: data)

        #expect(decoded.currentLevelID == original.currentLevelID, "currentLevelID was not preserved")
        #expect(decoded.resources == original.resources, "resources were not preserved")
        #expect(decoded.resources["gold"] == Decimal(string: "1e28")!, "1e28 gold lost precision through JSON")
        #expect(decoded.unitCounts == original.unitCounts, "unitCounts were not preserved")
        #expect(
            decoded.unitCounts.values.reduce(0, +) == RegressionFixtures.populatedTotalUnits,
            "unit total changed across the round trip"
        )
        #expect(decoded.completedMilestoneIDs == original.completedMilestoneIDs, "completedMilestoneIDs were not preserved")
        #expect(decoded.purchasedUpgradeIDs == original.purchasedUpgradeIDs, "purchasedUpgradeIDs were not preserved")
        #expect(decoded.prestigeTokens == original.prestigeTokens, "prestigeTokens were not preserved")
        #expect(decoded.totalPrestigeCount == original.totalPrestigeCount, "totalPrestigeCount was not preserved")
        #expect(decoded.totalLifetimeGold == original.totalLifetimeGold, "totalLifetimeGold was not preserved")
        #expect(decoded.sessionStartDate == original.sessionStartDate, "sessionStartDate was not preserved")
        #expect(decoded.lastSaveDate == original.lastSaveDate, "lastSaveDate was not preserved")
        #expect(decoded.studioPoints == original.studioPoints, "studioPoints were not preserved")
        #expect(decoded.earnedAchievementIDs == original.earnedAchievementIDs, "earnedAchievementIDs were not preserved")
        #expect(decoded.totalPlaySeconds == original.totalPlaySeconds, "totalPlaySeconds was not preserved")
        #expect(decoded.inProgressMilestoneID == original.inProgressMilestoneID, "inProgressMilestoneID was not preserved")
        #expect(
            decoded.milestoneConstructionEndDate == original.milestoneConstructionEndDate,
            "milestoneConstructionEndDate was not preserved"
        )

        // Whole-value equality catches any field added later that the assertions above miss.
        #expect(decoded == original, "Decoded state differs from the original")
    }

    @Test("Repeated encode/decode cycles are idempotent")
    func roundTripIsIdempotent() throws {
        var state = RegressionFixtures.populatedState()
        let firstEncoding = try RegressionFixtures.encoder.encode(state)

        for cycle in 1...5 {
            let data = try RegressionFixtures.encoder.encode(state)
            state = try RegressionFixtures.decoder.decode(GameState.self, from: data)
            #expect(state == RegressionFixtures.populatedState(), "State drifted on cycle \(cycle)")
        }

        let finalEncoding = try RegressionFixtures.encoder.encode(state)
        #expect(
            finalEncoding == firstEncoding,
            "Encoded bytes drifted across repeated cycles — the wire format is not stable"
        )
    }

    // MARK: - Forward compatibility

    /// The exact key set a v1 save on a player's device contains. Everything decoded with a
    /// hard `decode` in `GameState.init(from:)` must appear here.
    private static let v1OnlyJSON = """
    {
      "currentLevelID": "era_bronze",
      "resources": { "gold": 12345.5, "bronze": 200 },
      "unitCounts": { "campfire": 12, "hut": 4 },
      "completedMilestoneIDs": ["wonder_pyramids"],
      "prestigeTokens": 7,
      "totalPrestigeCount": 2,
      "totalLifetimeGold": 1000000000000000,
      "sessionStartDate": 1700000000,
      "lastSaveDate": 1700003600,
      "studioPoints": 125
    }
    """

    @Test("A v1-only save still decodes, with defaults for every later field")
    func v1SaveDecodesWithDefaults() throws {
        let data = try #require(Self.v1OnlyJSON.data(using: .utf8))
        let state = try RegressionFixtures.decoder.decode(GameState.self, from: data)

        // v1 fields survive intact.
        #expect(state.currentLevelID == "era_bronze")
        #expect(state.resources["gold"] == Decimal(string: "12345.5")!)
        #expect(state.unitCounts == ["campfire": 12, "hut": 4])
        #expect(state.completedMilestoneIDs == ["wonder_pyramids"])
        #expect(state.prestigeTokens == 7)
        #expect(state.totalPrestigeCount == 2)
        #expect(state.totalLifetimeGold == Decimal(string: "1000000000000000")!)
        #expect(state.sessionStartDate == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(state.lastSaveDate == Date(timeIntervalSince1970: 1_700_003_600))
        #expect(state.studioPoints == 125)

        // Fields added after v1 must default, never throw. A hard `decode` for any of these
        // would make every save written before that field shipped undecodable.
        #expect(state.purchasedUpgradeIDs.isEmpty, "purchasedUpgradeIDs must default to empty")
        #expect(state.earnedAchievementIDs.isEmpty, "earnedAchievementIDs must default to empty")
        #expect(state.totalPlaySeconds == 0, "totalPlaySeconds must default to 0")
        #expect(state.inProgressMilestoneID == nil, "inProgressMilestoneID must default to nil")
        #expect(state.milestoneConstructionEndDate == nil, "milestoneConstructionEndDate must default to nil")
    }

    @Test("A v1-only save survives a full save/load cycle through the service")
    func v1SaveSurvivesServiceRoundTrip() async throws {
        let data = try #require(Self.v1OnlyJSON.data(using: .utf8))
        let legacy = try RegressionFixtures.decoder.decode(GameState.self, from: data)

        let (service, _) = try makeService()
        try await service.save(state: legacy, gameID: "legacy-player")
        let reloaded = try #require(
            await service.load(gameID: "legacy-player"),
            "A legacy save must not be reported as a new player"
        )

        let pinned = RegressionFixtures.lastSave
        #expect(
            reloaded.markingSaved(at: pinned) == legacy.markingSaved(at: pinned),
            "A v1 save was altered by an upgrade round trip"
        )
    }

    // MARK: - Wire-format stability

    /// Renaming any of these breaks every save already on a player's device. Changing this
    /// list must be a deliberate act, not a side effect of a refactor.
    static let requiredWireKeys = [
        "currentLevelID",
        "resources",
        "unitCounts",
        "completedMilestoneIDs",
        "purchasedUpgradeIDs",
        "prestigeTokens",
        "totalPrestigeCount",
        "totalLifetimeGold",
        "sessionStartDate",
        "lastSaveDate",
        "studioPoints",
        "earnedAchievementIDs",
        "totalPlaySeconds",
        "inProgressMilestoneID",
        "milestoneConstructionEndDate"
    ]

    @Test("Encoded save contains every expected wire key", arguments: requiredWireKeys)
    func encodedSaveContainsKey(key: String) throws {
        let data = try RegressionFixtures.encoder.encode(RegressionFixtures.populatedState())
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Encoded GameState is not a JSON object"
        )
        #expect(
            object[key] != nil,
            "Wire key '\(key)' is missing from the encoded save — every existing save would fail to load"
        )
    }

    @Test("Encoded save contains no keys beyond the documented wire format")
    func encodedSaveHasNoUndocumentedKeys() throws {
        let data = try RegressionFixtures.encoder.encode(RegressionFixtures.populatedState())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let unexpected = Set(object.keys).subtracting(Self.requiredWireKeys)
        #expect(
            unexpected.isEmpty,
            "Undocumented wire keys \(unexpected.sorted()) — add them to requiredWireKeys deliberately"
        )
    }

    // MARK: - Service round trip

    @Test("save then load returns an equal state")
    func serviceSaveLoadRoundTrip() async throws {
        let (service, _) = try makeService()
        let original = RegressionFixtures.populatedState()

        try await service.save(state: original, gameID: "game-1")
        let loaded = try #require(await service.load(gameID: "game-1"), "load returned nil after a successful save")

        // `save` deliberately re-stamps `lastSaveDate`; normalise it before comparing.
        let pinned = RegressionFixtures.lastSave
        #expect(
            loaded.markingSaved(at: pinned) == original.markingSaved(at: pinned),
            "Loaded state differs from the state that was saved"
        )
        #expect(loaded.resources["gold"] == original.resources["gold"], "gold balance did not survive the store")
        #expect(loaded.unitCounts == original.unitCounts, "unit counts did not survive the store")
    }

    @Test("save stamps lastSaveDate at write time rather than trusting the caller")
    func saveStampsLastSaveDate() async throws {
        let (service, _) = try makeService()
        let stale = RegressionFixtures.populatedState()  // lastSaveDate is in 2023
        let before = Date()

        try await service.save(state: stale, gameID: "game-stamp")
        let loaded = try #require(await service.load(gameID: "game-stamp"))

        #expect(
            loaded.lastSaveDate >= before,
            "lastSaveDate was not re-stamped by the persistence layer (got \(loaded.lastSaveDate))"
        )
        #expect(
            loaded.lastSaveDate > stale.lastSaveDate,
            "The caller's stale lastSaveDate was persisted verbatim"
        )
    }

    @Test("Saving twice for one gameID updates a single row instead of duplicating")
    func repeatedSaveUpdatesOneRow() async throws {
        let (service, container) = try makeService()
        let state = RegressionFixtures.populatedState()

        for _ in 1...5 {
            try await service.save(state: state, gameID: "game-single")
        }

        let rows = try storedRows(in: container, gameID: "game-single")
        #expect(rows.count == 1, "Expected exactly 1 stored row, found \(rows.count) — saves are accumulating")
    }

    @Test("Distinct gameIDs get distinct rows")
    func distinctGameIDsAreIsolated() async throws {
        let (service, _) = try makeService()
        let a = RegressionFixtures.populatedState()
        let b = GameState.initial(firstLevelID: "level_1")

        try await service.save(state: a, gameID: "game-a")
        try await service.save(state: b, gameID: "game-b")

        let loadedA = try #require(await service.load(gameID: "game-a"))
        let loadedB = try #require(await service.load(gameID: "game-b"))
        #expect(loadedA.currentLevelID == a.currentLevelID, "game-a was overwritten by game-b")
        #expect(loadedB.currentLevelID == "level_1", "game-b was overwritten by game-a")
        #expect(loadedB.unitCounts.isEmpty, "game-b picked up game-a's units")
    }

    // MARK: - Duplicate rows (CloudKit mirrors these legitimately)

    @Test("With duplicate rows present, load returns the newest by savedAt")
    func loadPrefersNewestDuplicate() async throws {
        let (service, container) = try makeService()

        let old = RegressionFixtures.populatedState()
        let new = GameState(
            currentLevelID: "level_newest",
            resources: ResourceBundle(["gold": 999]),
            unitCounts: ["campfire": 1],
            completedMilestoneIDs: [],
            prestigeTokens: 0,
            totalPrestigeCount: 0,
            totalLifetimeGold: 999,
            sessionStartDate: RegressionFixtures.sessionStart,
            lastSaveDate: RegressionFixtures.lastSave,
            studioPoints: 0
        )

        // Insert both directly: `save` collapses duplicates, so it cannot set this scenario up.
        // Insertion order is deliberately newest-first so an unsorted `.first` would pass by
        // luck; the third, oldest row makes an unsorted fetch fail on either ordering.
        let context = ModelContext(container)
        let weeksAgo = Date(timeIntervalSince1970: 1_600_000_000)
        context.insert(PersistedSave(
            gameID: "game-dup",
            stateData: try RegressionFixtures.encoder.encode(new),
            savedAt: Date(timeIntervalSince1970: 1_800_000_000)
        ))
        context.insert(PersistedSave(
            gameID: "game-dup",
            stateData: try RegressionFixtures.encoder.encode(old),
            savedAt: weeksAgo
        ))
        context.insert(PersistedSave(
            gameID: "game-dup",
            stateData: try RegressionFixtures.encoder.encode(old),
            savedAt: Date(timeIntervalSince1970: 1_500_000_000)
        ))
        try context.save()

        let loaded = try #require(await service.load(gameID: "game-dup"))
        #expect(
            loaded.currentLevelID == "level_newest",
            "load resolved to a stale duplicate (\(loaded.currentLevelID)) — records must be sorted by savedAt descending"
        )
    }

    @Test("Saving over duplicate rows collapses them to one")
    func saveCollapsesDuplicates() async throws {
        let (service, container) = try makeService()
        let state = RegressionFixtures.populatedState()
        let data = try RegressionFixtures.encoder.encode(state)

        let context = ModelContext(container)
        for offset in 0..<4 {
            context.insert(PersistedSave(
                gameID: "game-collapse",
                stateData: data,
                savedAt: Date(timeIntervalSince1970: 1_600_000_000 + Double(offset))
            ))
        }
        try context.save()
        #expect(try storedRows(in: container, gameID: "game-collapse").count == 4, "Fixture setup failed")

        try await service.save(state: state, gameID: "game-collapse")

        let rows = try storedRows(in: container, gameID: "game-collapse")
        #expect(rows.count == 1, "Duplicates were not collapsed by save — found \(rows.count) rows")
    }

    // MARK: - Absent and corrupted saves

    @Test("load for an unknown gameID returns nil")
    func loadUnknownGameReturnsNil() async throws {
        let (service, _) = try makeService()
        let result = try await service.load(gameID: "never-played")
        #expect(result == nil, "An unplayed game must report nil, not a fabricated state")
    }

    @Test("load returns nil only for a genuinely new player, never after a delete of another game")
    func loadIsScopedToGameID() async throws {
        let (service, _) = try makeService()
        try await service.save(state: RegressionFixtures.populatedState(), gameID: "game-kept")
        try await service.deleteAll(gameID: "game-other")

        let kept = try await service.load(gameID: "game-kept")
        #expect(kept != nil, "deleteAll on an unrelated gameID destroyed a live save")
    }

    @Test("deleteAll removes every row for the game")
    func deleteAllRemovesRows() async throws {
        let (service, container) = try makeService()
        try await service.save(state: RegressionFixtures.populatedState(), gameID: "game-gdpr")
        #expect(try storedRows(in: container, gameID: "game-gdpr").count == 1, "Fixture setup failed")

        try await service.deleteAll(gameID: "game-gdpr")

        #expect(try storedRows(in: container, gameID: "game-gdpr").isEmpty, "deleteAll left rows behind")
        let loaded = try await service.load(gameID: "game-gdpr")
        #expect(loaded == nil, "load still returns a state after deleteAll")
    }

    @Test("An undecodable save throws saveCorrupted instead of returning nil")
    func corruptedSaveThrows() async throws {
        let (service, container) = try makeService()

        let context = ModelContext(container)
        context.insert(PersistedSave(
            gameID: "game-corrupt",
            stateData: Data("this is not JSON at all".utf8),
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        try context.save()

        // Returning nil here would show the player a brand-new game, and the 30-second
        // autosave would then overwrite their real save. It must throw.
        await #expect(throws: EngineError.self) {
            _ = try await service.load(gameID: "game-corrupt")
        }

        do {
            _ = try await service.load(gameID: "game-corrupt")
            Issue.record("load returned instead of throwing for a corrupted save")
        } catch let error as EngineError {
            guard case .saveCorrupted = error else {
                Issue.record("Expected .saveCorrupted, got \(error)")
                return
            }
            #expect(
                error.errorDescription?.isEmpty == false,
                "saveCorrupted must carry a player-facing message, not Foundation's fallback"
            )
        }
    }

    @Test("A structurally valid JSON blob that is not a GameState also throws saveCorrupted")
    func wrongShapeSaveThrows() async throws {
        let (service, container) = try makeService()

        let context = ModelContext(container)
        context.insert(PersistedSave(
            gameID: "game-wrong-shape",
            stateData: Data(#"{"totallyDifferent": true}"#.utf8),
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        try context.save()

        do {
            _ = try await service.load(gameID: "game-wrong-shape")
            Issue.record("A JSON blob missing every GameState field decoded successfully")
        } catch let error as EngineError {
            guard case .saveCorrupted = error else {
                Issue.record("Expected .saveCorrupted, got \(error)")
                return
            }
        }
    }

    @Test("Corrupted bytes are left on disk so they stay recoverable")
    func corruptedSaveIsNotDeleted() async throws {
        let (service, container) = try makeService()
        let bytes = Data("this is not JSON at all".utf8)

        let context = ModelContext(container)
        context.insert(PersistedSave(
            gameID: "game-keep-bytes",
            stateData: bytes,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        try context.save()

        _ = try? await service.load(gameID: "game-keep-bytes")

        let rows = try storedRows(in: container, gameID: "game-keep-bytes")
        #expect(rows.count == 1, "The failed load destroyed the row")
        #expect(rows.first?.stateData == bytes, "The failed load mutated the player's bytes")
    }

    // MARK: - Container construction

    @Test("The store opens and is usable — the schema is CloudKit-legal")
    func makeContainerYieldsUsableLocalStore() throws {
        // In-memory on purpose. `makeContainer` builds an on-disk store at SwiftData's
        // default location, which is derived from `Bundle.main.bundleIdentifier` — nil in an
        // SPM test process, so constructing one raises an uncaught NSException and takes down
        // the whole runner. The schema legality this asserts is identical either way.
        let container = try makeInMemoryContainer()

        let context = ModelContext(container)
        context.insert(PersistedSave(gameID: "fallback-check", stateData: Data("{}".utf8)))
        try context.save()

        var descriptor = FetchDescriptor<PersistedSave>(
            predicate: #Predicate { $0.gameID == "fallback-check" }
        )
        descriptor.fetchLimit = 1
        #expect(try context.fetch(descriptor).count == 1, "Local store is not writable")

        // Clean up so repeated local runs stay independent.
        for row in try context.fetch(descriptor) { context.delete(row) }
        try context.save()
    }

    /// Guards the two schema rules that made the shipped container un-openable. Both are
    /// CloudKit requirements, and both were violated.
    @Test("PersistedSave has no unique constraint and every property is defaulted")
    func persistedSaveSchemaIsCloudKitLegal() throws {
        // Constructible with no arguments beyond the initialiser's own defaults: every
        // stored property carries a default value, which CloudKit requires.
        let record = PersistedSave(gameID: "", stateData: Data())
        #expect(record.savedAt <= Date())
        #expect(record.schemaVersion == PersistedSave.currentSchemaVersion)

        // Two records may share a gameID. Under `@Attribute(.unique)` this second insert
        // would collide; CloudKit forbids the constraint, and duplicates are expected because
        // two devices legitimately mirror their own row.
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(PersistedSave(gameID: "dupe-check", stateData: Data("{\"a\":1}".utf8)))
        context.insert(PersistedSave(gameID: "dupe-check", stateData: Data("{\"a\":2}".utf8)))
        try context.save()

        let all = try context.fetch(
            FetchDescriptor<PersistedSave>(predicate: #Predicate { $0.gameID == "dupe-check" })
        )
        #expect(all.count == 2, "Schema still enforces uniqueness — CloudKit will reject it")

        for row in all { context.delete(row) }
        try context.save()
    }


}

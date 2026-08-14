import Foundation
import SwiftData

// MARK: - Protocol

/// Saves and restores game state. Injected into `GameEngine` at startup.
/// Production implementation uses SwiftData, optionally mirrored to CloudKit.
/// Test implementation uses an in-memory dictionary.
public protocol PersistenceService: Sendable {
    /// Persist the current game state for the given game ID.
    func save(state: GameState, gameID: String) async throws
    /// Load the most recent saved state.
    /// - Returns: `nil` only when no save exists (a genuinely new player).
    /// - Throws: `EngineError.saveCorrupted` when a save exists but cannot be decoded.
    ///   Callers must NOT treat that as a new player — see `SwiftDataPersistenceService.load`.
    func load(gameID: String) async throws -> GameState?
}

// MARK: - SwiftData Model

/// The stored save record.
///
/// **Every property is optional-with-default and there is no `@Attribute(.unique)`.**
/// Both are hard requirements of CloudKit-backed SwiftData, and violating either makes
/// `ModelContainer.init` throw at launch. That is exactly what shipped: `gameID` carried
/// a `.unique` constraint and all three properties were non-optional with no default, so
/// the container never opened, the error was swallowed by `try?`, and every save silently
/// became a no-op. No Idle Civilizations player's progress was ever written to disk.
///
/// Uniqueness is enforced in `save()` instead, which is where it has to live anyway:
/// CloudKit can legitimately mirror two records for the same `gameID` from two devices.
@Model
final class PersistedSave {
    var gameID: String = ""
    var stateData: Data = Data()
    var savedAt: Date = Date.distantPast
    /// Format version of `stateData`. Lets a future migration recognise and upgrade an old
    /// blob instead of failing to decode it and discarding the player's progress.
    var schemaVersion: Int = PersistedSave.currentSchemaVersion

    static let currentSchemaVersion = 1

    init(gameID: String, stateData: Data, savedAt: Date = .now) {
        self.gameID = gameID
        self.stateData = stateData
        self.savedAt = savedAt
        self.schemaVersion = PersistedSave.currentSchemaVersion
    }
}

// MARK: - SwiftData Implementation

/// Persists `GameState` as JSON via SwiftData, optionally mirrored to CloudKit.
///
/// **CloudKit setup required in Xcode:**
/// 1. Add the iCloud capability to the app target
/// 2. Enable CloudKit and create a container named `iCloud.<bundleID>`
/// 3. Pass the container identifier as `cloudKitContainerID`
///
/// If the CloudKit-backed store cannot be opened, this falls back to a purely local store
/// rather than failing. Losing sync is recoverable; losing the ability to save is not.
@ModelActor
public actor SwiftDataPersistenceService: PersistenceService {

    /// Canonical save encoder. Exposed so tests exercise the exact configuration production
    /// uses — both sides previously relied on Foundation defaults, so setting a strategy on
    /// one of them would have silently invalidated every existing save.
    ///
    /// `.sortedKeys` matters beyond tidiness: `GameState` holds dictionaries and sets whose
    /// encoding order is otherwise unspecified, so re-saving unchanged state produced
    /// different bytes every time. That defeats byte comparison, makes saves undiffable, and
    /// makes CloudKit treat an unchanged record as modified on every write.
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // MARK: - Container Construction

    /// Builds a container, preferring CloudKit and degrading to local-only on failure.
    ///
    /// - Parameter cloudKitContainerID: iCloud container identifier, or `nil` for local-only.
    /// - Parameter onCloudKitFailure: Invoked with the error when the CloudKit store could not
    ///   be opened and the local fallback was used. Wire this to analytics — a silent
    ///   degradation to local-only is exactly the failure that went undetected for months.
    public static func makeContainer(
        cloudKitContainerID: String?,
        onCloudKitFailure: ((any Error) -> Void)? = nil
    ) throws -> ModelContainer {
        if let id = cloudKitContainerID {
            do {
                return try ModelContainer(
                    for: PersistedSave.self,
                    configurations: ModelConfiguration(cloudKitDatabase: .private(id))
                )
            } catch {
                onCloudKitFailure?(error)
                // fall through to the local store
            }
        }
        // `.none` is required, not merely tidy: `ModelConfiguration`'s default is `.automatic`,
        // which re-enables CloudKit whenever the target carries an iCloud entitlement — which
        // this app does. Omitting it would reintroduce the same failure this fallback exists
        // to survive.
        return try ModelContainer(
            for: PersistedSave.self,
            configurations: ModelConfiguration(cloudKitDatabase: .none)
        )
    }

    public init(cloudKitContainerID: String? = nil, onCloudKitFailure: ((any Error) -> Void)? = nil) throws {
        let container = try Self.makeContainer(
            cloudKitContainerID: cloudKitContainerID,
            onCloudKitFailure: onCloudKitFailure
        )
        self.init(modelContainer: container)
    }

    // MARK: - Save

    public func save(state: GameState, gameID: String) throws {
        let stamped = state.markingSaved()
        let data: Data
        do {
            data = try Self.encoder.encode(stamped)
        } catch {
            throw EngineError.persistenceFailed("Encode failed: \(error.localizedDescription)")
        }

        do {
            let existing = try fetchRecords(gameID: gameID)
            if let newest = existing.first {
                newest.stateData = data
                newest.savedAt = .now
                newest.schemaVersion = PersistedSave.currentSchemaVersion
                // CloudKit can mirror duplicates for the same gameID from multiple devices.
                // Collapse them now so `load` can never resolve to a stale one.
                for stale in existing.dropFirst() {
                    modelContext.delete(stale)
                }
            } else {
                modelContext.insert(PersistedSave(gameID: gameID, stateData: data))
            }
            try modelContext.save()
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.persistenceFailed(error.localizedDescription)
        }
    }

    // MARK: - Load

    public func load(gameID: String) throws -> GameState? {
        let records: [PersistedSave]
        do {
            records = try fetchRecords(gameID: gameID)
        } catch {
            throw EngineError.persistenceFailed(error.localizedDescription)
        }

        guard let record = records.first else { return nil }

        do {
            return try Self.decoder.decode(GameState.self, from: record.stateData)
        } catch {
            // A save exists but will not decode. Returning `nil` here would present the
            // player with a brand-new game and the next autosave would overwrite the real
            // save 30 seconds later — silent, unrecoverable destruction of their progress.
            // Throw instead, and leave the bytes untouched so they stay recoverable.
            throw EngineError.saveCorrupted(
                "schemaVersion \(record.schemaVersion), saved \(record.savedAt): \(error.localizedDescription)"
            )
        }
    }

    /// Records for `gameID`, newest first.
    ///
    /// The sort is load-bearing. Without it `first` returned an arbitrary row in unspecified
    /// store order — and because CloudKit legitimately produces duplicate rows per `gameID`,
    /// that could resolve to a weeks-old save.
    private func fetchRecords(gameID: String) throws -> [PersistedSave] {
        var descriptor = FetchDescriptor<PersistedSave>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Data Deletion (GDPR)

    /// Permanently deletes every save for `gameID`. Used by "Delete My Data" in Settings.
    public func deleteAll(gameID: String) throws {
        do {
            for record in try fetchRecords(gameID: gameID) {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            throw EngineError.persistenceFailed(error.localizedDescription)
        }
    }
}

// MARK: - In-Memory Implementation (tests / previews)

/// Non-persisting in-memory implementation. Use in tests and SwiftUI Previews.
public actor InMemoryPersistenceService: PersistenceService {
    private var store: [String: GameState] = [:]

    public init() {}

    public func save(state: GameState, gameID: String) async {
        store[gameID] = state.markingSaved()
    }

    public func load(gameID: String) async -> GameState? {
        store[gameID]
    }

    public func deleteAll(gameID: String) async {
        store[gameID] = nil
    }
}

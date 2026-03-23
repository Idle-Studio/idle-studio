import Foundation
import SwiftData

// MARK: - Protocol

/// Saves and restores game state. Injected into `GameEngine` at startup.
/// Production implementation uses SwiftData + CloudKit.
/// Test implementation uses an in-memory dictionary.
public protocol PersistenceService: Sendable {
    /// Persist the current game state for the given game ID.
    func save(state: GameState, gameID: String) async throws
    /// Load the most recent saved state, or nil if no save exists.
    func load(gameID: String) async throws -> GameState?
}

// MARK: - SwiftData Model

@Model
final class PersistedSave {
    @Attribute(.unique) var gameID: String
    var stateData: Data
    var savedAt: Date

    init(gameID: String, stateData: Data) {
        self.gameID = gameID
        self.stateData = stateData
        self.savedAt = .now
    }
}

// MARK: - SwiftData + CloudKit Implementation

/// Persists `GameState` as JSON via SwiftData. Optionally syncs via CloudKit.
///
/// **CloudKit setup required in Xcode:**
/// 1. Add iCloud capability to the app target
/// 2. Enable CloudKit and create a container named `iCloud.<bundleID>`
/// 3. Pass the container identifier as `cloudKitContainerID`
@MainActor
public final class SwiftDataPersistenceService: PersistenceService, @unchecked Sendable {
    private let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(cloudKitContainerID: String? = nil) throws {
        let config: ModelConfiguration
        if let id = cloudKitContainerID {
            config = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(id)
            )
        } else {
            config = ModelConfiguration(isStoredInMemoryOnly: false)
        }
        container = try ModelContainer(for: PersistedSave.self, configurations: config)
    }

    public func save(state: GameState, gameID: String) async throws {
        let data: Data
        do { data = try encoder.encode(state) }
        catch { throw EngineError.persistenceFailed("Encode failed: \(error)") }

        let context = ModelContext(container)
        let existing = try context.fetch(FetchDescriptor<PersistedSave>())
            .filter { $0.gameID == gameID }
        if let record = existing.first {
            record.stateData = data
            record.savedAt = .now
        } else {
            context.insert(PersistedSave(gameID: gameID, stateData: data))
        }
        do { try context.save() }
        catch { throw EngineError.persistenceFailed("Save failed: \(error)") }
    }

    public func load(gameID: String) async throws -> GameState? {
        let context = ModelContext(container)
        let results = try context.fetch(FetchDescriptor<PersistedSave>())
            .filter { $0.gameID == gameID }
        guard let record = results.first else { return nil }
        return try decoder.decode(GameState.self, from: record.stateData)
    }
}

// MARK: - In-Memory Implementation (tests / previews)

/// Non-persisting in-memory implementation. Use in tests and SwiftUI Previews.
public actor InMemoryPersistenceService: PersistenceService {
    private var store: [String: GameState] = [:]

    public init() {}

    public func save(state: GameState, gameID: String) async {
        store[gameID] = state
    }

    public func load(gameID: String) async -> GameState? {
        store[gameID]
    }
}

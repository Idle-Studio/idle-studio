import Foundation
import GameKit

// MARK: - Protocol

/// Game Center leaderboards and achievements. All IDs come from the active theme.
public protocol GameCenterService: Sendable {
    /// Authenticate the local player. Must be called on app launch.
    func authenticate() async -> Bool
    /// Submit a score to a leaderboard. `leaderboardID` comes from `theme.leaderboards`.
    func submitScore(_ score: Int, to leaderboardID: String) async throws
    /// Fetch the top entries for display in the leaderboard screen.
    func fetchLeaderboard(id: String, scope: LeaderboardScope) async throws -> [LeaderboardEntry]
    /// Report an achievement as completed.
    func reportAchievement(id: String, percentComplete: Double) async throws
    /// Show the native Game Center view controller.
    func presentGameCenter() async
}

public enum LeaderboardScope: Sendable {
    case global
    case friends
    case country
}

public struct LeaderboardEntry: Sendable, Identifiable {
    public let id: String
    public let rank: Int
    public let playerName: String
    public let score: Int
    public let isLocalPlayer: Bool

    public init(id: String, rank: Int, playerName: String, score: Int, isLocalPlayer: Bool) {
        self.id = id
        self.rank = rank
        self.playerName = playerName
        self.score = score
        self.isLocalPlayer = isLocalPlayer
    }
}

// MARK: - Live Implementation

@MainActor
public final class LiveGameCenterService: GameCenterService, @unchecked Sendable {
    public init() {}

    public func authenticate() async -> Bool {
        // Fast-path: already authenticated — skip handler setup entirely.
        // This prevents a second authenticateHandler assignment from stranding
        // a concurrent continuation (the stuck-loading race on tab switches).
        if GKLocalPlayer.local.isAuthenticated { return true }

        // authenticateHandler can be called multiple times by GameKit (e.g. once
        // presenting a VC, once with the final result). Guard ensures we resume
        // the continuation exactly once.
        return await withCheckedContinuation { continuation in
            var resumed = false
            GKLocalPlayer.local.authenticateHandler = { _, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: GKLocalPlayer.local.isAuthenticated)
            }
        }
    }

    public func submitScore(_ score: Int, to leaderboardID: String) async throws {
        try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID])
    }

    public func fetchLeaderboard(id: String, scope: LeaderboardScope) async throws -> [LeaderboardEntry] {
        let boards = try await GKLeaderboard.loadLeaderboards(IDs: [id])
        guard let board = boards.first else { return [] }

        let gkScope: GKLeaderboard.PlayerScope = scope == .friends ? .friendsOnly : .global
        let timeScope: GKLeaderboard.TimeScope = (scope == .friends) ? .week : .allTime
        let (_, entries, _) = try await board.loadEntries(for: gkScope, timeScope: timeScope, range: NSRange(1...100))

        return entries.map { entry in
            LeaderboardEntry(
                id: entry.player.gamePlayerID,
                rank: entry.rank,
                playerName: entry.player.displayName,
                score: Int(entry.score),
                isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
            )
        }
    }

    public func reportAchievement(id: String, percentComplete: Double) async throws {
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percentComplete
        try await GKAchievement.report([achievement])
    }

    public func presentGameCenter() async {
        // Presented via GKGameCenterViewController from the calling SwiftUI view
    }
}

// MARK: - No-op stub

public struct NoOpGameCenterService: GameCenterService {
    public init() {}
    public func authenticate() async -> Bool { false }
    public func submitScore(_ score: Int, to leaderboardID: String) async throws {}
    public func fetchLeaderboard(id: String, scope: LeaderboardScope) async throws -> [LeaderboardEntry] { [] }
    public func reportAchievement(id: String, percentComplete: Double) async throws {}
    public func presentGameCenter() async {}
}

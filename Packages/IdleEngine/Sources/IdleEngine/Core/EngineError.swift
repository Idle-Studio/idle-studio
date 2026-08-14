import Foundation

/// Errors thrown by the game engine. All cases are theme-agnostic.
public enum EngineError: Error, Sendable, Equatable {
    case themeNotLoaded
    case themeNotFound(String)
    case unknownUnit(String)
    case unknownLevel(String)
    case insufficientResources
    case noNextLevel
    case alreadyCompleted(String)
    case prestigeNotAvailable
    case validationFailed([String])
    case schemaVersionMismatch(found: String, expected: String)
    case persistenceFailed(String)
    case constructionInProgress
    case milestonesIncomplete
    case invalidQuantity(Int)
    /// A save exists on disk but could not be decoded. Carries the underlying reason.
    /// The engine must never treat this as "new player" — doing so destroys real progress.
    case saveCorrupted(String)
}

// MARK: - Player-Facing Messages

/// Without this conformance `error.localizedDescription` produces Foundation's
/// fallback — "The operation couldn't be completed. (IdleEngine.EngineError error 9.)" —
/// which is what players were being shown on the load-failure screen.
extension EngineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .themeNotLoaded:
            return String(localized: "The game is still starting up. Please try again in a moment.")
        case .themeNotFound(let name):
            return String(localized: "Game content \(name) is missing from this build.")
        case .unknownUnit(let id):
            return String(localized: "That item is no longer available (\(id)).")
        case .unknownLevel(let id):
            return String(localized: "That stage is no longer available (\(id)).")
        case .insufficientResources:
            return String(localized: "Not enough resources yet.")
        case .noNextLevel:
            return String(localized: "You've reached the final stage.")
        case .alreadyCompleted:
            return String(localized: "You've already completed that.")
        case .prestigeNotAvailable:
            return String(localized: "You don't meet the requirements to reset yet.")
        case .validationFailed(let problems):
            let detail = problems.prefix(3).joined(separator: "\n• ")
            return String(localized: "This game's content failed validation:\n• \(detail)")
        case .schemaVersionMismatch(let found, let expected):
            return String(localized: "This game's content is version \(found) but the app expects \(expected). Please update the app.")
        case .persistenceFailed(let reason):
            return String(localized: "Your progress could not be saved: \(reason)")
        case .constructionInProgress:
            return String(localized: "Something is already under construction. Finish it first.")
        case .milestonesIncomplete:
            return String(localized: "Complete this stage's objectives first.")
        case .invalidQuantity(let quantity):
            return String(localized: "Invalid quantity: \(quantity).")
        case .saveCorrupted(let reason):
            return String(localized: "Your saved game could not be read: \(reason)")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .saveCorrupted, .persistenceFailed:
            return String(localized: "Please contact support before reinstalling — your progress may still be recoverable.")
        case .themeNotFound, .validationFailed, .schemaVersionMismatch:
            return String(localized: "Reinstalling the app should resolve this. Contact support if it persists.")
        default:
            return nil
        }
    }
}

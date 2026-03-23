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
}

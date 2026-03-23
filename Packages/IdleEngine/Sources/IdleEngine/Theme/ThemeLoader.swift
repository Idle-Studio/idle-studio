import Foundation

/// Loads a `JSONThemePackage` from the app bundle by filename.
/// Each game target ships its theme JSON file (e.g. `civilizations.json`) in its bundle.
public enum ThemeLoader {

    /// Load and decode a theme from `[name].json` in the given bundle.
    /// - Parameters:
    ///   - name: The filename without extension (e.g. `"civilizations"`).
    ///   - bundle: The bundle containing the JSON file. Defaults to `.main`.
    /// - Throws: `EngineError.themeNotFound` if the file is missing, or a `DecodingError` if the JSON is malformed.
    public static func load(named name: String, in bundle: Bundle = .main) throws -> JSONThemePackage {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw EngineError.themeNotFound(name)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(JSONThemePackage.self, from: data)
    }
}

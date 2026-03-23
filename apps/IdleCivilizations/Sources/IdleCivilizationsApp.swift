import SwiftUI
import IdleEngine

@main
struct IdleCivilizationsApp: App {
    var body: some Scene {
        WindowGroup {
            IdleGameRoot(themeName: "idle-civilizations")
        }
    }
}

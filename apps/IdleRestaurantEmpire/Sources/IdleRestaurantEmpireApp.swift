import SwiftUI
import IdleEngine

@main
@MainActor
struct IdleRestaurantEmpireApp: App {
    // Ad-free entitlement is resolved by `EntitlementStore` from the theme's own
    // `iapProducts` — no product identifier is hardcoded here. See the note in
    // IdleCivilizationsApp for why the injected-string version was removed.
    private let adService: any AdService = GoogleMobileAdsService()

    var body: some Scene {
        WindowGroup {
            IdleGameRoot(themeName: "idle-restaurant-empire")
                .environment(\.adService, adService)
        }
    }
}

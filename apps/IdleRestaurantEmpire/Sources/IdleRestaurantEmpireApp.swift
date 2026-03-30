import SwiftUI
import IdleEngine

@main
struct IdleRestaurantEmpireApp: App {
    // Remove-ads product ID must match idle-restaurant-empire.json iapProducts.removeAds
    private let adService: any AdService = GoogleMobileAdsService(
        removeAdsProductID: "com.idlestudio.idlerestaurant.remove_ads"
    )

    var body: some Scene {
        WindowGroup {
            IdleGameRoot(themeName: "idle-restaurant-empire")
                .environment(\.adService, adService)
        }
    }
}

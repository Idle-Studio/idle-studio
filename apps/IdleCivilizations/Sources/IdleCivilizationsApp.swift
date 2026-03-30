import SwiftUI
import IdleEngine

@main
struct IdleCivilizationsApp: App {
    // Remove-ads product ID must match civilizations.json iapProducts.removeAds
    private let adService: any AdService = GoogleMobileAdsService(
        removeAdsProductID: "com.yourstudio.idlecivilizations.remove_ads"
    )

    var body: some Scene {
        WindowGroup {
            IdleGameRoot(
                themeName: "idle-civilizations",
                cloudKitContainerID: "iCloud.com.idlestudio.idleciv"
            )
            .environment(\.adService, adService)
        }
    }
}

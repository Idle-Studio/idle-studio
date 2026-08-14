import SwiftUI
import IdleEngine

@main
@MainActor
struct IdleCivilizationsApp: App {
    // Ad-free entitlement is resolved by `EntitlementStore` from the theme's own
    // `iapProducts`, so no product identifier is hardcoded here.
    //
    // This used to take a `removeAdsProductID` string, and the value passed was
    // "com.yourstudio.idlecivilizations.remove_ads" — scaffold placeholder text copied from
    // a stale theme file. The real product is "com.idlestudio.idleciv.remove_ads", so the
    // comparison never matched and every player who paid $4.99 to remove ads kept seeing
    // them, permanently, on every device.
    private let adService: any AdService = GoogleMobileAdsService()

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

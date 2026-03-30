fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios setup_signing

```sh
[bundle exec] fastlane ios setup_signing
```

Sync certificates and provisioning profiles for GAME

### ios nuke_signing

```sh
[bundle exec] fastlane ios nuke_signing
```

Revoke and regenerate all certificates for GAME (emergency use only)

### ios build

```sh
[bundle exec] fastlane ios build
```

Archive GAME and export an App Store .ipa

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build GAME and upload to TestFlight (internal testers only)

### ios distribute_beta

```sh
[bundle exec] fastlane ios distribute_beta
```

Distribute latest processed TestFlight build to all external groups

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload App Store text metadata and screenshots for GAME from metadata/ folder

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload App Store screenshots for GAME

### ios sync_iap

```sh
[bundle exec] fastlane ios sync_iap
```

Sync IAP products from .storekit config → ASC for GAME

### ios sync_gamecenter

```sh
[bundle exec] fastlane ios sync_gamecenter
```

Sync Game Center leaderboards/achievements from ThemePackage → ASC for GAME

### ios fetch_reports

```sh
[bundle exec] fastlane ios fetch_reports
```

Pull sales and download reports for GAME (--days N)

### ios review_status

```sh
[bundle exec] fastlane ios review_status
```

Check App Store review status for GAME

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

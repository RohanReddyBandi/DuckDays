# Shipping Duck Days

What is already done in this repo, and what only you can do.

## Done here

- **Privacy manifest** (`Shared/PrivacyInfo.xcprivacy`), bundled into both the app and
  the widget extension. Declares no tracking, no collected data, and the App Group
  `UserDefaults` access that `CountdownStore` uses.
- **Export compliance** — `ITSAppUsesNonExemptEncryption = NO` in the app's Info.plist,
  so App Store Connect stops asking on every upload. The app has no network or crypto
  code, so this is accurate.
- **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`). The layout was never designed or
  tested for iPad; claiming iPad support means Apple reviews it there and you owe iPad
  screenshots. Flip it back to `"1,2"` if you want iPad, but do the layout work first.
- **App icon** is 1024×1024 with no alpha channel. Alpha in an app icon is an automatic
  rejection.
- **Versions match** across the app and the widget (`1.0` / build `1`). A mismatch is
  rejected at upload.
- **Release build for arm64 devices and `xcodebuild archive` both succeed**, with the
  widget correctly embedded in `PlugIns/`.

## Only you can do these

### 1. Apple Developer Program

Paid membership, $99/year. A free Apple ID cannot publish.

### 2. Register identifiers

On [developer.apple.com](https://developer.apple.com/account/resources/identifiers):

| What | Identifier |
| --- | --- |
| App ID | `com.rohan.duckdays` |
| App ID (widget) | `com.rohan.duckdays.DuckWidget` |
| App Group | `group.com.rohan.duckdays` |

Enable the **App Groups** capability on both App IDs and tick the group.

Bundle IDs are globally unique — if `com.rohan.duckdays` is taken, pick another and
change it in `project.pbxproj` (both targets). If you change the **App Group**, update
it in three places: `Shared/Countdown.swift`, `DuckDays/DuckDays.entitlements`, and
`DuckWidget/DuckWidget.entitlements`.

### 3. Signing

Open the project in Xcode → each target → **Signing & Capabilities** → set your Team.
I deliberately did not hardcode a team ID; it depends on which account you publish under.

### 4. App Store Connect

Create the app record, then fill in:

- **Screenshots** — 6.9″ iPhone required (1320×2868). Capture from the simulator with
  an iPhone 17 Pro Max. Show the countdown, a couple of ducks, and the widget on a home
  screen.
- **Privacy nutrition label** — answer **Data Not Collected**. It matches the manifest.
- **Category** — Utilities fits; Lifestyle also defensible.
- **Age rating** — 4+.
- **Privacy policy URL** — required for every app. `PRIVACY.md` in this repo is ready to
  publish; turning on GitHub Pages gives you a URL for free.
- **Support URL** — required. The repo's issues page works.

### 5. Verify before you submit

- Run on a **real device**, not just the simulator. Widget refresh behaviour and the
  App Group container both differ there, and the duck's motion rate is throttled by
  iOS power management in ways the simulator does not model.
- Double-check the privacy manifest reason code `1C8F.1` against
  [Apple's current list](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api).
  It is the App Group `UserDefaults` reason, which is what this app does, but Apple
  revises these and a wrong code earns a warning email after upload.

## Bumping a release

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` appear in **four** build
configurations — Debug and Release for each target. Keep all four in step.

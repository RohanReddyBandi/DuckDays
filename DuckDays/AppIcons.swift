import SwiftUI
import UIKit

/// Which duck the home screen icon shows.
///
/// Every style has an icon set in the asset catalog, written by
/// `tools/duck_forge.py icons` from the same sprite the widget draws. The
/// default duck's set is plain `AppIcon`; the rest are `AppIcon-<name>` and are
/// addressed as alternates.
///
/// The coupling to the forge is by name and is not checked at build time — an
/// icon set that is missing, or missing from
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`, fails only when someone
/// taps it. `verify()` exists to make that visible in a debug run.
@MainActor
enum AppIcons {
    /// The style whose icon set is `AppIcon` rather than an alternate. Must
    /// match `DEFAULT_ICON` in tools/duck_forge.py.
    static let defaultStyleID = "classic"

    static func setName(for style: DuckStyle) -> String? {
        style.id == defaultStyleID ? nil : "AppIcon-\(style.name)"
    }

    static var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    /// The style currently on the home screen, falling back to the default.
    static var current: DuckStyle {
        guard let name = UIApplication.shared.alternateIconName else {
            return DuckStyle.named(defaultStyleID)
        }
        let duck = name.replacingOccurrences(of: "AppIcon-", with: "")
        return DuckStyle.all.first { $0.name == duck }
            ?? DuckStyle.named(defaultStyleID)
    }

    /// iOS puts up its own "you have changed the icon" alert on success. That
    /// is not suppressible outside private API, so the app does not try — it
    /// just avoids triggering it when nothing would change.
    static func apply(_ style: DuckStyle) async -> Bool {
        let name = setName(for: style)
        guard isSupported, name != UIApplication.shared.alternateIconName else {
            return false
        }
        do {
            try await UIApplication.shared.setAlternateIconName(name)
            return true
        } catch {
            return false
        }
    }

    #if DEBUG
    /// Every alternate this app offers has to appear in CFBundleAlternateIcons,
    /// which the asset catalog only writes for names listed in the build
    /// setting. Checking here turns a silent runtime failure into a log line.
    static func verify() {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let alternates = icons?["CFBundleAlternateIcons"] as? [String: Any] ?? [:]
        let missing = DuckStyle.all.compactMap(setName(for:))
            .filter { alternates[$0] == nil }
        if missing.isEmpty {
            print("[AppIcons] \(alternates.count) alternate icons registered")
        } else {
            print("[AppIcons] MISSING from the bundle: \(missing.joined(separator: ", "))")
        }
    }
    #endif
}

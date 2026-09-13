import Foundation

/// Ducks you earn rather than choose, and what earns them.
///
/// The duck is looked up from the style table by its `reward` field rather than
/// named here, so there is one place that decides which duck belongs to which
/// challenge and the picker cannot disagree with the rules.
enum DuckChallenge: String, CaseIterable, Identifiable {
    case firstArrival

    var id: String { rawValue }

    var style: DuckStyle? {
        DuckStyle.all.first { $0.reward == rawValue }
    }

    /// Shown once, on the card that appears when it is earned.
    var title: String {
        switch self {
        case .firstArrival: return "The day came"
        }
    }

    /// Shown on the locked duck in the picker. Says what to do, not what it is.
    var hint: String {
        switch self {
        case .firstArrival: return "Reach zero"
        }
    }

    var blurb: String {
        switch self {
        case .firstArrival:
            return "You set a date, waited it out, and it arrived. Star was there for it."
        }
    }

    func isSatisfied(by events: [CountdownEvent], now: Date) -> Bool {
        switch self {
        case .firstArrival:
            // Waited for, not backdated. `createdAt < date` is what makes
            // typing in last week's date fail to earn this.
            return events.contains { $0.createdAt < $0.date && $0.date <= now }
        }
    }
}

/// Which challenges have been earned. Lives in the App Group beside the
/// countdowns so it survives reinstall-free updates the same way they do.
enum DuckUnlocks {
    private static let key = "duckdays.unlocked"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: duckAppGroupID) ?? .standard
    }

    static var earned: Set<String> {
        get { Set(defaults.stringArray(forKey: key) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: key) }
    }

    static func isLocked(_ style: DuckStyle) -> Bool {
        guard let reward = style.reward else { return false }
        return !earned.contains(reward)
    }

    static func challenge(for style: DuckStyle) -> DuckChallenge? {
        style.reward.flatMap(DuckChallenge.init(rawValue:))
    }

    /// Checks every rule and banks any that now pass, returning only the ones
    /// newly earned so the caller can celebrate exactly once.
    @discardableResult
    static func evaluate(_ events: [CountdownEvent],
                         now: Date = Date()) -> [DuckChallenge] {
        var banked = earned
        var fresh: [DuckChallenge] = []
        for challenge in DuckChallenge.allCases
        where !banked.contains(challenge.rawValue) {
            guard challenge.isSatisfied(by: events, now: now) else { continue }
            banked.insert(challenge.rawValue)
            fresh.append(challenge)
        }
        if !fresh.isEmpty { earned = banked }
        return fresh
    }
}

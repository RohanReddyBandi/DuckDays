import Foundation
import SwiftUI

let duckAppGroupID = "group.com.rohanreddybandi.duckdays"

struct CountdownEvent: Codable, Equatable {
    var title: String
    var date: Date
    var styleID: String
    /// Whether the **widget** gets a dense timeline so the duck moves. Off means
    /// a handful of entries a day instead of one every few seconds. It says
    /// nothing about the app, where the duck always animates — the app has a run
    /// loop and animating costs it nothing worth saving.
    var motion: Bool

    init(title: String, date: Date, styleID: String = DuckStyle.fallback.id,
         motion: Bool = true) {
        self.title = title
        self.date = date
        self.styleID = styleID
        self.motion = motion
    }

    /// Tolerates payloads written before styles existed rather than failing to decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        styleID = try c.decodeIfPresent(String.self, forKey: .styleID)
            ?? DuckStyle.fallback.id
        motion = try c.decodeIfPresent(Bool.self, forKey: .motion) ?? true
    }

    var style: DuckStyle { DuckStyle.named(styleID) }

    static let placeholder = CountdownEvent(
        title: "Something good",
        date: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
    )

    /// Whole days between today and the event day, ignoring time of day.
    /// Positive means the future, zero means today, negative means it already happened.
    func daysRemaining(from reference: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }
}

/// Shared storage. The app writes, the widget reads, and they meet in the App Group.
enum CountdownStore {
    private static let key = "duckdays.event"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: duckAppGroupID) ?? .standard
    }

    static func load() -> CountdownEvent {
        guard let data = defaults.data(forKey: key),
              let event = try? JSONDecoder().decode(CountdownEvent.self, from: data) else {
            return .placeholder
        }
        return event
    }

    static func save(_ event: CountdownEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        defaults.set(data, forKey: key)
    }
}

/// The two lines of the counter, which change as the date passes.
///
/// The split is count-and-unit on top, direction-and-subject underneath:
/// "12 Days" / "until graduation". The unit belongs with the number because
/// "12 Days" is one phrase read at one size; only the event is secondary.
enum CountdownPhrasing {
    /// The big line. Set at the headline size in full — the word is part of
    /// the number, not a caption for it.
    static func headline(for days: Int) -> String {
        switch abs(days) {
        case 0: return "TODAY"
        case 1: return "1 Day"
        default: return "\(abs(days)) Days"
        }
    }

    /// The small line under it.
    static func caption(for days: Int, title: String) -> String {
        switch days {
        case 0: return "it's \(title)!"
        case let d where d > 0: return "until \(title)"
        default: return "since \(title)"
        }
    }

    /// Short form for the cramped lock screen widgets.
    static func compact(for days: Int, title: String) -> String {
        switch days {
        case 0: return "\(title) today!"
        case 1: return "1 day to \(title)"
        case let d where d > 1: return "\(d) days to \(title)"
        default: return "\(title) passed"
        }
    }
}

import Foundation
import SwiftUI

let duckAppGroupID = "group.com.rohanreddybandi.duckdays"

struct CountdownEvent: Codable, Equatable {
    var title: String
    var date: Date
    var styleID: String
    /// Whether the widget gets a dense timeline so the duck moves. Off means a
    /// handful of entries a day instead of one every minute.
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

/// The phrasing under the big number, which changes as the date passes.
enum CountdownPhrasing {
    static func headline(for days: Int) -> String {
        switch days {
        case 0: return "TODAY"
        case 1: return "1"
        default: return "\(abs(days))"
        }
    }

    static func caption(for days: Int, title: String) -> String {
        switch days {
        case 0: return "It's \(title) day!"
        case 1: return "day until \(title)"
        case let d where d > 1: return "days until \(title)"
        case -1: return "day since \(title)"
        default: return "days since \(title)"
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

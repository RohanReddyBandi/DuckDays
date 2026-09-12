import Foundation
import SwiftUI

let duckAppGroupID = "group.com.rohanreddybandi.duckdays"

struct CountdownEvent: Codable, Equatable, Identifiable {
    /// Stable identity. This is what a configured widget stores to say which
    /// countdown it is showing, so it must survive edits and reordering — never
    /// regenerate it for an event that already has one.
    var id: UUID
    var title: String
    var date: Date
    var styleID: String
    /// Whether the **widget** gets a dense timeline so the duck moves. Off means
    /// a handful of entries a day instead of one every few seconds. It says
    /// nothing about the app, where the duck always animates — the app has a run
    /// loop and animating costs it nothing worth saving.
    var motion: Bool
    var precision: Precision

    /// How far down the countdown counts.
    ///
    /// `.day` counts **calendar days**, so an event tomorrow morning reads as
    /// "1 Day" at eleven tonight rather than "9 Hrs". `.minute` counts the real
    /// interval. They disagree on purpose: one answers "how many more sleeps",
    /// the other "how long from now".
    enum Precision: String, Codable, CaseIterable {
        case day, minute
    }

    init(id: UUID = UUID(), title: String, date: Date,
         styleID: String = DuckStyle.fallback.id, motion: Bool = true,
         precision: Precision = .day) {
        self.id = id
        self.title = title
        self.date = date
        self.styleID = styleID
        self.motion = motion
        self.precision = precision
    }

    /// Tolerates payloads written by any earlier version rather than failing to
    /// decode — a throw here would silently empty somebody's widget.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        styleID = try c.decodeIfPresent(String.self, forKey: .styleID)
            ?? DuckStyle.fallback.id
        motion = try c.decodeIfPresent(Bool.self, forKey: .motion) ?? true
        precision = try c.decodeIfPresent(Precision.self, forKey: .precision) ?? .day
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

    /// The real interval, broken into whole units. Unlike `daysRemaining` this
    /// measures from the instant, not from midnight.
    func remaining(from reference: Date = Date()) -> (days: Int, hours: Int,
                                                      minutes: Int, past: Bool) {
        let seconds = Int(date.timeIntervalSince(reference))
        let past = seconds < 0
        let total = abs(seconds)
        return (total / 86_400, (total % 86_400) / 3600, (total % 3600) / 60, past)
    }

    /// Which direction the caption reads, for either precision.
    func isPast(from reference: Date = Date()) -> Bool {
        precision == .day ? daysRemaining(from: reference) < 0
                          : remaining(from: reference).past
    }
}

/// Shared storage. The app writes, the widget reads, and they meet in the App Group.
///
/// The list is the source of truth. Version 1.0 stored exactly one event under
/// its own key, so the first read migrates that into a one-item list and leaves
/// the old key alone — an app that is rolled back should still find its event.
enum CountdownStore {
    private static let listKey = "duckdays.events"
    private static let legacyKey = "duckdays.event"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: duckAppGroupID) ?? .standard
    }

    static func loadAll() -> [CountdownEvent] {
        if let data = defaults.data(forKey: listKey),
           let events = try? JSONDecoder().decode([CountdownEvent].self, from: data),
           !events.isEmpty {
            return events
        }
        if let data = defaults.data(forKey: legacyKey),
           let event = try? JSONDecoder().decode(CountdownEvent.self, from: data) {
            saveAll([event])
            return [event]
        }
        return [.placeholder]
    }

    static func saveAll(_ events: [CountdownEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: listKey)
    }

    /// What a widget resolves its configuration to.
    ///
    /// Falls back to the first countdown rather than to a placeholder: a widget
    /// whose countdown was deleted should keep showing something real, and an
    /// unconfigured widget has no id at all.
    static func event(id: UUID?) -> CountdownEvent {
        let all = loadAll()
        guard let id, let hit = all.first(where: { $0.id == id }) else {
            return all.first ?? .placeholder
        }
        return hit
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
    static func headline(for event: CountdownEvent, at reference: Date) -> String {
        switch event.precision {
        case .day:
            return dayHeadline(for: event.daysRemaining(from: reference))
        case .minute:
            return minuteHeadline(for: event.remaining(from: reference))
        }
    }

    static func dayHeadline(for days: Int) -> String {
        switch abs(days) {
        case 0: return "TODAY"
        case 1: return "1 Day"
        default: return "\(abs(days)) Days"
        }
    }

    /// Two units, never three: "3 Days 4 Hrs" then "4 Hrs 37 Min" then "37 Min".
    /// Three would not fit the headline at small size, and the smallest unit of
    /// the three is noise next to the largest.
    static func minuteHeadline(
        for parts: (days: Int, hours: Int, minutes: Int, past: Bool)
    ) -> String {
        let day = parts.days == 1 ? "Day" : "Days"
        let hour = parts.hours == 1 ? "Hr" : "Hrs"
        if parts.days > 0 {
            return parts.hours > 0 ? "\(parts.days) \(day) \(parts.hours) \(hour)"
                                   : "\(parts.days) \(day)"
        }
        if parts.hours > 0 {
            return "\(parts.hours) \(hour) \(parts.minutes) Min"
        }
        if parts.minutes > 0 { return "\(parts.minutes) Min" }
        return "NOW"
    }

    /// The small line under it.
    static func caption(for event: CountdownEvent, at reference: Date) -> String {
        let title = event.title
        if event.precision == .day {
            let days = event.daysRemaining(from: reference)
            if days == 0 { return "it's \(title)!" }
            return days > 0 ? "until \(title)" : "since \(title)"
        }
        let parts = event.remaining(from: reference)
        if parts.days == 0 && parts.hours == 0 && parts.minutes == 0 {
            return "it's \(title)!"
        }
        return parts.past ? "since \(title)" : "until \(title)"
    }

    /// Short form for the cramped lock screen widgets.
    static func compact(for event: CountdownEvent, at reference: Date) -> String {
        let title = event.title
        if event.precision == .minute {
            let parts = event.remaining(from: reference)
            let head = minuteHeadline(for: parts)
            if head == "NOW" { return "\(title) now!" }
            return parts.past ? "\(head) since \(title)" : "\(head) to \(title)"
        }
        switch event.daysRemaining(from: reference) {
        case 0: return "\(title) today!"
        case 1: return "1 day to \(title)"
        case let d where d > 1: return "\(d) days to \(title)"
        default: return "\(title) passed"
        }
    }
}

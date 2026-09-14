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
    /// When the countdown was set. Only the unlock rules read it: "a countdown
    /// you waited for" has to mean the date was still ahead when you set it,
    /// or typing in last week's date would earn the reward instantly.
    var createdAt: Date

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
         precision: Precision = .day, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.date = date
        self.styleID = styleID
        self.motion = motion
        self.precision = precision
        self.createdAt = createdAt
    }

    /// Tolerates payloads written by any earlier version rather than failing to
    /// decode — a throw here would silently empty somebody's widget.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        id = try c.decodeIfPresent(UUID.self, forKey: .id)
            ?? Self.legacyID(title: title, date: date)
        styleID = try c.decodeIfPresent(String.self, forKey: .styleID)
            ?? DuckStyle.fallback.id
        motion = try c.decodeIfPresent(Bool.self, forKey: .motion) ?? true
        precision = try c.decodeIfPresent(Precision.self, forKey: .precision) ?? .day
        // Migrated events have no creation date. Clamping to the target keeps a
        // countdown that already passed from counting as one somebody waited
        // for, while one still ahead is credited from now.
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
            ?? min(Date(), date)
    }

    var style: DuckStyle { DuckStyle.named(styleID) }

    /// A stable id for an event written before ids existed, derived from what
    /// the event *is* instead of rolled at random.
    ///
    /// Both the app and the widget decode that payload. With `UUID()` here each
    /// process invented its own id for the same countdown, so a widget
    /// configured against one could never find it in the other. Deriving it
    /// from title and date means every decode, in every process, agrees.
    ///
    /// FNV-1a rather than a cryptographic hash on purpose: this is an identifier,
    /// not a secret, and the app's export-compliance answer is that it contains
    /// no cryptography at all.
    static func legacyID(title: String, date: Date) -> UUID {
        let seed = Array("\(title)|\(date.timeIntervalSince1970)".utf8)
        func fnv(_ basis: UInt64) -> UInt64 {
            var hash = basis
            for byte in seed {
                hash ^= UInt64(byte)
                hash = hash &* 0x100000001b3
            }
            return hash
        }
        let high = fnv(0xcbf29ce484222325)
        let low = fnv(0x84222325cbf29ce4)
        var b = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            b[i] = UInt8(truncatingIfNeeded: high >> (UInt64(i) * 8))
            b[8 + i] = UInt8(truncatingIfNeeded: low >> (UInt64(i) * 8))
        }
        b[6] = (b[6] & 0x0F) | 0x50      // version nibble: name-based
        b[8] = (b[8] & 0x3F) | 0x80      // RFC 4122 variant
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

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
    func remaining(from reference: Date = Date()) -> Remaining {
        let signed = Int(date.timeIntervalSince(reference))
        let total = abs(signed)
        return Remaining(days: total / 86_400, hours: (total % 86_400) / 3600,
                         minutes: (total % 3600) / 60, seconds: total % 60,
                         past: signed < 0)
    }

    struct Remaining {
        var days: Int
        var hours: Int
        var minutes: Int
        var seconds: Int
        var past: Bool
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
/// its own key; reading falls back to it and leaves the old key alone, so an app
/// that is rolled back still finds its event.
///
/// **Reading never writes.** It used to: a read that missed the list would save
/// a one-item list built from the old key. Both the app and the widget read,
/// so either process could clobber the other's list down to its first
/// countdown. The app saves the list on its own the moment it loads.
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

    /// A cascade rather than a fixed pair of units. Whole days while there is
    /// more than a day left, then hours and minutes, then minutes and seconds,
    /// then seconds — so the largest thing on screen is always the unit that is
    /// actually moving, and the last minute genuinely ticks.
    ///
    /// Days alone above 24 hours on purpose: "26 Days 4 Hrs" reads as precision
    /// nobody asked for at that distance, and the hours figure is stale within
    /// the hour anyway.
    static func minuteHeadline(for parts: CountdownEvent.Remaining) -> String {
        if parts.days > 0 {
            return parts.days == 1 ? "1 Day" : "\(parts.days) Days"
        }
        if parts.hours > 0 {
            return "\(parts.hours) \(parts.hours == 1 ? "Hr" : "Hrs") \(parts.minutes) Min"
        }
        if parts.minutes > 0 { return "\(parts.minutes) Min \(parts.seconds) Sec" }
        if parts.seconds > 0 { return "\(parts.seconds) Sec" }
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
        if parts.days == 0 && parts.hours == 0 && parts.minutes == 0
            && parts.seconds == 0 {
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

import Foundation

var failures = 0
func check(_ actual: String, _ expected: String, _ label: String) {
    let ok = actual == expected
    if !ok { failures += 1 }
    print("\(ok ? "PASS" : "FAIL")  \(label.padding(toLength: 34, withPad: " ", startingAt: 0)) \(actual)\(ok ? "" : "   expected: \(expected)")")
}

let now = Date()
func event(_ offset: TimeInterval, _ p: CountdownEvent.Precision,
           _ title: String = "Fall Break") -> CountdownEvent {
    CountdownEvent(title: title, date: now.addingTimeInterval(offset), precision: p)
}
let day = 86_400.0, hour = 3600.0, minute = 60.0

print("— minute precision: the cascade —")
// Days while more than a day is left; then hours + minutes; then minutes +
// seconds; then seconds; then NOW. Each step is pinned at both of its edges.
check(CountdownPhrasing.headline(for: event(3*day + 4*hour + 37*minute, .minute), at: now), "3 Days", "days only above 24h")
check(CountdownPhrasing.headline(for: event(day + hour + 5, .minute), at: now), "1 Day", "1 day, singular")
check(CountdownPhrasing.headline(for: event(day + 5, .minute), at: now), "1 Day", "just over 24h is still a day")
check(CountdownPhrasing.headline(for: event(day - 60, .minute), at: now), "23 Hrs 59 Min", "just under 24h drops to hours")
check(CountdownPhrasing.headline(for: event(4*hour + 37*minute + 5, .minute), at: now), "4 Hrs 37 Min", "hours and minutes")
// 5-second steps, rounded up while counting down; zero minor units dropped.
check(CountdownPhrasing.headline(for: event(hour + 5, .minute), at: now), "1 Hr", "1 hour, zero minutes dropped")
check(CountdownPhrasing.headline(for: event(hour - 1, .minute), at: now), "1 Hr", "rounds up, never under-reads")
check(CountdownPhrasing.headline(for: event(37*minute + 12, .minute), at: now), "37 Min 15 Sec", "minutes, seconds in 5s steps")
check(CountdownPhrasing.headline(for: event(61, .minute), at: now), "1 Min 5 Sec", "just over a minute")
check(CountdownPhrasing.headline(for: event(60, .minute), at: now), "1 Min", "1 min")
check(CountdownPhrasing.headline(for: event(57, .minute), at: now), "1 Min", "57s still reads 1 min")
check(CountdownPhrasing.headline(for: event(55, .minute), at: now), "55 Sec", "55 sec")
check(CountdownPhrasing.headline(for: event(53, .minute), at: now), "55 Sec", "53s reads 55")
check(CountdownPhrasing.headline(for: event(50, .minute), at: now), "50 Sec", "50 sec")
check(CountdownPhrasing.headline(for: event(1, .minute), at: now), "5 Sec", "last step before zero")
check(CountdownPhrasing.headline(for: event(0, .minute), at: now), "NOW", "zero")
// Held at NOW for the first minute after, then counting up rounds down.
check(CountdownPhrasing.headline(for: event(-30, .minute), at: now), "NOW", "held 30s after")
check(CountdownPhrasing.headline(for: event(-59, .minute), at: now), "NOW", "still held at 59s after")
check(CountdownPhrasing.headline(for: event(-60, .minute), at: now), "1 Min", "counting up starts at a minute")
check(CountdownPhrasing.headline(for: event(-64, .minute), at: now), "1 Min", "past rounds down")
check(CountdownPhrasing.headline(for: event(-65, .minute), at: now), "1 Min 5 Sec", "then steps by 5")
check(CountdownPhrasing.headline(for: event(-(2*day + 5*hour), .minute), at: now), "2 Days", "past reads as magnitude")

print("\n— day precision headline —")
// Calendar days, not raw seconds: "tomorrow" is a calendar relationship, and
// now + 1.5 days lands two days out whenever the clock is past noon.
func inDays(_ n: Int) -> CountdownEvent {
    let when = Calendar.current.date(byAdding: .day, value: n, to: now)!
    return CountdownEvent(title: "Fall Break", date: when, precision: .day)
}
check(CountdownPhrasing.headline(for: inDays(28), at: now), "28 Days", "28 days")
check(CountdownPhrasing.headline(for: inDays(1), at: now), "1 Day", "tomorrow")
check(CountdownPhrasing.headline(for: inDays(0), at: now), "TODAY", "today")
check(CountdownPhrasing.headline(for: inDays(-1), at: now), "1 Day", "yesterday")
check(CountdownPhrasing.caption(for: inDays(-1), at: now), "since Fall Break", "yesterday reads back")

print("\n— caption direction —")
check(CountdownPhrasing.caption(for: event(3*day, .minute), at: now), "until Fall Break", "future, minute")
check(CountdownPhrasing.caption(for: event(-3*day, .minute), at: now), "since Fall Break", "past, minute")
check(CountdownPhrasing.caption(for: event(30, .minute), at: now), "until Fall Break", "30s left is not arrived yet")
check(CountdownPhrasing.caption(for: event(0, .minute), at: now), "it's Fall Break!", "arrived at zero, minute")
check(CountdownPhrasing.caption(for: event(-45, .minute), at: now), "it's Fall Break!", "still arrived inside the grace minute")
check(CountdownPhrasing.caption(for: event(-90, .minute), at: now), "since Fall Break", "counting up after the grace minute")
check(CountdownPhrasing.caption(for: event(28*day, .day), at: now), "until Fall Break", "future, day")
check(CountdownPhrasing.caption(for: event(-28*day, .day), at: now), "since Fall Break", "past, day")

print("\n— lock screen compact —")
check(CountdownPhrasing.compact(for: event(3*day + 4*hour, .minute), at: now), "3 Days to Fall Break", "minute compact, days")
check(CountdownPhrasing.compact(for: event(42, .minute), at: now), "45 Sec to Fall Break", "minute compact, seconds")
check(CountdownPhrasing.compact(for: event(28*day, .day), at: now), "28 days to Fall Break", "day compact")

print("\n— decoding a 1.0 payload (no id, no precision) —")
let legacy = #"{"title":"the reunion","date":800000000,"styleID":"midnight","motion":true}"#
if let decoded = try? JSONDecoder().decode(CountdownEvent.self, from: Data(legacy.utf8)) {
    check(decoded.title, "the reunion", "title survives")
    check(decoded.precision.rawValue, "day", "precision defaults to day")
    check(decoded.id.uuidString.isEmpty ? "" : "generated", "generated", "id is generated")
} else {
    failures += 1
    print("FAIL  legacy payload did not decode")
}

print("\n— share links —")
let shared = CountdownEvent(title: "Fall Break", date: now.addingTimeInterval(28*day),
                            styleID: "harvest", precision: .minute)
let link = CountdownShare.link(for: shared)!
check(link.absoluteString.hasPrefix("https://rohanreddybandi.github.io/DuckDays/c/#")
        ? "prefixed" : link.absoluteString, "prefixed", "link shape")
check(link.absoluteString.contains("?") ? "has query" : "fragment only",
      "fragment only", "payload is in the fragment")

if let back = CountdownShare.event(from: link) {
    check(back.title, "Fall Break", "title round-trips")
    check(back.styleID, "harvest", "duck round-trips")
    check(back.precision.rawValue, "minute", "precision round-trips")
    check(abs(back.date.timeIntervalSince(shared.date)) < 1 ? "same" : "drifted",
          "same", "date round-trips")
    check(back.id == shared.id ? "same" : "fresh", "fresh", "gets a new id")
    // The property is that import stamps it, not that it matches the sender.
    check(abs(back.createdAt.timeIntervalSinceNow) < 5 ? "now" : "copied",
          "now", "createdAt is stamped at import")
} else {
    failures += 1; print("FAIL  link did not decode")
}

// An imported countdown whose date has already passed must not earn the reward.
if let old = CountdownShare.event(from:
        CountdownShare.link(for: CountdownEvent(title: "gone by",
            date: now.addingTimeInterval(-10*day), styleID: "classic"))!) {
    check(old.createdAt < old.date ? "would unlock" : "cannot unlock",
          "cannot unlock", "past import cannot farm the reward")
}

check(CountdownShare.event(from: URL(string: "duckdays://add#\(CountdownShare.payload(for: shared))")!)?.title ?? "nil",
      "Fall Break", "app scheme link decodes")
check(CountdownShare.event(from: URL(string: "duckdays://add?d=\(CountdownShare.payload(for: shared))")!)?.title ?? "nil",
      "Fall Break", "query fallback decodes")

let emoji = CountdownEvent(title: "Rohan\u{2019}s trip 🦆", date: now.addingTimeInterval(day))
check(CountdownShare.event(from: CountdownShare.link(for: emoji)!)?.title ?? "nil",
      "Rohan\u{2019}s trip 🦆", "non-ASCII survives base64url")

check(CountdownShare.event(from: "not-a-payload") == nil ? "nil" : "decoded",
      "nil", "garbage rejected")
check(CountdownShare.event(from: URL(string: "duckdays://add")!) == nil ? "nil" : "decoded",
      "nil", "empty link rejected")
let unknownDuck = CountdownShare.payload(for:
    CountdownEvent(title: "x", date: now, styleID: "duck-from-the-future"))
check(CountdownShare.event(from: unknownDuck)?.styleID ?? "nil", "classic",
      "unknown duck falls back")

print("\n— ids written before ids existed —")
// The app and the widget each decode a 1.0 payload. They must agree on its id,
// or a widget configured against it never finds it in the other process.
let legacyA = #"{"title":"the reunion","date":800000000,"styleID":"midnight","motion":true}"#
let first = try! JSONDecoder().decode(CountdownEvent.self, from: Data(legacyA.utf8))
let second = try! JSONDecoder().decode(CountdownEvent.self, from: Data(legacyA.utf8))
check(first.id == second.id ? "same" : "different", "same", "same payload, same id")
let legacyB = #"{"title":"graduation","date":800000000}"#
let other = try! JSONDecoder().decode(CountdownEvent.self, from: Data(legacyB.utf8))
check(first.id != other.id ? "distinct" : "collided", "distinct", "different event, different id")
let stored = #"{"id":"11111111-2222-3333-4444-555555555555","title":"the reunion","date":800000000}"#
let explicit = try! JSONDecoder().decode(CountdownEvent.self, from: Data(stored.utf8))
check(explicit.id.uuidString, "11111111-2222-3333-4444-555555555555", "a stored id always wins")

print("\n— widget schedule stays under the tinted-mode cap —")
func planFor(_ offset: TimeInterval, _ precision: CountdownEvent.Precision, motion: Bool) -> WidgetSchedule.Plan {
    WidgetSchedule.plan(for: CountdownEvent(title: "x", date: now.addingTimeInterval(offset),
                                            motion: motion, precision: precision), now: now)
}
let cases: [(String, WidgetSchedule.Plan)] = [
    ("day, motion", planFor(10*day, .day, motion: true)),
    ("day, still", planFor(10*day, .day, motion: false)),
    ("minute far, motion", planFor(3*day, .minute, motion: true)),
    ("minute far, still", planFor(3*day, .minute, motion: false)),
    ("minute closing 59m, motion", planFor(59*minute, .minute, motion: true)),
    ("minute closing 59m, still", planFor(59*minute, .minute, motion: false)),
    ("minute closing 2m, still", planFor(2*minute, .minute, motion: false)),
]
for (name, plan) in cases {
    check(plan.slots.count <= WidgetSchedule.entryCap ? "under" : "\(plan.slots.count)",
          "under", "\(name): \(plan.slots.count) entries")
    let sorted = zip(plan.slots, plan.slots.dropFirst()).allSatisfy { $0.date < $1.date }
    check(sorted ? "ascending" : "out of order", "ascending", "\(name): dates ascend")
    check(plan.refresh >= plan.slots.first!.date ? "ok" : "refresh before start", "ok",
          "\(name): refresh not in the past")
}
let motionPlan = planFor(10*day, .day, motion: true)
let motionEnd = motionPlan.slots.filter { $0.phase > 0 }.last!.date.timeIntervalSince(now)
check(motionEnd > 30*minute ? "most of an hour" : "\(Int(motionEnd))s", "most of an hour",
      "motion keeps moving past 30 minutes")
check(Set(motionPlan.slots.map(\.phase)).count > 400 ? "distinct" : "repeats", "distinct",
      "motion poses keep changing")
let closing = planFor(2*minute, .minute, motion: false)
let onBoundaries = closing.slots.dropFirst().allSatisfy {
    let off = $0.date.timeIntervalSince(closing.slots.last!.date)
    return abs(off.truncatingRemainder(dividingBy: 5)) < 0.001
}
check(onBoundaries ? "on 5s marks" : "off grid", "on 5s marks", "closing entries land on 5s boundaries")
check(closing.slots.last!.date.timeIntervalSince(now) > 2*minute + 60 ? "past grace" : "stops early",
      "past grace", "closing plan runs through the NOW minute")

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)

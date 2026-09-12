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

print("— minute precision headline —")
check(CountdownPhrasing.headline(for: event(3*day + 4*hour + 37*minute, .minute), at: now), "3 Days 4 Hrs", "3d 4h 37m")
check(CountdownPhrasing.headline(for: event(4*hour + 37*minute, .minute), at: now), "4 Hrs 37 Min", "4h 37m")
check(CountdownPhrasing.headline(for: event(37*minute, .minute), at: now), "37 Min", "37m")
check(CountdownPhrasing.headline(for: event(30, .minute), at: now), "NOW", "30 seconds")
check(CountdownPhrasing.headline(for: event(day + hour + 5, .minute), at: now), "1 Day 1 Hr", "singulars")
check(CountdownPhrasing.headline(for: event(3*day + 30, .minute), at: now), "3 Days", "3d, no hours -> unit dropped")
check(CountdownPhrasing.headline(for: event(-(2*day + 5*hour), .minute), at: now), "2 Days 5 Hrs", "past reads as magnitude")

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
check(CountdownPhrasing.caption(for: event(30, .minute), at: now), "it's Fall Break!", "arrived, minute")
check(CountdownPhrasing.caption(for: event(28*day, .day), at: now), "until Fall Break", "future, day")
check(CountdownPhrasing.caption(for: event(-28*day, .day), at: now), "since Fall Break", "past, day")

print("\n— lock screen compact —")
check(CountdownPhrasing.compact(for: event(3*day + 4*hour, .minute), at: now), "3 Days 4 Hrs to Fall Break", "minute compact")
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

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)

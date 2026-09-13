import Foundation

/// Sharing a countdown as a link.
///
/// The payload rides in the URL **fragment**, never the query. A fragment is
/// not sent to the server, so the title and date of a shared countdown never
/// reach the host serving the landing page. For an app whose privacy policy
/// says it collects nothing, that is the only honest place to put it — a query
/// string would end up in somebody's access log.
///
/// Two shapes of link resolve to the same payload:
///
///     https://rohanreddybandi.github.io/DuckDays/c/#<payload>   shared
///     duckdays://add#<payload>                                  the button on that page
///
/// The first works for anyone: with the app installed iOS offers to open it,
/// and without it the page renders the countdown and points at the App Store.
enum CountdownShare {
    static let scheme = "duckdays"
    static let webPrefix = "https://rohanreddybandi.github.io/DuckDays/c/"

    /// Deliberately one-letter keys. The whole thing ends up in a link someone
    /// pastes into a message, and every character is one more to wrap.
    private struct Wire: Codable {
        var t: String    // title
        var d: Double    // unix epoch seconds
        var s: String    // styleID
        var p: String    // "day" | "min"
    }

    // MARK: out

    static func payload(for event: CountdownEvent) -> String {
        let wire = Wire(t: event.title,
                        d: event.date.timeIntervalSince1970,
                        s: event.styleID,
                        p: event.precision == .minute ? "min" : "day")
        guard let data = try? JSONEncoder().encode(wire) else { return "" }
        return base64url(data)
    }

    static func link(for event: CountdownEvent) -> URL? {
        URL(string: webPrefix + "#" + payload(for: event))
    }

    // MARK: in

    /// Pulls the payload out of either link shape. Falls back to a `d` query
    /// item so a link that lost its fragment somewhere still works.
    static func payload(from url: URL) -> String? {
        if let fragment = url.fragment(percentEncoded: false), !fragment.isEmpty {
            return fragment
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "d" }?.value
    }

    /// Rebuilds a countdown from a payload.
    ///
    /// The result is a **new** countdown, not a copy: a fresh `id` so it cannot
    /// collide with the sender's, and `createdAt` left at now. That last part
    /// matters — importing something whose date has already passed must not
    /// hand over the "you waited for it" reward.
    ///
    /// An unknown `styleID` falls back rather than failing. A link from a later
    /// version carrying a duck this build has never heard of should still add
    /// the countdown.
    static func event(from payload: String) -> CountdownEvent? {
        guard let data = data(fromBase64url: payload),
              let wire = try? JSONDecoder().decode(Wire.self, from: data)
        else { return nil }

        let title = wire.t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, wire.d.isFinite else { return nil }

        let known = DuckStyle.all.contains { $0.id == wire.s }
        return CountdownEvent(title: String(title.prefix(60)),
                              date: Date(timeIntervalSince1970: wire.d),
                              styleID: known ? wire.s : DuckStyle.fallback.id,
                              precision: wire.p == "min" ? .minute : .day)
    }

    static func event(from url: URL) -> CountdownEvent? {
        payload(from: url).flatMap(event(from:))
    }

    // MARK: base64url
    //
    // Plain base64 is not safe in a URL: "+" and "/" are meaningful and "="
    // gets escaped into "%3D" by half the apps that touch a link.

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func data(fromBase64url text: String) -> Data? {
        var padded = text.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }
}

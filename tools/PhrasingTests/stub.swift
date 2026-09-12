// Minimal stand-in so the real Countdown.swift compiles outside the app.
struct DuckStyle {
    let id: String
    static let fallback = DuckStyle(id: "classic")
    static func named(_ id: String) -> DuckStyle { fallback }
}

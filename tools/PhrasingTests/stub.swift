// Minimal stand-in so the real Shared/ sources compile outside the app.
struct DuckStyle {
    let id: String
    static let all = [DuckStyle(id: "classic"), DuckStyle(id: "harvest"),
                      DuckStyle(id: "starlight")]
    static let fallback = all[0]
    static func named(_ id: String) -> DuckStyle { all.first { $0.id == id } ?? fallback }
}

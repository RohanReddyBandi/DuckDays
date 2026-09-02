import SwiftUI
import UIKit

/// A complete look for the countdown: duck sprite, palette, scene colours, and type.
///
/// The sprite grids and colours live in `DuckStyles+Generated.swift`, which is
/// produced by `tools/duck_forge.py`. Edit the forge, not the generated file.
struct DuckStyle: Identifiable, Hashable {
    enum FontChoice: String, Hashable {
        case rounded, serif, monospaced, `default`

        var design: Font.Design {
            switch self {
            case .rounded: return .rounded
            case .serif: return .serif
            case .monospaced: return .monospaced
            case .default: return .default
            }
        }
    }

    let id: String
    let name: String
    let body: UInt32
    let shade: UInt32
    let light: UInt32
    let beak: UInt32
    let beakDark: UInt32
    let cheek: UInt32
    let accent: UInt32
    let accentDark: UInt32
    let bgTop: UInt32
    let bgBottom: UInt32
    let ink: UInt32
    let water: UInt32
    let waterDeep: UInt32
    let font: FontChoice
    let uppercaseCaption: Bool
    /// Night styles get a moon and stars instead of a sun.
    let night: Bool
    let rows: [String]
    let blinkRows: [String]

    static let fallback = all[0]

    static func named(_ id: String) -> DuckStyle {
        all.first { $0.id == id } ?? fallback
    }

    // MARK: colours

    var inkColor: Color { Color(rgb: ink) }
    var waterColor: Color { Color(rgb: water) }
    var waterDeepColor: Color { Color(rgb: waterDeep) }

    var sky: LinearGradient {
        LinearGradient(colors: [Color(rgb: bgTop), Color(rgb: bgBottom)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Maps a material character from a sprite grid to a colour.
    func color(for token: Character) -> UIColor? {
        switch token {
        case "k": return UIColor(rgb: 0x17171A)
        case "w": return UIColor(rgb: 0xFFFFFF)
        case "b": return UIColor(rgb: body)
        case "s": return UIColor(rgb: shade)
        case "h": return UIColor(rgb: light)
        case "r": return UIColor(rgb: beak)
        case "e": return UIColor(rgb: beakDark)
        case "p": return UIColor(rgb: cheek)
        case "a": return UIColor(rgb: accent)
        case "d": return UIColor(rgb: accentDark)
        case "g": return UIColor(rgb: waterDeep)
        default: return nil
        }
    }
}

// MARK: - hex helpers

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - sprite rendering

/// One pixel per point, drawn once per sprite and scaled up at display time.
///
/// Pre-rendered images rather than a `Canvas`: WidgetKit archives a widget's view
/// tree and replays it outside this process, and an image survives that intact.
enum DuckSprite {
    private static let lock = NSLock()
    private static var cache: [String: UIImage] = [:]

    static func image(key: String, grid: [String],
                      color: (Character) -> UIColor?) -> UIImage {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[key] { return hit }

        let width = grid.map(\.count).max() ?? 1
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: CGFloat(width), height: CGFloat(grid.count))

        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            for (row, line) in grid.enumerated() {
                for (column, token) in line.enumerated() {
                    guard let fill = color(token) else { continue }
                    fill.setFill()
                    ctx.fill(CGRect(x: column, y: row, width: 1, height: 1))
                }
            }
        }.withRenderingMode(.alwaysOriginal)

        cache[key] = rendered
        return rendered
    }

    static func duck(_ style: DuckStyle, blinking: Bool = false) -> UIImage {
        image(key: "\(style.id).duck.\(blinking)",
              grid: blinking ? style.blinkRows : style.rows,
              color: style.color(for:))
    }

    static func decor(_ grid: [String], name: String, style: DuckStyle,
                      white: UInt32? = nil) -> UIImage {
        image(key: "\(style.id).\(name)", grid: grid) { token in
            if token == "w", let white { return UIColor(rgb: white) }
            return style.color(for: token)
        }
    }

    /// The waterline, built by repeating the scallop tile so it can be stretched
    /// across any width without the crests going lopsided.
    static func waveStrip(_ style: DuckStyle, tiles: Int) -> UIImage {
        let tile = DuckDecor.wave
        let grid = tile.map { line in String(repeating: line, count: tiles) }
        return image(key: "\(style.id).wave.\(tiles)", grid: grid) { token in
            token == "w" ? UIColor(rgb: style.water) : nil
        }
    }
}

/// Draws the duck at whatever size it is given, preserving its aspect ratio.
/// Nearest-neighbour scaling keeps the pixel edges hard instead of blurring them.
struct PixelDuckView: View {
    let style: DuckStyle
    var blinking: Bool = false

    var body: some View {
        Image(uiImage: DuckSprite.duck(style, blinking: blinking))
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .aspectRatio(contentMode: .fit)
            .accessibilityLabel("Pixel art rubber duck, \(style.name) style")
    }
}

/// Any decor sprite, scaled the same crisp way.
struct PixelDecorView: View {
    let grid: [String]
    let name: String
    let style: DuckStyle
    var white: UInt32? = nil

    var body: some View {
        Image(uiImage: DuckSprite.decor(grid, name: name, style: style, white: white))
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .aspectRatio(contentMode: .fit)
    }
}

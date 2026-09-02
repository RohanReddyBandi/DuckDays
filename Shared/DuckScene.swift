import SwiftUI

/// Where the scenery goes, in fractions of the container.
///
/// Explicit per-size placement rather than a "density" knob: the text sits in a
/// different place in each widget size, and the scenery has to dodge it.
struct ScenePlacement {
    enum CloudKind {
        case small, mid, long

        var grid: [String] {
            switch self {
            case .small: return DuckDecor.cloudSmall
            case .mid: return DuckDecor.cloudMid
            case .long: return DuckDecor.cloudLong
            }
        }

        var name: String {
            switch self {
            case .small: return "cloudSmall"
            case .mid: return "cloudMid"
            case .long: return "cloudLong"
            }
        }
    }

    struct CloudSpot { var x: CGFloat; var y: CGFloat; var kind: CloudKind }
    struct StarSpot { var x: CGFloat; var y: CGFloat; var big: Bool = false }

    var sun: CGPoint
    var clouds: [CloudSpot]
    var stars: [StarSpot]

    /// Small drops the clouds entirely — at 158pt there is not room for the duck,
    /// the counter and weather without everything competing.
    static let small = ScenePlacement(
        sun: CGPoint(x: 0.86, y: 0.53),
        clouds: [],
        stars: [StarSpot(x: 0.09, y: 0.47, big: true),
                StarSpot(x: 0.16, y: 0.62),
                StarSpot(x: 0.93, y: 0.70)])

    static let medium = ScenePlacement(
        sun: CGPoint(x: 0.90, y: 0.20),
        clouds: [CloudSpot(x: 0.11, y: 0.17, kind: .small)],
        stars: [StarSpot(x: 0.07, y: 0.40, big: true),
                StarSpot(x: 0.13, y: 0.52),
                StarSpot(x: 0.055, y: 0.62),
                StarSpot(x: 0.97, y: 0.46)])

    // Clustered, not evenly spread: a tight group upper-left, a loose pair right,
    // and a couple of strays. An even grid of stars reads as a pattern.
    // The counter block runs number → caption → date, and the caption goes
    // nearly edge to edge. So the clouds stay out of that band entirely: one
    // high beside the number, two low flanking the duck.
    static let large = ScenePlacement(
        sun: CGPoint(x: 0.86, y: 0.10),
        clouds: [CloudSpot(x: 0.16, y: 0.09, kind: .long),
                 CloudSpot(x: 0.90, y: 0.52, kind: .small),
                 CloudSpot(x: 0.08, y: 0.62, kind: .small)],
        stars: [StarSpot(x: 0.05, y: 0.20, big: true),
                StarSpot(x: 0.10, y: 0.26),
                StarSpot(x: 0.145, y: 0.185),
                StarSpot(x: 0.955, y: 0.24, big: true),
                StarSpot(x: 0.905, y: 0.30),
                StarSpot(x: 0.045, y: 0.44),
                StarSpot(x: 0.955, y: 0.68),
                StarSpot(x: 0.075, y: 0.76, big: true)])

    /// Used by the style swatches, where there is no text to avoid.
    static let swatch = ScenePlacement(
        sun: CGPoint(x: 0.82, y: 0.20),
        clouds: [CloudSpot(x: 0.22, y: 0.18, kind: .small)],
        stars: [StarSpot(x: 0.10, y: 0.44, big: true),
                StarSpot(x: 0.90, y: 0.50)])
}

/// The pond: sky, weather, waterline, and a duck floating on it.
///
/// Everything is drawn on one shared pixel grid. `unit` is the size of a single
/// sprite pixel in points, and every sprite is a whole number of those, so the
/// 1px outlines all come out the same visual weight — the duck's outline matches
/// the clouds' matches the moon's.
/// What the overlay needs to know about the pond it is sitting on.
struct PondMetrics {
    var unit: CGFloat
    var surface: CGFloat
    var size: CGSize
    /// Height of the water band — the room the overlay must stay out of.
    var waterDepth: CGFloat { max(0, size.height - surface) }
}

struct DuckPond<Overlay: View>: View {
    let style: DuckStyle
    var animated: Bool = false
    /// Where the water starts, as a fraction of height.
    var waterLine: CGFloat = 0.72
    /// Duck width as a fraction of scene width, before snapping to the grid.
    var duckWidth: CGFloat = 0.50
    var duckCenterX: CGFloat = 0.5
    /// How much of the duck sits below the waterline.
    var submersion: CGFloat = 0.12
    var placement: ScenePlacement = .small
    /// Receives the pond's measurements so the caller's type can share the grid
    /// and keep clear of the waterline.
    @ViewBuilder var overlay: (PondMetrics) -> Overlay

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = max(1, (w * duckWidth / CGFloat(DuckStyle.spriteColumns)).rounded())
            let duckW = unit * CGFloat(DuckStyle.spriteColumns)
            let duckH = unit * CGFloat(DuckStyle.spriteRows)
            let surface = (h * waterLine / unit).rounded() * unit

            ZStack {
                style.sky

                sky(w: w, h: h, unit: unit)

                water(w: w, h: h, surface: surface, unit: unit)

                DuckFloating(style: style, animated: animated)
                    .frame(width: duckW, height: duckH)
                    .position(x: w * duckCenterX,
                              y: surface - duckH / 2 + duckH * submersion)

                overlay(PondMetrics(unit: unit, surface: surface,
                                   size: proxy.size))
            }
            .clipped()
        }
    }

    // MARK: sky

    /// Keeps a sprite a whole unit clear of the edges so nothing crops.
    private func clamp(_ centre: CGFloat, size: CGFloat, limit: CGFloat,
                       unit: CGFloat) -> CGFloat {
        min(max(centre, size / 2 + unit), limit - size / 2 - unit)
    }

    @ViewBuilder
    private func sky(w: CGFloat, h: CGFloat, unit: CGFloat) -> some View {
        let sunGrid = style.night ? DuckDecor.moon : DuckDecor.sun
        let sunW = unit * CGFloat(sunGrid[0].count)

        PixelDecorView(grid: sunGrid, name: style.night ? "moon" : "sun", style: style)
            .frame(width: sunW, height: unit * CGFloat(sunGrid.count))
            .position(x: clamp(w * placement.sun.x, size: sunW, limit: w, unit: unit),
                      y: h * placement.sun.y)

        if style.night {
            ForEach(Array(placement.stars.enumerated()), id: \.offset) { _, spot in
                let grid = spot.big ? DuckDecor.starBig : DuckDecor.star
                let size = unit * CGFloat(grid[0].count)
                PixelDecorView(grid: grid, name: spot.big ? "starBig" : "star",
                               style: style)
                    .frame(width: size, height: size)
                    .position(x: clamp(w * spot.x, size: size, limit: w, unit: unit),
                              y: h * spot.y)
            }
        }

        ForEach(Array(placement.clouds.enumerated()), id: \.offset) { index, spot in
            let grid = spot.kind.grid
            let cw = unit * CGFloat(grid[0].count)
            DriftingCloud(style: style, grid: grid, name: spot.kind.name,
                          animated: animated, delay: Double(index) * 1.7, unit: unit)
                .frame(width: cw, height: unit * CGFloat(grid.count))
                .position(x: clamp(w * spot.x, size: cw, limit: w, unit: unit),
                          y: h * spot.y)
        }
    }

    // MARK: water

    @ViewBuilder
    private func water(w: CGFloat, h: CGFloat, surface: CGFloat,
                       unit: CGFloat) -> some View {
        let depth = max(0, h - surface)
        let tiles = max(4, Int((w / unit / 8).rounded()))

        LinearGradient(colors: [style.waterColor, style.waterDeepColor],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: depth)
            .position(x: w / 2, y: surface + depth / 2)

        Image(uiImage: DuckSprite.waveStrip(style, tiles: tiles))
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .frame(width: unit * CGFloat(tiles * 8), height: unit * 3)
            .position(x: w / 2, y: surface - unit * 3 / 2 + unit)

        Ripples(style: style, animated: animated, unit: unit)
            .frame(width: w, height: depth)
            .position(x: w / 2, y: surface + depth / 2)
    }
}

extension DuckPond where Overlay == EmptyView {
    init(style: DuckStyle, animated: Bool = false, waterLine: CGFloat = 0.72,
         duckWidth: CGFloat = 0.50, duckCenterX: CGFloat = 0.5,
         submersion: CGFloat = 0.12, placement: ScenePlacement = .small) {
        self.init(style: style, animated: animated, waterLine: waterLine,
                  duckWidth: duckWidth, duckCenterX: duckCenterX,
                  submersion: submersion, placement: placement) { _ in EmptyView() }
    }
}

// MARK: - moving parts
//
// WidgetKit archives a widget's view tree and replays it out of process, so none
// of this runs there. The animated variants are only ever built by the app.

struct DuckFloating: View {
    let style: DuckStyle
    let animated: Bool

    var body: some View {
        if animated {
            AnimatedDuck(style: style)
        } else {
            PixelDuckView(style: style)
        }
    }
}

private struct AnimatedDuck: View {
    let style: DuckStyle
    @State private var bobbing = false
    @State private var blinking = false

    private let blinkTimer = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()

    var body: some View {
        PixelDuckView(style: style, blinking: blinking)
            .rotationEffect(.degrees(bobbing ? 1.6 : -1.6))
            .offset(y: bobbing ? -3 : 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                    bobbing = true
                }
            }
            .onReceive(blinkTimer) { _ in
                blinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { blinking = false }
            }
    }
}

private struct DriftingCloud: View {
    let style: DuckStyle
    let grid: [String]
    let name: String
    let animated: Bool
    let delay: Double
    let unit: CGFloat
    @State private var drifted = false

    var body: some View {
        PixelDecorView(grid: grid, name: name, style: style)
            // Drift in whole pixels, so the cloud never lands off the grid.
            .offset(x: animated && drifted ? unit * 2 : -unit * 2)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 9).delay(delay)
                    .repeatForever(autoreverses: true)) {
                    drifted = true
                }
            }
    }
}

/// Deliberate ripples: two dash lengths on a fixed rhythm, every row offset from
/// the one above, all snapped to the pixel grid.
private struct Ripples: View {
    let style: DuckStyle
    let animated: Bool
    let unit: CGFloat
    @State private var shimmer = false

    /// (column, length) in pixel units, cycled per row. Two dashes a row, not
    /// three: any denser and the water reads as a repeating texture rather than
    /// as a few deliberate ripples.
    private static let pattern: [[(x: CGFloat, len: CGFloat)]] = [
        [(4, 5), (21, 3)],
        [(12, 3), (28, 5)],
        [(2, 4), (17, 5)],
    ]
    private static let maxRows = 3

    var body: some View {
        GeometryReader { proxy in
            let cols = proxy.size.width / unit
            let rows = min(Self.maxRows, max(0, Int(proxy.size.height / (unit * 5))))
            ForEach(0..<rows, id: \.self) { row in
                let dashes = Self.pattern[row % Self.pattern.count]
                ForEach(Array(dashes.enumerated()), id: \.offset) { _, dash in
                    if dash.x + dash.len < cols {
                        Rectangle()
                            .fill(Color.white.opacity(shimmer ? 0.26 : 0.16))
                            .frame(width: unit * dash.len, height: unit)
                            .position(x: unit * (dash.x + dash.len / 2),
                                      y: unit * (CGFloat(row) * 5 + 2))
                    }
                }
            }
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

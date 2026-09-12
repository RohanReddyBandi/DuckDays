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

    /// Medium's headline is "12 Days", not "12" — roughly four times the width —
    /// so the counter now owns the whole right half and the sun cannot sit in
    /// the corner it used to. It moves left, above the duck, and the clouds go
    /// the way small's did: there is one good place left and the sun has it.
    static let medium = ScenePlacement(
        sun: CGPoint(x: 0.095, y: 0.17),
        clouds: [],
        stars: [StarSpot(x: 0.515, y: 0.125),
                StarSpot(x: 0.595, y: 0.085, big: true),
                StarSpot(x: 0.86, y: 0.11),
                StarSpot(x: 0.945, y: 0.07),
                StarSpot(x: 0.06, y: 0.57, big: true),
                StarSpot(x: 0.05, y: 0.69)])

    // Same story on large, in the other axis: number → caption → date now runs
    // nearly the full width, so the whole top third is type and the weather sits
    // below it, in the two strips either side of the duck. Sun high right, one
    // cloud low right, mid and small clouds left — a ring around the duck rather
    // than anything competing with the counter.
    //
    // Stars are clustered, not evenly spread — an even grid reads as a pattern
    // rather than a sky. They keep to the outer margins the centred type never
    // reaches, and to the gap under the caption.
    static let large = ScenePlacement(
        sun: CGPoint(x: 0.88, y: 0.545),
        clouds: [CloudSpot(x: 0.14, y: 0.53, kind: .mid),
                 CloudSpot(x: 0.10, y: 0.70, kind: .small),
                 CloudSpot(x: 0.87, y: 0.72, kind: .small)],
        stars: [StarSpot(x: 0.032, y: 0.068, big: true),
                StarSpot(x: 0.072, y: 0.155),
                StarSpot(x: 0.028, y: 0.235),
                StarSpot(x: 0.962, y: 0.078, big: true),
                StarSpot(x: 0.925, y: 0.17),
                StarSpot(x: 0.062, y: 0.355),
                StarSpot(x: 0.945, y: 0.305)])

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
    /// Widget-side motion. Each timeline entry carries a phase, and the pond
    /// poses itself from it; WidgetKit animates the change between entries.
    var phase: Int? = nil
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

                DuckFloating(style: style, animated: animated, phase: phase,
                             unit: unit)
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
                          animated: animated, delay: Double(index) * 1.7,
                          unit: unit, phase: phase, index: index)
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
        // Taken from the sprite rather than hardcoded, so changing the wave's
        // shape in the forge cannot silently squash or stretch it here.
        let tileWidth = CGFloat(DuckDecor.wave[0].count)
        let waveRows = CGFloat(DuckDecor.wave.count)
        let tiles = max(4, Int((w / unit / tileWidth).rounded()))

        LinearGradient(colors: [style.waterColor, style.waterDeepColor],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: depth)
            .position(x: w / 2, y: surface + depth / 2)

        Image(uiImage: DuckSprite.waveStrip(style, tiles: tiles))
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .frame(width: unit * CGFloat(tiles) * tileWidth, height: unit * waveRows)
            // Anchored so the solid bottom row always covers the first unit
            // below the surface, whatever the crests do above it.
            .position(x: w / 2, y: surface - unit * waveRows / 2 + unit)

        Ripples(style: style, animated: animated, unit: unit, phase: phase)
            .frame(width: w, height: depth)
            .position(x: w / 2, y: surface + depth / 2)
    }
}

extension DuckPond where Overlay == EmptyView {
    init(style: DuckStyle, animated: Bool = false, waterLine: CGFloat = 0.72,
         duckWidth: CGFloat = 0.50, duckCenterX: CGFloat = 0.5,
         submersion: CGFloat = 0.12, placement: ScenePlacement = .small,
         phase: Int? = nil) {
        self.init(style: style, animated: animated, waterLine: waterLine,
                  duckWidth: duckWidth, duckCenterX: duckCenterX,
                  submersion: submersion, placement: placement,
                  phase: phase) { _ in EmptyView() }
    }
}

// MARK: - moving parts
//
// Two different mechanisms. In the app, views animate themselves on a timer.
// In the widget they cannot — WidgetKit archives the view tree and replays it
// out of process, with no run loop to drive a repeating animation. What the
// widget gets instead is a `phase` on each timeline entry: the pose is a pure
// function of that number, and WidgetKit animates the change as one entry
// replaces the next.

struct DuckFloating: View {
    let style: DuckStyle
    let animated: Bool
    var phase: Int? = nil
    var unit: CGFloat = 2

    var body: some View {
        if animated {
            AnimatedDuck(style: style, unit: unit)
        } else if let phase {
            PosedDuck(style: style, phase: phase, unit: unit)
        } else {
            PixelDuckView(style: style)
        }
    }
}

/// One frame of the bob, chosen by the timeline entry rather than by a running
/// animation. Nothing here ticks — the movement comes from WidgetKit animating
/// between two entries that happen to pose the duck differently.
private struct PosedDuck: View {
    let style: DuckStyle
    let phase: Int
    let unit: CGFloat

    /// Step size and amplitude are a pair: too fine and a step rounds to the
    /// same pixel and nothing appears to move, too coarse and the duck jumps
    /// between poses instead of travelling between them. At 0.5rad a step there
    /// are ~12 poses to a cycle, which is about the fewest that still reads as
    /// bobbing; with entries 3s apart that puts the cycle near 40 seconds.
    private var t: Double { Double(phase) * 0.5 }

    var body: some View {
        // Travel is measured in sprite pixels, not points. The old amplitudes
        // were a flat 6pt and 3°, which is a third of the duck's height on a
        // small widget and a tenth of it on a large one — so the motion faded
        // out exactly where there was the most room for it. Scaling by `unit`
        // makes the bob the same size relative to the duck at every size.
        //
        // Three axes rather than one, each on its own phase offset so they
        // never peak together: rise and fall, roll, and drift sideways the way
        // something actually floating does.
        PixelDuckView(style: style)
            .rotationEffect(.degrees(sin(t) * 5.5))
            .offset(x: sin(t * 0.7 + 1.9) * unit * 2,
                    y: sin(t + 0.6) * unit * 2.5)
            // Just under the entry interval, so wherever a transition does get
            // drawn the duck is still moving when the next pose arrives.
            .animation(.easeInOut(duration: 2.4), value: phase)
    }
}

private struct AnimatedDuck: View {
    let style: DuckStyle
    let unit: CGFloat
    @State private var bobbing = false
    @State private var blinking = false

    private let blinkTimer = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()

    var body: some View {
        PixelDuckView(style: style, blinking: blinking)
            .rotationEffect(.degrees(bobbing ? 2.6 : -2.6))
            .offset(y: bobbing ? -unit * 1.5 : unit * 1.5)
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
    var phase: Int? = nil
    var index: Int = 0
    @State private var drifted = false

    /// Widget-side drift, posed from the entry's phase.
    private var posed: CGFloat {
        guard let phase else { return 0 }
        // 0.4rad against a 3-unit swing moves the cloud at least a whole pixel
        // per step; below that it rounds to the same position and never budges.
        // Slower than the duck on purpose — weather should lag the character.
        return CGFloat(sin(Double(phase) * 0.4 + Double(index) * 1.3)) * unit * 3
    }

    var body: some View {
        PixelDecorView(grid: grid, name: name, style: style)
            // Drift in whole pixels, so the cloud never lands off the grid.
            .offset(x: phase != nil ? posed
                       : (animated && drifted ? unit * 2 : -unit * 2))
            .animation(.easeInOut(duration: 2.4), value: phase)
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
    var phase: Int? = nil
    @State private var shimmer = false

    /// Widget-side drift. Each row slides on its own phase offset and at its
    /// own rate, so the water shears rather than sliding as one sheet. Still
    /// snapped to whole pixels — a sub-pixel slide rounds to nothing.
    private func drift(row: Int) -> CGFloat {
        guard let phase else { return 0 }
        let t = Double(phase) * 0.35 + Double(row) * 2.1
        return (CGFloat(sin(t)) * 2).rounded() * unit
    }

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
                            .offset(x: drift(row: row))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 2.4), value: phase)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

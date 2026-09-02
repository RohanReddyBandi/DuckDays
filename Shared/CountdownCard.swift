import SwiftUI

/// The full countdown scene, shared by the widget and by the preview inside the app
/// so what you see while picking a style is exactly what lands on the home screen.
///
/// All three sizes are one design: a counter block, then a duck floating on water.
/// The number-to-caption size ratio is held constant across sizes so they read as
/// the same system rearranging itself rather than three separate layouts.
struct CountdownScene: View {
    let event: CountdownEvent
    let referenceDate: Date
    var size: Size = .small
    var animated: Bool = false
    /// Set by the widget from its timeline entry; nil in the app.
    var phase: Int? = nil

    enum Size {
        case small, medium, large

        /// Type sizes as a fraction of the scene's height rather than fixed
        /// points. The artwork already scales with the container, so fixed type
        /// only composes correctly at exactly one render size — it overflowed
        /// the moment the scene was drawn as a hero or a sheet thumbnail.
        /// Number:caption stays 3.3:1 in every size.
        var typeScale: (number: CGFloat, caption: CGFloat, meta: CGFloat) {
            switch self {
            case .small: return (0.209, 0.0633, 0)
            case .medium: return (0.316, 0.0962, 0)
            case .large: return (0.181, 0.0548, 0.0367)
            }
        }

        /// Width of the text column, as a fraction of the scene's width.
        var counterWidth: CGFloat { self == .medium ? 0.497 : 1 }
    }

    private var days: Int { event.daysRemaining(from: referenceDate) }
    private var style: DuckStyle { event.style }

    var body: some View {
        switch size {
        case .small: small
        case .medium: medium
        case .large: large
        }
    }

    private var small: some View {
        DuckPond(style: style, animated: animated, waterLine: 0.80,
                 duckWidth: 0.48, duckCenterX: 0.5, placement: .small, phase: phase) { m in
            VStack(spacing: 0) {
                counter(metrics: m)
                Spacer(minLength: 0)
            }
            .padding(.top, m.unit * 3)
            .padding(.horizontal, m.unit * 2)
        }
    }

    private var medium: some View {
        DuckPond(style: style, animated: animated, waterLine: 0.76,
                 duckWidth: 0.34, duckCenterX: 0.24, placement: .medium, phase: phase) { m in
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                counter(metrics: m)
                    .frame(width: m.size.width * size.counterWidth)
            }
            // Centre the counter in the sky, not in the whole card — otherwise
            // the caption lands right on the waterline.
            .padding(.bottom, m.waterDepth)
            .padding(.trailing, m.unit * 5)
        }
    }

    /// The date is part of the counter block rather than a separate plaque in the
    /// water — one text group at the top, one duck below it, nothing floating.
    private var large: some View {
        DuckPond(style: style, animated: animated, waterLine: 0.80,
                 duckWidth: 0.52, duckCenterX: 0.5, placement: .large, phase: phase) { m in
            VStack(spacing: 0) {
                counter(metrics: m)
                Spacer(minLength: 0)
            }
            .padding(.top, m.unit * 3)
            .padding(.horizontal, m.unit * 2)
        }
    }

    private func counter(metrics m: PondMetrics) -> some View {
        let ratio = size.typeScale
        let h = m.size.height
        let scale = (number: ratio.number * h, caption: ratio.caption * h,
                     meta: ratio.meta * h)
        let text = CountdownPhrasing.caption(for: days, title: event.title)
        return VStack(spacing: 0) {
            Text(CountdownPhrasing.headline(for: days))
                .font(.system(size: days == 0 ? scale.number * 0.7 : scale.number,
                              weight: .heavy,
                              design: style.font.design))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(style.uppercaseCaption ? text.uppercased() : text)
                .font(.system(size: scale.caption, weight: .semibold,
                              design: style.font.design))
                .tracking(style.uppercaseCaption ? 0.6 : 0)
                .minimumScaleFactor(0.55)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if scale.meta > 0 {
                Text(event.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
                    .uppercased())
                    .font(.system(size: scale.meta, weight: .semibold,
                                  design: style.font.design))
                    .tracking(1.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.72)
                    .padding(.top, m.unit * 1.6)
            }
        }
        .foregroundStyle(style.inkColor)
        // A hard 1px offset shadow keeps the type readable over clouds and water
        // without softening the pixel-art look.
        .shadow(color: (style.night ? Color.black : Color.white).opacity(0.45),
                radius: 0, x: 0, y: 1)
    }
}

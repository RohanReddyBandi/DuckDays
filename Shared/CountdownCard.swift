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

    enum Size {
        case small, medium, large

        /// Number, caption, and meta line. Number:caption is 3.3:1 everywhere.
        var type: (number: CGFloat, caption: CGFloat, meta: CGFloat) {
            switch self {
            case .small: return (33, 10.0, 0)
            case .medium: return (50, 15.2, 0)
            case .large: return (64, 19.4, 13)
            }
        }
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
                 duckWidth: 0.48, duckCenterX: 0.5, placement: .small) { m in
            VStack(spacing: 0) {
                counter(unit: m.unit)
                Spacer(minLength: 0)
            }
            .padding(.top, m.unit * 3)
            .padding(.horizontal, m.unit * 2)
        }
    }

    private var medium: some View {
        DuckPond(style: style, animated: animated, waterLine: 0.76,
                 duckWidth: 0.34, duckCenterX: 0.24, placement: .medium) { m in
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                counter(unit: m.unit)
                    .frame(width: 168)
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
                 duckWidth: 0.52, duckCenterX: 0.5, placement: .large) { m in
            VStack(spacing: 0) {
                counter(unit: m.unit)
                Spacer(minLength: 0)
            }
            .padding(.top, m.unit * 3)
            .padding(.horizontal, m.unit * 2)
        }
    }

    private func counter(unit: CGFloat) -> some View {
        let scale = size.type
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
                    .padding(.top, unit * 1.6)
            }
        }
        .foregroundStyle(style.inkColor)
        // A hard 1px offset shadow keeps the type readable over clouds and water
        // without softening the pixel-art look.
        .shadow(color: (style.night ? Color.black : Color.white).opacity(0.45),
                radius: 0, x: 0, y: 1)
    }
}

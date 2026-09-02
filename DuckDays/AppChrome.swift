import SwiftUI
import UIKit

/// Design tokens. Rounded sans for anything a person reads as language;
/// monospaced only for data — numbers, dates, duck names. Retro personality
/// comes from the artwork, not from styling every label like a terminal.
enum Chrome {
    static let ink = Color(white: 0.96)
    static let dim = Color.white.opacity(0.46)
    static let card = Color.white.opacity(0.05)
    static let hairline = Color.white.opacity(0.08)
    static let margin: CGFloat = 20

    static func heading(_ text: String, size: CGFloat = 17) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(ink)
    }

    static func meta(_ text: String, size: CGFloat = 12) -> some View {
        Text(text)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(dim)
    }
}

/// A one-pixel grid, tiled. Deliberately faint — it is texture, and it should
/// sit well below the duck, the number and the controls in the reading order.
struct PixelGrid: View {
    var spacing: Int = 8

    var body: some View {
        Image(uiImage: Self.tile(spacing))
            .resizable(resizingMode: .tile)
            .opacity(0.22)
            .allowsHitTesting(false)
    }

    private static var cache: [Int: UIImage] = [:]

    private static func tile(_ spacing: Int) -> UIImage {
        if let hit = cache[spacing] { return hit }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: spacing, height: spacing), format: format
        ).image { ctx in
            UIColor(white: 1, alpha: 0.045).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: spacing, height: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: spacing))
        }
        cache[spacing] = image
        return image
    }
}

/// Near-black, tinted very slightly by the selected duck's sky and water.
struct PixelField: View {
    let style: DuckStyle

    var body: some View {
        ZStack {
            Color(rgb: 0x0A0B0F)
            LinearGradient(colors: [Color(rgb: style.bgTop).opacity(0.13),
                                    Color(rgb: style.water).opacity(0.05),
                                    .clear],
                           startPoint: .top, endPoint: .bottom)
            PixelGrid()
        }
        .ignoresSafeArea()
    }
}

/// A duck, its name, and its selected state. The outline is reserved for
/// selection — nothing else on the screen is outlined.
struct DuckCard: View {
    let style: DuckStyle
    let selected: Bool
    var size: CGFloat = 96

    var body: some View {
        VStack(spacing: 8) {
            DuckPond(style: style, waterLine: 0.74, duckWidth: 0.62,
                     placement: .swatch)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .inset(by: 2)
                        .strokeBorder(selected ? Color(rgb: style.accent) : .clear,
                                      lineWidth: 3)
                )
                .scaleEffect(selected ? 1 : 0.96)
                .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)

            Text(style.name)
                .font(.system(size: 11, weight: selected ? .bold : .medium,
                              design: .monospaced))
                .foregroundStyle(selected ? Chrome.ink : Chrome.dim)
        }
    }
}

/// Filled primary action. The accent belongs here and on the selected duck —
/// not on whole sections of the interface.
struct PrimaryButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color(rgb: 0x0A0B0F))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75),
                       value: configuration.isPressed)
    }
}

/// Compact segmented control, used inside sheets rather than on the main screen.
struct SizePicker: View {
    @Binding var selection: CountdownScene.Size
    let accent: Color

    private let options: [(CountdownScene.Size, String)] = [
        (.small, "Small"), (.medium, "Medium"), (.large, "Large"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { option, label in
                let active = selection == option
                Button { selection = option } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(active ? Color(rgb: 0x0A0B0F) : Chrome.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(active ? accent : Chrome.card))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selection)
    }
}

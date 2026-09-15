import WidgetKit
import SwiftUI
import AppIntents

struct DuckEntry: TimelineEntry {
    let date: Date
    let event: CountdownEvent
    /// Step through the bob. Every entry poses the duck slightly differently.
    var phase: Int = 0
}

struct DuckProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DuckEntry {
        DuckEntry(date: Date(), event: .placeholder)
    }

    func snapshot(for configuration: SelectCountdownIntent,
                  in context: Context) async -> DuckEntry {
        DuckEntry(date: Date(),
                  event: CountdownStore.event(id: configuration.chosenID))
    }

    /// The schedule lives in `WidgetSchedule` (Shared/Countdown.swift), where it
    /// is capped and tested. Stepping through entries the provider already
    /// supplied does not spend the reload budget — only calling this again does.
    func timeline(for configuration: SelectCountdownIntent,
                  in context: Context) async -> Timeline<DuckEntry> {
        let event = CountdownStore.event(id: configuration.chosenID)
        let plan = WidgetSchedule.plan(for: event, now: Date())
        let entries = plan.slots.map {
            DuckEntry(date: $0.date, event: event, phase: $0.phase)
        }
        return Timeline(entries: entries, policy: .after(plan.refresh))
    }
}

struct DuckWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: DuckEntry

    private var style: DuckStyle { entry.event.style }

    /// One number for the circular lock screen widget. A minute countdown that
    /// is still days out shows days; inside a day it switches to hours, because
    /// "0" would be wrong all day and "1440" is not a number anyone reads.
    private var circularValue: String {
        guard entry.event.precision == .minute else {
            return "\(abs(entry.event.daysRemaining(from: entry.date)))"
        }
        let parts = entry.event.remaining(from: entry.date)
        if parts.days > 0 { return "\(parts.days)d" }
        if parts.hours > 0 { return "\(parts.hours)h" }
        if parts.minutes > 0 { return "\(parts.minutes)m" }
        if parts.seconds > 0 { return "\(parts.seconds)s" }
        return "now"
    }

    /// The only chrome: one hairline of the same near-black the sprites are
    /// outlined with, so the widget edge reads as part of the pixel art.
    ///
    /// Both the border and the sky are dropped on a tinted or clear home
    /// screen. The sky is an opaque rectangle, and an opaque rectangle is
    /// exactly what those modes turn into a solid slab of tint; the border
    /// would then be a bright ring drawn around it. Handing back `Color.clear`
    /// lets the wallpaper through, which is what the mode is for.
    private func framed<V: View>(_ content: V) -> some View {
        content
            .overlay {
                if renderingMode == .fullColor {
                    ContainerRelativeShape()
                        .strokeBorder(Color(rgb: 0x17171A).opacity(0.85), lineWidth: 2)
                }
            }
            // The Edit Widget sheet does NOT take its colours from here — it
            // reads WidgetBackground and AccentColor from this target's asset
            // catalog. See Assets.xcassets in DuckWidget/.
            .containerBackground(for: .widget) {
                if renderingMode == .fullColor { style.sky } else { Color.clear }
            }
    }

    var body: some View {
        switch family {
        case .systemLarge:
            framed(CountdownScene(event: entry.event, referenceDate: entry.date,
                                  size: .large, phase: entry.phase))

        case .systemMedium:
            framed(CountdownScene(event: entry.event, referenceDate: entry.date,
                                  size: .medium, phase: entry.phase))

        case .accessoryRectangular:
            HStack(spacing: 6) {
                PixelDuckView(style: style).frame(width: 26)
                Text(CountdownPhrasing.compact(for: entry.event, at: entry.date))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(2)
            }
            .containerBackground(for: .widget) { Color.clear }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                // No room for a unit or a direction here, so show magnitude
                // only — days, or hours once a minute countdown is inside a day.
                Text(circularValue)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
            .containerBackground(for: .widget) { Color.clear }

        default:
            framed(CountdownScene(event: entry.event, referenceDate: entry.date,
                                  size: .small, phase: entry.phase))
        }
    }
}

struct DuckWidget: Widget {
    let kind = "DuckWidget"

    /// Configurable rather than static, so two widgets on one home screen can
    /// count down to different things. Long-press a widget and Edit to choose.
    ///
    /// Switching a shipped widget from `StaticConfiguration` to this resets any
    /// widget already on a home screen to its default countdown — unavoidable,
    /// and the default is the first one in the list rather than a placeholder.
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCountdownIntent.self,
                               provider: DuckProvider()) { entry in
            DuckWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Duck Countdown")
        .description("A little duck counting the days until your thing.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemLarge) {
    DuckWidget()
} timeline: {
    DuckEntry(date: Date(), event: .placeholder)
}

import WidgetKit
import SwiftUI

struct DuckEntry: TimelineEntry {
    let date: Date
    let event: CountdownEvent
    /// Step through the bob. Every entry poses the duck slightly differently.
    var phase: Int = 0
}

struct DuckProvider: TimelineProvider {
    func placeholder(in context: Context) -> DuckEntry {
        DuckEntry(date: Date(), event: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DuckEntry) -> Void) {
        completion(DuckEntry(date: Date(), event: CountdownStore.load()))
    }

    /// Three seconds apart, for an hour. Stepping through entries the provider
    /// already supplied does not spend the reload budget — only calling
    /// `getTimeline` again does — so density is bought with entry count, not
    /// with reloads. Keeping the span at an hour holds the cost at 24 reloads a
    /// day however fine the step gets; only `motionSpan × motionStep` may not
    /// shrink. Entries are a date, a small struct and an Int, so 1200 of them
    /// is a few hundred KB across the archive.
    ///
    /// Measured on the simulator, every one of these renders. A real device
    /// applies power management on top and will coalesce them, so treat this as
    /// the ceiling rather than the guaranteed rate.
    private static let motionStep: TimeInterval = 3
    private static let motionSpan = 1200

    func getTimeline(in context: Context, completion: @escaping (Timeline<DuckEntry>) -> Void) {
        let event = CountdownStore.load()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        var entries: [DuckEntry] = []
        if event.motion {
            for step in 0..<Self.motionSpan {
                entries.append(DuckEntry(
                    date: now.addingTimeInterval(Double(step) * Self.motionStep),
                    event: event, phase: step))
            }
        } else {
            entries.append(DuckEntry(date: now, event: event))
        }

        // One entry per midnight for the next week, so the number ticks over on
        // its own even if the system is slow to refresh the timeline.
        let lastMoving = entries.last?.date ?? now
        for offset in 1...7 {
            guard let midnight = calendar.date(byAdding: .day, value: offset, to: today),
                  midnight > lastMoving else { continue }
            entries.append(DuckEntry(date: midnight, event: event))
        }

        let refresh = event.motion
            ? lastMoving
            : (calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(3600))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct DuckWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: DuckEntry

    private var style: DuckStyle { entry.event.style }

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
                Text(CountdownPhrasing.compact(for: entry.event.daysRemaining(from: entry.date),
                                               title: entry.event.title))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(2)
            }
            .containerBackground(for: .widget) { Color.clear }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                // No room for "days since" here, so show magnitude only.
                Text("\(abs(entry.event.daysRemaining(from: entry.date)))")
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

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DuckProvider()) { entry in
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

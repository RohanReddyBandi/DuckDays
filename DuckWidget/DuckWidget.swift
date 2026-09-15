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
                  event: CountdownStore.event(id: configuration.countdown?.id))
    }

    /// A second and a half apart, for an hour. Stepping through entries the provider
    /// already supplied does not spend the reload budget — only calling
    /// `getTimeline` again does — so density is bought with entry count, not
    /// with reloads. Keeping the span at an hour holds the cost at 24 reloads a
    /// day however fine the step gets; only `motionSpan × motionStep` may not
    /// shrink. Entries are a date, a small struct and an Int, so 2400 of them
    /// is a few hundred KB across the archive.
    ///
    /// Measured on the simulator, every one of these renders. A real device
    /// applies power management on top and will coalesce them, so treat this as
    /// the ceiling rather than the guaranteed rate.
    private static let motionStep: TimeInterval = 1.5
    private static let motionSpan = 2400

    /// Minute precision without motion still needs an entry a minute, or the
    /// number sits there stale. An hour of them costs the same one reload as
    /// the motion timeline does.
    private static let minuteStep: TimeInterval = 60
    private static let minuteSpan = 60

    /// Inside the last hour the headline is counting seconds, in the 5-second
    /// steps `CountdownEvent.remaining` rounds to. Entries go exactly on those
    /// boundaries — the instants the readout changes — rather than on a fixed
    /// tick from whenever the timeline happened to be built, which put every
    /// change up to a tick late.
    private static let closingWindow: TimeInterval = 3600

    func timeline(for configuration: SelectCountdownIntent,
                  in context: Context) async -> Timeline<DuckEntry> {
        let event = CountdownStore.event(id: configuration.countdown?.id)
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Every entry carries its own date and the scene reads the countdown
        // from that, so entry density buys text freshness and duck motion at
        // the same time. Motion is the denser of the two, so it wins when both
        // are on rather than the two being added together.
        let untilTarget = event.date.timeIntervalSince(now)
        let closingIn = event.precision == .minute
            && untilTarget > 0 && untilTarget < Self.closingWindow

        var entries: [DuckEntry] = []
        if event.motion {
            for step in 0..<Self.motionSpan {
                entries.append(DuckEntry(
                    date: now.addingTimeInterval(Double(step) * Self.motionStep),
                    event: event, phase: step))
            }
            // Motion entries tick from whenever the timeline was built, so a
            // 5-second change could land up to a tick late. In the last hour,
            // add an entry on each boundary as well, carrying the phase of the
            // motion entry it falls beside so the duck does not jump.
            if closingIn {
                let step = CountdownEvent.displayStep
                let before = Int((untilTarget / step).rounded(.up))
                let after = Int((CountdownEvent.arrivalGrace + 30) / step)
                for k in stride(from: before, through: -after, by: -1) {
                    let boundary = event.date.addingTimeInterval(-Double(k) * step)
                    guard boundary > now else { continue }
                    let phase = Int(boundary.timeIntervalSince(now) / Self.motionStep)
                    guard phase < Self.motionSpan else { continue }
                    entries.append(DuckEntry(date: boundary, event: event, phase: phase))
                }
                entries.sort { $0.date < $1.date }
            }
        } else if closingIn {
            // One entry now, then one at each 5-second boundary before the
            // moment, then on through the minute "NOW" holds and a little
            // past it, so counting up starts on time too.
            entries.append(DuckEntry(date: now, event: event))
            let step = CountdownEvent.displayStep
            let before = Int((untilTarget / step).rounded(.up))
            let after = Int((CountdownEvent.arrivalGrace + 30) / step)
            for k in stride(from: before, through: -after, by: -1) {
                let boundary = event.date.addingTimeInterval(-Double(k) * step)
                if boundary > now {
                    entries.append(DuckEntry(date: boundary, event: event))
                }
            }
        } else if event.precision == .minute {
            for step in 0..<Self.minuteSpan {
                entries.append(DuckEntry(
                    date: now.addingTimeInterval(Double(step) * Self.minuteStep),
                    event: event))
            }
        } else {
            entries.append(DuckEntry(date: now, event: event))
        }

        // One entry per midnight for the next week, so the number ticks over on
        // its own even if the system is slow to refresh the timeline. Only day
        // precision needs these; a minute countdown is already reloading hourly.
        let lastScheduled = entries.last?.date ?? now
        if event.precision == .day {
            for offset in 1...7 {
                guard let midnight = calendar.date(byAdding: .day, value: offset, to: today),
                      midnight > lastScheduled else { continue }
                entries.append(DuckEntry(date: midnight, event: event))
            }
        }

        let refresh: Date
        if event.motion || event.precision == .minute || closingIn {
            refresh = lastScheduled
        } else {
            refresh = calendar.date(byAdding: .day, value: 1, to: today)
                ?? now.addingTimeInterval(3600)
        }
        return Timeline(entries: entries, policy: .after(refresh))
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

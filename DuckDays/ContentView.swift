import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var events: [CountdownEvent] = [.placeholder]
    @State private var index = 0
    @State private var previewSize: CountdownScene.Size = .small
    @State private var sheet: DuckSheet?
    @State private var justSaved = false
    /// Re-read often enough that a minute countdown ticks over while you watch.
    /// Five seconds, not one: the finest thing on screen is a minute, and the
    /// whole scene re-renders on each tick.
    @State private var now = Date()
    /// Set when a challenge is met, cleared when the card is dismissed.
    @State private var unlocked: DuckChallenge?
    private let clock = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var current: CountdownEvent {
        events.indices.contains(index) ? events[index] : .placeholder
    }

    private var style: DuckStyle { current.style }
    private var accent: Color { Color(rgb: style.accent) }

    /// Edits go through the array so there is one copy of the truth. Writing
    /// back out of range is a no-op rather than a crash — `index` and `events`
    /// are separate pieces of state and a delete can land between them.
    private var currentBinding: Binding<CountdownEvent> {
        Binding(get: { current },
                set: { updated in
                    guard events.indices.contains(index) else { return }
                    events[index] = updated
                })
    }

    private var heroAspect: CGFloat {
        switch previewSize {
        case .small: return 1
        case .medium: return 338.0 / 158.0
        case .large: return 338.0 / 354.0
        }
    }

    /// A page view needs a concrete height, so it is computed from the real
    /// width rather than guessed.
    private func heroHeight(width: CGFloat) -> CGFloat {
        let full = max(1, width - Chrome.margin * 2)
        return previewSize == .small ? min(full, 224) : full / heroAspect
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PixelField(style: style)
                    .animation(.easeInOut(duration: 0.45), value: current.styleID)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        masthead
                        hero(width: proxy.size.width)
                        eventCard
                        duckRow
                        callToAction
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(accent)
        .onAppear {
            load()
            #if DEBUG
            AppIcons.verify()
            #endif
        }
        .onReceive(clock) {
            now = $0
            // A countdown can reach zero while the app is open and on screen.
            checkUnlocks()
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .event:
                EventEditorSheet(event: currentBinding, style: style,
                                 canDelete: events.count > 1,
                                 onDelete: deleteCurrent)
                    .presentationDetents([.large])
            case .widget:
                WidgetSheet(size: $previewSize, event: currentBinding, style: style)
                    // An explicit height rather than .medium: the content is a
                    // known size, and .medium clipped the controls.
                    .presentationDetents([.height(540), .large])
            case .allDucks:
                AllDucksSheet(styleID: currentBinding.styleID, style: style)
                    .presentationDetents([.large])
            }
        }
        .onChange(of: events) { _, _ in
            persist()
            checkUnlocks()
        }
        // An overlay, not a second `.sheet` — two presentations on one view is
        // how you get one of them silently refusing to appear.
        .overlay {
            if let challenge = unlocked {
                UnlockCard(challenge: challenge) {
                    if let style = challenge.style {
                        currentBinding.wrappedValue.styleID = style.id
                    }
                    withAnimation(.easeOut(duration: 0.2)) { unlocked = nil }
                } onDismiss: {
                    withAnimation(.easeOut(duration: 0.2)) { unlocked = nil }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: screen

    private var masthead: some View {
        HStack(spacing: 10) {
            Text("Duck Days")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Chrome.ink)
            Spacer()
            circleButton("plus", action: addCountdown)
            circleButton("slider.horizontal.3") { sheet = .widget }
        }
        .padding(.horizontal, Chrome.margin)
        .padding(.top, 6)
    }

    private func circleButton(_ symbol: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Chrome.dim)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Chrome.card))
        }
        .buttonStyle(.plain)
    }

    /// The countdown is the point of the app, so it gets the room. With more
    /// than one it becomes a pager rather than a list — the hero staying hero
    /// is the whole reason the screen looks like this.
    private func hero(width: CGFloat) -> some View {
        VStack(spacing: 14) {
            TabView(selection: $index) {
                ForEach(Array(events.enumerated()), id: \.element.id) { position, event in
                    Button { sheet = .widget } label: {
                        CountdownScene(event: event, referenceDate: now,
                                       size: previewSize, animated: true)
                            .aspectRatio(heroAspect, contentMode: .fit)
                            .frame(maxWidth: previewSize == .small ? 224 : .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 26,
                                                        style: .continuous))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Chrome.margin)
                    }
                    .buttonStyle(.plain)
                    .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: heroHeight(width: width))

            if events.count > 1 { dots }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: previewSize)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(events.indices, id: \.self) { position in
                Circle()
                    .fill(position == index ? accent : Color.white.opacity(0.24))
                    .frame(width: position == index ? 8 : 6,
                           height: position == index ? 8 : 6)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: index)
    }

    private var eventCard: some View {
        Button { sheet = .event } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(current.title)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(Chrome.ink)
                        .lineLimit(1)
                    Chrome.meta(subtitle)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Chrome.dim)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Chrome.card))
            .padding(.horizontal, Chrome.margin)
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        let when = current.date.formatted(.dateTime.day().month(.abbreviated).year())
        if current.precision == .minute {
            let parts = current.remaining(from: now)
            let head = CountdownPhrasing.minuteHeadline(for: parts).lowercased()
            if head == "now" { return "\(when)  •  now" }
            return "\(when)  •  \(parts.past ? "\(head) ago" : "in \(head)")"
        }
        let days = current.daysRemaining(from: now)
        switch days {
        case 0: return "\(when)  •  today"
        case 1: return "\(when)  •  tomorrow"
        case let d where d > 1: return "\(when)  •  in \(d) days"
        case -1: return "\(when)  •  yesterday"
        default: return "\(when)  •  \(abs(days)) days ago"
        }
    }

    private var duckRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Chrome.heading("Choose your duck")
                Spacer()
                Button("See all") { sheet = .allDucks }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, Chrome.margin)

            ScrollViewReader { scroller in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(DuckStyle.all) { candidate in
                            let locked = DuckUnlocks.isLocked(candidate)
                            Button {
                                guard !locked else { return }
                                currentBinding.wrappedValue.styleID = candidate.id
                            } label: {
                                DuckCard(style: candidate,
                                         selected: candidate.id == current.styleID,
                                         locked: locked)
                            }
                            .buttonStyle(.plain)
                            .id(candidate.id)
                        }
                    }
                    .padding(.horizontal, Chrome.margin)
                    .padding(.vertical, 2)
                }
                // Your duck should be on screen when you open the app, even if
                // it is the twentieth in the row — and again when you swipe to
                // a countdown wearing a different one.
                .onAppear { scroller.scrollTo(current.styleID, anchor: .center) }
                .onChange(of: current.styleID) { _, id in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        scroller.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var callToAction: some View {
        Button {
            persist()
            justSaved = true
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                justSaved = false
            }
            sheet = .widget
        } label: {
            Text(justSaved ? "Duck is ready" : "Add Duck Widget")
                .contentTransition(.identity)
        }
        .buttonStyle(PrimaryButtonStyle(accent: justSaved ? Color(rgb: 0x7CE08A) : accent))
        .padding(.horizontal, Chrome.margin)
        .padding(.top, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: justSaved)
    }

    // MARK: state

    private func load() {
        events = CountdownStore.loadAll()
        index = min(index, max(0, events.count - 1))
        checkUnlocks()
    }

    /// Run on launch and after every edit. `evaluate` banks what it finds and
    /// returns only what was new, so the card cannot appear twice for the same
    /// challenge however often this is called.
    private func checkUnlocks() {
        guard unlocked == nil,
              let fresh = DuckUnlocks.evaluate(events, now: now).first else { return }
        withAnimation(.easeIn(duration: 0.2)) { unlocked = fresh }
    }

    private func addCountdown() {
        let start = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        // A duck it is not already wearing, so a new countdown is tellable
        // apart from the one beside it at a glance.
        let taken = Set(events.map(\.styleID))
        let fresh = DuckStyle.all.first { !taken.contains($0.id) } ?? DuckStyle.fallback
        events.append(CountdownEvent(title: "the big day", date: start,
                                     styleID: fresh.id))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            index = events.count - 1
        }
        sheet = .event
    }

    private func deleteCurrent() {
        guard events.count > 1, events.indices.contains(index) else { return }
        let doomed = index
        // Step the page back before the array shrinks, so the pager is never
        // pointing past the end even for a single layout pass.
        index = max(0, doomed - 1)
        events.remove(at: doomed)
    }

    /// Edits save as they happen, so the button is about adding the widget
    /// rather than about committing a form.
    private func persist() {
        CountdownStore.saveAll(events)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    ContentView()
}

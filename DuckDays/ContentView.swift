import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var styleID: String = DuckStyle.fallback.id
    @State private var previewSize: CountdownScene.Size = .small
    @State private var motion = true
    @State private var sheet: DuckSheet?
    @State private var justSaved = false

    private var draft: CountdownEvent {
        CountdownEvent(title: title.isEmpty ? "the big day" : title,
                       date: date, styleID: styleID, motion: motion)
    }

    private var style: DuckStyle { draft.style }
    private var accent: Color { Color(rgb: style.accent) }

    private var heroAspect: CGFloat {
        switch previewSize {
        case .small: return 1
        case .medium: return 338.0 / 158.0
        case .large: return 338.0 / 354.0
        }
    }

    var body: some View {
        ZStack {
            PixelField(style: style)
                .animation(.easeInOut(duration: 0.45), value: styleID)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    masthead
                    hero
                    eventCard
                    duckRow
                    callToAction
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .tint(accent)
        .onAppear(perform: loadSavedEvent)
        .sheet(item: $sheet) { which in
            switch which {
            case .event:
                EventEditorSheet(title: $title, date: $date, style: style)
                    .presentationDetents([.large])
            case .widget:
                WidgetSheet(size: $previewSize, motion: $motion,
                            event: draft, style: style)
                    // An explicit height rather than .medium: the content is a
                    // known size, and .medium clipped the controls.
                    .presentationDetents([.height(500), .large])
            case .allDucks:
                AllDucksSheet(styleID: $styleID, style: style)
                    .presentationDetents([.large])
            }
        }
        .onChange(of: styleID) { _, _ in persist() }
        .onChange(of: title) { _, _ in persist() }
        .onChange(of: date) { _, _ in persist() }
        .onChange(of: motion) { _, _ in persist() }
    }

    // MARK: screen

    private var masthead: some View {
        HStack {
            Text("Duck Days")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Chrome.ink)
            Spacer()
            Button { sheet = .widget } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Chrome.dim)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Chrome.card))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Chrome.margin)
        .padding(.top, 6)
    }

    /// The countdown is the point of the app, so it gets the room.
    private var hero: some View {
        Button { sheet = .widget } label: {
            CountdownScene(event: draft, referenceDate: Date(),
                           size: previewSize, animated: motion)
                .aspectRatio(heroAspect, contentMode: .fit)
                .frame(maxWidth: previewSize == .small ? 224 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Chrome.margin)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: previewSize)
        .animation(.easeInOut(duration: 0.25), value: styleID)
    }

    private var eventCard: some View {
        Button { sheet = .event } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.title)
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
        let days = draft.daysRemaining()
        let when = date.formatted(.dateTime.day().month(.abbreviated).year())
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
                            Button { styleID = candidate.id } label: {
                                DuckCard(style: candidate,
                                         selected: candidate.id == styleID)
                            }
                            .buttonStyle(.plain)
                            .id(candidate.id)
                        }
                    }
                    .padding(.horizontal, Chrome.margin)
                    .padding(.vertical, 2)
                }
                // Your duck should be on screen when you open the app, even if
                // it is the twentieth in the row.
                .onAppear { scroller.scrollTo(styleID, anchor: .center) }
                .onChange(of: styleID) { _, id in
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
            WidgetCenter.shared.reloadAllTimelines()
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

    private func loadSavedEvent() {
        let saved = CountdownStore.load()
        title = saved.title
        date = saved.date
        styleID = saved.styleID
        motion = saved.motion
    }

    /// Edits save as they happen, so the button is about adding the widget
    /// rather than about committing a form.
    private func persist() {
        CountdownStore.save(draft)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    ContentView()
}

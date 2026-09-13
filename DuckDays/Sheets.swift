import SwiftUI

/// Editing lives in sheets so the main screen can be the finished thing rather
/// than the editor for it.
enum DuckSheet: String, Identifiable {
    case event, widget, allDucks
    var id: String { rawValue }
}

private struct SheetShell<Content: View>: View {
    let title: String
    let style: DuckStyle
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PixelField(style: style)
                ScrollView { content().padding(.top, 8) }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .tint(Color(rgb: style.accent))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct EventEditorSheet: View {
    @Binding var event: CountdownEvent
    let style: DuckStyle
    var canDelete: Bool = false
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var confirmingDelete = false

    var body: some View {
        SheetShell(title: "Event", style: style) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Chrome.meta("WHAT")
                    TextField("", text: $event.title, prompt:
                                Text("the big day").foregroundStyle(.white.opacity(0.22)))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(Chrome.ink)
                        .focused($focused)
                        .submitLabel(.done)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Chrome.meta("WHEN")
                    // The picker gains a time row when the countdown counts to
                    // the minute, because a minute countdown to midnight-by-
                    // default would be wrong for almost every event.
                    DatePicker("", selection: $event.date,
                               displayedComponents: event.precision == .minute
                                   ? [.date, .hourAndMinute] : .date)
                        .datePickerStyle(.graphical)
                        .tint(Color(rgb: style.accent))
                        .padding(.horizontal, -6)

                    Toggle(isOn: Binding(
                        get: { event.precision == .minute },
                        set: { event.precision = $0 ? .minute : .day }
                    )) {
                        Text("Count to the minute")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Chrome.ink)
                    }
                    .tint(Color(rgb: style.accent))
                    .padding(.top, 4)

                    Text(event.precision == .minute
                         ? "Shows hours and minutes as well as days."
                         : "Counts whole days, so tomorrow reads as 1 Day all evening.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Chrome.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Past dates are fine — the countdown just counts the other way.
                Chrome.meta("A date in the past counts up instead of down.", size: 11)

                if let link = CountdownShare.link(for: event) {
                    ShareLink(item: link,
                              subject: Text(event.title),
                              message: Text("Counting down to \(event.title) in Duck Days")) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Share countdown")
                                .font(.system(size: 16, weight: .semibold,
                                              design: .rounded))
                        }
                        .foregroundStyle(Color(rgb: style.accent))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(rgb: style.accent).opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    Text("Sends a link that recreates this countdown — name, date and duck.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Chrome.dim)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -14)
                }

                if canDelete {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Text("Delete countdown")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(rgb: 0xFF6B6B))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(rgb: 0xFF6B6B).opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Delete \(event.title)?", isPresented: $confirmingDelete,
                                        titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            // Dismiss first: the sheet is bound to the event
                            // about to be removed, and letting it re-render
                            // against a deleted index is how you get a blank
                            // flash on the way out.
                            dismiss()
                            onDelete()
                        }
                        Button("Keep it", role: .cancel) {}
                    } message: {
                        Text("Widgets showing it will fall back to your first countdown.")
                    }
                }
            }
            .padding(.horizontal, Chrome.margin)
            .padding(.bottom, 30)
        }
        .onAppear { focused = event.title.isEmpty || event.title == "the big day" }
    }
}

struct WidgetSheet: View {
    @Binding var size: CountdownScene.Size
    @Binding var event: CountdownEvent
    let style: DuckStyle

    static let stageHeight: CGFloat = 200

    private var aspect: CGFloat {
        switch size {
        case .small: return 1
        case .medium: return 338.0 / 158.0
        case .large: return 338.0 / 354.0
        }
    }

    var body: some View {
        SheetShell(title: "Widget", style: style) {
            VStack(spacing: 22) {
                // A fixed-height stage. Without it the large preview is taller
                // than the sheet itself and pushes the size picker off screen —
                // the controls have to stay put whichever size is selected.
                // Always animated, whatever the toggle says. This is the app,
                // and the toggle governs the widget.
                CountdownScene(event: event, referenceDate: Date(),
                               size: size, animated: true)
                    .aspectRatio(aspect, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: Self.stageHeight)
                    .frame(height: Self.stageHeight)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: size)

                VStack(alignment: .leading, spacing: 10) {
                    Chrome.meta("SIZE")
                    SizePicker(selection: $size, accent: Color(rgb: style.accent))
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Named for what it actually governs. Calling it "Duck
                    // motion" while the duck above it keeps bobbing would read
                    // as a broken switch.
                    Toggle(isOn: $event.motion) {
                        Text("Widget motion")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Chrome.ink)
                    }
                    .tint(Color(rgb: style.accent))

                    Text("iOS may slow this down to save energy.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Chrome.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // A push rather than another sheet: SheetShell already owns a
                // navigation stack, and stacking modals to reach a settings
                // choice two levels down is worse than a plain row.
                NavigationLink {
                    AppIconSheet(style: style)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("App icon")
                                .font(.system(size: 16, weight: .semibold,
                                              design: .rounded))
                                .foregroundStyle(Chrome.ink)
                            Chrome.meta(AppIcons.current.name)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Chrome.dim)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Chrome.card))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Chrome.meta("ADDING IT")
                    Text("Long-press your home screen, tap the **+**, search for **Duck Days**, and pick a size.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Chrome.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Chrome.margin)
            .padding(.bottom, 30)
        }
    }
}

/// The home screen icon, one per duck.
///
/// Selection is not a local preference — it is whatever iOS currently has set,
/// so the state is seeded from `AppIcons.current` and only advances once the
/// system has actually accepted the change. Assuming success would leave the
/// grid showing a tick against an icon the home screen is not using.
struct AppIconSheet: View {
    let style: DuckStyle
    @State private var selectedID = AppIcons.current.id

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 16)]

    var body: some View {
        ZStack {
            PixelField(style: style)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(DuckStyle.all) { candidate in
                        // A duck you have not earned should not be wearable on
                        // the home screen either, or the icon picker becomes a
                        // way around the lock.
                        let locked = DuckUnlocks.isLocked(candidate)
                        Button {
                            guard !locked else { return }
                            Task {
                                if await AppIcons.apply(candidate) {
                                    selectedID = candidate.id
                                }
                            }
                        } label: {
                            AppIconCard(style: candidate,
                                        selected: candidate.id == selectedID,
                                        locked: locked)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Chrome.margin)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Deliberately not `DuckCard`: that draws a whole pond, and the icon is the
/// duck on the bare sky gradient. The swatch should show what lands on the
/// home screen, not something close to it.
private struct AppIconCard: View {
    let style: DuckStyle
    let selected: Bool
    var locked: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                style.sky
                PixelDuckView(style: style).padding(13)
            }
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if locked {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(rgb: 0x0A0B0F).opacity(0.82))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .inset(by: 2)
                .strokeBorder(selected && !locked ? Color(rgb: style.accent) : .clear,
                              lineWidth: 3))
            .scaleEffect(selected && !locked ? 1 : 0.96)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)

            Text(locked ? (DuckUnlocks.challenge(for: style)?.hint ?? "Locked")
                        : style.name)
                .font(.system(size: 11, weight: selected && !locked ? .bold : .medium,
                              design: .monospaced))
                .foregroundStyle(locked ? Chrome.dim
                                        : (selected ? Chrome.ink : Chrome.dim))
                .lineLimit(1)
        }
    }
}

struct AllDucksSheet: View {
    @Binding var styleID: String
    let style: DuckStyle

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        SheetShell(title: "\(DuckStyle.all.count) Ducks", style: style) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(DuckStyle.all) { candidate in
                    let locked = DuckUnlocks.isLocked(candidate)
                    Button {
                        guard !locked else { return }
                        styleID = candidate.id
                    } label: {
                        DuckCard(style: candidate,
                                 selected: candidate.id == styleID,
                                 locked: locked)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Chrome.margin)
            .padding(.bottom, 30)
        }
    }
}


/// What appears the first time a challenge is met.
///
/// An overlay rather than a sheet: the screen already owns `.sheet(item:)` for
/// editing, and stacking a second presentation on the same view is how you get
/// one of them silently refusing to appear. It also just suits the moment more
/// — a card landing on top of the app rather than a form sliding up.
struct UnlockCard: View {
    let challenge: DuckChallenge
    var onWear: () -> Void
    var onDismiss: () -> Void

    @State private var landed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            if let style = challenge.style {
                VStack(spacing: 18) {
                    Text("DUCK UNLOCKED")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(Color(rgb: style.accent))

                    DuckPond(style: style, animated: true, waterLine: 0.74,
                             duckWidth: 0.62, placement: .swatch)
                        .frame(width: 148, height: 148)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(spacing: 6) {
                        Text(style.name)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Chrome.ink)
                        Text(challenge.title)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(rgb: style.accent))
                        Text(challenge.blurb)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Chrome.dim)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }

                    VStack(spacing: 10) {
                        Button("Wear it", action: onWear)
                            .buttonStyle(PrimaryButtonStyle(accent: Color(rgb: style.accent)))
                        Button("Maybe later", action: onDismiss)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Chrome.dim)
                    }
                    .padding(.top, 2)
                }
                .padding(26)
                .background(RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(rgb: 0x14161D))
                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)))
                .padding(.horizontal, 32)
                .scaleEffect(landed ? 1 : 0.88)
                .opacity(landed ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                landed = true
            }
        }
    }
}


/// What appears when a shared link opens the app.
///
/// Shows the countdown itself rather than describing it: the same scene the
/// widget draws, so what you are agreeing to add is what you can see. Nothing
/// is written until the button is pressed — a link should never be able to
/// change somebody's data just by being opened.
struct ImportCard: View {
    let event: CountdownEvent
    var onAdd: () -> Void
    var onDismiss: () -> Void

    @State private var landed = false

    private var style: DuckStyle { event.style }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 18) {
                Text("SHARED WITH YOU")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(Color(rgb: style.accent))

                CountdownScene(event: event, referenceDate: Date(),
                               size: .small, animated: true)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 168, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Chrome.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Chrome.meta(event.date.formatted(
                        .dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                }

                VStack(spacing: 10) {
                    Button("Add countdown", action: onAdd)
                        .buttonStyle(PrimaryButtonStyle(accent: Color(rgb: style.accent)))
                    Button("Not now", action: onDismiss)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Chrome.dim)
                }
                .padding(.top, 2)
            }
            .padding(26)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(rgb: 0x14161D))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)))
            .padding(.horizontal, 32)
            .scaleEffect(landed ? 1 : 0.88)
            .opacity(landed ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                landed = true
            }
        }
    }
}

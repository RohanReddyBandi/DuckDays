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
                        Button {
                            Task {
                                if await AppIcons.apply(candidate) {
                                    selectedID = candidate.id
                                }
                            }
                        } label: {
                            AppIconCard(style: candidate,
                                        selected: candidate.id == selectedID)
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

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                style.sky
                PixelDuckView(style: style).padding(13)
            }
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .inset(by: 2)
                .strokeBorder(selected ? Color(rgb: style.accent) : .clear,
                              lineWidth: 3))
            .scaleEffect(selected ? 1 : 0.96)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)

            Text(style.name)
                .font(.system(size: 11, weight: selected ? .bold : .medium,
                              design: .monospaced))
                .foregroundStyle(selected ? Chrome.ink : Chrome.dim)
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
                    Button { styleID = candidate.id } label: {
                        DuckCard(style: candidate,
                                 selected: candidate.id == styleID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Chrome.margin)
            .padding(.bottom, 30)
        }
    }
}

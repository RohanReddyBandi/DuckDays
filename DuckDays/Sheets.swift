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
    @Binding var title: String
    @Binding var date: Date
    let style: DuckStyle
    @FocusState private var focused: Bool

    var body: some View {
        SheetShell(title: "Event", style: style) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Chrome.meta("WHAT")
                    TextField("", text: $title, prompt:
                                Text("the big day").foregroundStyle(.white.opacity(0.22)))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(Chrome.ink)
                        .focused($focused)
                        .submitLabel(.done)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Chrome.meta("WHEN")
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Color(rgb: style.accent))
                        .padding(.horizontal, -6)
                }

                // Past dates are fine — the countdown just counts the other way.
                Chrome.meta("A date in the past counts up instead of down.", size: 11)
            }
            .padding(.horizontal, Chrome.margin)
            .padding(.bottom, 30)
        }
        .onAppear { focused = title.isEmpty }
    }
}

struct WidgetSheet: View {
    @Binding var size: CountdownScene.Size
    @Binding var motion: Bool
    let event: CountdownEvent
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
                CountdownScene(event: event, referenceDate: Date(),
                               size: size, animated: motion)
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
                    Toggle(isOn: $motion) {
                        Text("Duck motion")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Chrome.ink)
                    }
                    .tint(Color(rgb: style.accent))

                    Text("The duck bobs on the home screen, easing to a new pose every few seconds. iOS sets the real pace and will slow it down to save power — a widget cannot animate continuously the way this preview does.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Chrome.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }

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

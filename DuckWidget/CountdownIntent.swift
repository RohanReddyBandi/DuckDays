import AppIntents
import Foundation

// Widget target only. This file used to live in Shared/ and compile into the
// app as well, which registered SelectCountdownIntent and CountdownEntity in
// both bundles' Metadata.appintents. With two registrations the system could
// resolve a widget's chosen countdown against the app's copy while the widget's
// timeline received an intent whose countdown never resolved on its side — nil,
// so every widget fell back to the first countdown whatever it was set to.
// The app never uses these types, so it does not carry them.

/// One countdown, as something the widget's own edit sheet can list.
///
/// A thin projection of `CountdownEvent` rather than the event itself: the
/// entity is what iOS persists inside a widget's configuration, so it should
/// carry identity and a label and nothing that goes stale. Everything else is
/// looked up fresh from the store at render time.
struct CountdownEntity: AppEntity, Identifiable {
    let id: UUID
    let title: String
    let when: String

    init(_ event: CountdownEvent) {
        id = event.id
        title = event.title
        when = event.date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Countdown")
    }

    static var defaultQuery = CountdownQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(when)")
    }
}

struct CountdownQuery: EntityQuery {
    /// Resolving by id, not by index — a widget configured against a countdown
    /// keeps pointing at it after the list is reordered or something above it
    /// is deleted.
    func entities(for identifiers: [UUID]) async throws -> [CountdownEntity] {
        CountdownStore.loadAll()
            .filter { identifiers.contains($0.id) }
            .map(CountdownEntity.init)
    }

    /// What the widget's edit sheet offers.
    func suggestedEntities() async throws -> [CountdownEntity] {
        CountdownStore.loadAll().map(CountdownEntity.init)
    }
}

/// The widget's configuration: which countdown this particular widget shows.
///
/// This is what makes two Duck Days widgets on one home screen able to count
/// down to different things. Every other setting still travels with the event
/// itself, so editing a countdown in the app updates every widget pointed at it.
struct SelectCountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Countdown" }
    static var description: IntentDescription {
        IntentDescription("Pick which countdown this duck is waiting for.")
    }

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?

    init() {}

    init(countdown: CountdownEntity?) {
        self.countdown = countdown
    }
}

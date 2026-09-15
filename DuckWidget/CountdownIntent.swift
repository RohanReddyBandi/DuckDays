import AppIntents
import Foundation

// Widget target only — the app never uses these types.
//
// Why a String and not an AppEntity. This used to be `CountdownEntity`, an
// AppEntity with an EntityQuery. The picker listed the countdowns and iOS saved
// the choice correctly — the serialized intent carried the chosen id — but the
// widget still received `nil` every time and fell back to the first countdown.
// Logged on the simulator, while rebuilding the saved value:
//
//     Converting single entity value … identifier: CountdownEntity, bundleIdentifier: nil
//     Failed to build EntityIdentifier. CountdownEntity is not a registered AppEntity identifier
//     Prepared countdown to CountdownEntity(nil)
//
// iOS looked the entity type up under an unknown bundle before our query was
// ever asked — the query was never called. The build's metadata was correct;
// the failure is in the system's runtime lookup, which this code cannot reach.
//
// A String parameter is converted as a primitive, with no entity registration
// involved, and an options provider still gives the picker a proper title and
// date per countdown. The stored value is the countdown's UUID string.

/// What the widget's edit sheet lists: every countdown, by title and date,
/// with its id as the value that gets saved.
struct CountdownOptions: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        let items = CountdownStore.loadAll().map { event in
            IntentItem(event.id.uuidString,
                       title: "\(event.title)",
                       subtitle: "\(event.date.formatted(.dateTime.day().month(.abbreviated).year()))")
        }
        return IntentItemCollection(sections: [IntentItemSection(items: items)])
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

    /// Named `countdownID`, not `countdown`: a widget configured under the old
    /// entity parameter never resolved anyway, so nothing is lost, and a fresh
    /// name keeps the old serialized value from being decoded as a string.
    @Parameter(title: "Countdown", optionsProvider: CountdownOptions())
    var countdownID: String?

    init() {}

    init(countdownID: String?) {
        self.countdownID = countdownID
    }

    /// The chosen countdown's id, or nil when none is chosen or the stored
    /// string is not a UUID. Resolution falls back to the first countdown.
    var chosenID: UUID? { countdownID.flatMap(UUID.init(uuidString:)) }
}

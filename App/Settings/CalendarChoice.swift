import Foundation
import EventKit

/// Which calendar new events go into. Empty means the system default.
enum CalendarChoice {
    private static let key = "settings.newEventCalendar"

    static var identifier: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// The chosen calendar when it still exists and accepts changes, otherwise the system default.
    static func target(in store: EKEventStore) -> EKCalendar? {
        if let id = identifier, let c = store.calendar(withIdentifier: id), c.allowsContentModifications { return c }
        return store.defaultCalendarForNewEvents
    }

    /// Name shown on the approval card. Falls back to the system default without asking for calendar access.
    static func targetName() -> String {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return String(localized: "Calendar default") }
        let store = EKEventStore()
        return target(in: store).map { CalendarStore.label($0) } ?? String(localized: "Calendar default")
    }

    static func writable(in store: EKEventStore) -> [EKCalendar] {
        store.calendars(for: .event).filter(\.allowsContentModifications)
            .sorted { ($0.source?.title ?? "", $0.title) < ($1.source?.title ?? "", $1.title) }
    }
}

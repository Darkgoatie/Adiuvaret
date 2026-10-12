import EventKit

enum CalendarAccess {
    /// True when the app may read events. Never asks.
    static var granted: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
}

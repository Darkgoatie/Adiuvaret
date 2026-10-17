import Foundation
import Observation
import EventKit
import UserNotifications
import BackgroundTasks
import BriefingKit
import Diagnostics

/// Schedules briefing notifications and keeps them fresh. Each notification carries a fixed text built from counts and times, no model runs in the background.
/// Tapping it opens a chat that reads the calendar and reminders and writes the real briefing.
@MainActor @Observable
final class BriefingHub {
    static let shared = BriefingHub()
    nonisolated static let refreshID = "com.halit.adiuvaretapp.briefing.refresh"

    @ObservationIgnored let store = BriefingStore.standard()
    @ObservationIgnored let attempts = BriefingAttemptLog.standard()
    private(set) var briefings: [Briefing] = []
    private(set) var permission: UNAuthorizationStatus = .notDetermined

    private init() { briefings = store.all() }

    // MARK: Editing

    @discardableResult func save(_ b: Briefing) -> Bool {
        let ok = store.save(b)
        briefings = store.all()
        Task { await reschedule(reason: "edit") }
        return ok
    }

    func delete(_ id: UUID) {
        store.remove(id)
        briefings = store.all()
        Task { await reschedule(reason: "delete") }
    }

    func refreshPermission() async {
        permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await refreshPermission()
        await reschedule(reason: "permission")
    }

    // MARK: Notifications

    /// Replaces every pending briefing notification with a fresh set for the coming days.
    func reschedule(reason: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("briefing.") })
        await refreshPermission()
        guard permission == .authorized || permission == .provisional else { scheduleRefresh(); return }
        let enabled = briefings.filter(\.enabled)
        let days = BriefingSchedule.daysPerBriefing(count: enabled.count)
        let calendar = Calendar.current
        let reminders = await openReminderCount()
        var added = 0
        for b in enabled {
            for fire in BriefingSchedule.fireDates(b, from: Date(), calendar: calendar, days: days) {
                let content = UNMutableNotificationContent()
                content.title = b.title
                content.body = BriefingTemplate.body(for: b, events: events(on: fire, calendar: calendar), openReminders: reminders,
                                                     time: { $0.formatted(date: .omitted, time: .shortened) }, words: Self.words)
                content.sound = .default
                content.threadIdentifier = "briefing.\(b.id.uuidString)"
                content.userInfo = ["briefingID": b.id.uuidString]
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let request = UNNotificationRequest(identifier: BriefingSchedule.requestID(b, fire: fire, calendar: calendar), content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
                do { try await center.add(request); added += 1 } catch { DiagnosticsLog.shared.record("briefing", "add failed: \(type(of: error))") }
            }
        }
        attempts.record(.notificationsRefreshed, "\(reason): \(added) notifications for \(enabled.count) briefings")
        scheduleRefresh()
    }

    private static var words: BriefingTemplate.Words {
        BriefingTemplate.Words(noEvents: String(localized: "Nothing on your calendar today."), oneEvent: String(localized: "1 event today."),
                               manyEvents: String(localized: "%d events today."), firstAt: String(localized: "First at %@."),
                               firstTitled: String(localized: "%@ at %@."), reminders: String(localized: "%d open reminders."),
                               tapToOpen: String(localized: "Tap for your briefing."))
    }

    /// Events of that day, or nil when calendar access was not granted. Nothing is requested here, so a background run never shows a prompt.
    private func events(on day: Date, calendar: Calendar) -> [BriefingEvent]? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let store = EKEventStore()
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .map { BriefingEvent(title: $0.title ?? "", start: $0.startDate, isAllDay: $0.isAllDay) }
    }

    private func openReminderCount() async -> Int? {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return nil }
        let store = EKEventStore()
        return await withCheckedContinuation { cont in
            store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { cont.resume(returning: $0?.count ?? 0) }
        }
    }

    // MARK: Background refresh

    private final class TaskBox: @unchecked Sendable {
        let task: BGTask
        init(_ task: BGTask) { self.task = task }
    }

    /// Must run while the app launches, before it finishes.
    nonisolated static func registerBackground() {
        _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshID, using: nil) { task in
            let box = TaskBox(task)
            Task { @MainActor in await BriefingHub.shared.runBackground(box.task) }
        }
    }

    private func runBackground(_ task: BGTask) async {
        attempts.record(.ran, "background refresh")
        let log = attempts
        task.expirationHandler = { log.record(.expired) }
        await reschedule(reason: "background")
        task.setTaskCompleted(success: true)
    }

    /// Asks iOS for another refresh shortly before the next briefing. iOS decides when, and may not run it at all, so every request and every run is logged.
    func scheduleRefresh() {
        guard briefings.contains(where: \.enabled) else { return }
        let next = briefings.flatMap { BriefingSchedule.fireDates($0, from: Date(), days: 2) }.min()
        let earliest = max((next ?? Date().addingTimeInterval(8 * 3600)).addingTimeInterval(-3600), Date().addingTimeInterval(15 * 60))
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshID)
        request.earliestBeginDate = earliest
        do {
            try BGTaskScheduler.shared.submit(request)
            attempts.record(.scheduled, "earliest \(earliest.formatted(date: .abbreviated, time: .shortened))")
        } catch {
            attempts.record(.scheduled, "failed: \(String(String(describing: error).prefix(80)))")
        }
    }
}

/// Opens a briefing chat when the user taps its notification, also when the app was not running.
final class BriefingNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = BriefingNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo["briefingID"] as? String
        completionHandler()
        guard let raw, let id = UUID(uuidString: raw) else { return }
        Task { @MainActor in LaunchRouter.shared.open(briefing: id) }
    }
}

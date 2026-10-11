import WidgetKit
import SwiftUI
import EventKit

@main
struct AdiuvaretWidgetBundle: WidgetBundle {
    var body: some Widget { NextEventWidget() }
}

struct EventEntry: TimelineEntry {
    let date: Date
    /// Nil when calendar access was not granted to the app.
    let events: [Item]?

    struct Item: Hashable {
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
    }
}

struct EventProvider: TimelineProvider {
    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: Date(), events: [.init(title: "Team standup", start: Date().addingTimeInterval(1800), end: Date().addingTimeInterval(3600), isAllDay: false)])
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let now = Date()
        let first = entry(at: now)
        // One entry per moment the list changes: when an event starts or ends.
        var moments = Set<Date>()
        for e in first.events ?? [] where !e.isAllDay {
            if e.start > now { moments.insert(e.start) }
            if e.end > now { moments.insert(e.end) }
        }
        let entries = [first] + moments.sorted().prefix(12).map { entry(at: $0) }
        let refresh = Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now.addingTimeInterval(7200)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func entry(at date: Date) -> EventEntry {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return EventEntry(date: date, events: nil) }
        let store = EKEventStore()
        let end = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: date)) ?? date.addingTimeInterval(172_800)
        let found = store.events(matching: store.predicateForEvents(withStart: date, end: end, calendars: nil))
            .filter { $0.endDate > date }
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
            .map { EventEntry.Item(title: $0.title ?? "", start: $0.startDate, end: $0.endDate, isAllDay: $0.isAllDay) }
        return EventEntry(date: date, events: Array(found))
    }
}

struct NextEventWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextEvent", provider: EventProvider()) { entry in
            NextEventView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next event")
        .description("Your next calendar event. Tap to ask Adiuvaret.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct NextEventView: View {
    let entry: EventEntry
    @Environment(\.widgetFamily) private var family

    private var openURL: URL { URL(string: "adiuvaret://new")! }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryRectangular: rectangular
            case .systemMedium: list(limit: 3)
            default: list(limit: 1)
            }
        }
        .widgetURL(openURL)
    }

    @ViewBuilder private var inline: some View {
        if let e = entry.events?.first { Text("\(e.title) \(e.isAllDay ? "" : e.start.formatted(date: .omitted, time: .shortened))") }
        else { Text(entry.events == nil ? "Open Adiuvaret" : "No events") }
    }

    @ViewBuilder private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let e = entry.events?.first {
                Text(e.isAllDay ? "All day" : e.start.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                Text(verbatim: e.title).font(.headline).lineLimit(2)
            } else {
                Text(entry.events == nil ? "Open Adiuvaret to allow calendar access" : "No events coming up").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func list(limit: Int) -> some View {
        if let events = entry.events {
            if events.isEmpty {
                Text("Nothing coming up").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(events.prefix(limit)), id: \.self) { e in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.isAllDay ? "All day" : e.start.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(verbatim: e.title).font(limit == 1 ? .headline : .subheadline).lineLimit(limit == 1 ? 3 : 1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            Text("Open Adiuvaret once and allow calendar access to see your events here.").font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

import Foundation

public extension ToolCatalog {
    /// Every tool the app ships. Each id must match a tool name in the app; keep them in step.
    static let standard = ToolCatalog(entries: [
        CatalogEntry(
            id: "readCalendar", title: "Read calendar", category: "Calendar",
            description: "Reads the user's calendar events for a day or a date range, past or future, and can search event titles. Use it to answer what is on, when something is, or what the schedule looks like.",
            keywords: ["calendar", "event", "agenda", "appointment", "meeting", "upcoming", "birthday", "holiday", "week", "tomorrow", "today", "tonight", "weekend", "month", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
            examples: ["What's on my calendar tomorrow?", "Do I have anything next week?", "When is my dentist appointment?", "What meetings did I have last month?"]),
        CatalogEntry(
            id: "findFreeTime", title: "Find free time", category: "Calendar",
            description: "Finds open time slots in the calendar between 08:00 and 20:00, for a given length. Use it when the user asks when they are free or wants to fit something in.",
            keywords: ["free", "available", "availability", "slot", "gap", "opening", "fit"],
            examples: ["Find me an hour free on Friday", "When am I free this week?", "Is there a gap for a 30 minute call?"]),
        CatalogEntry(
            id: "createEvent", title: "Create event", category: "Calendar",
            description: "Adds a new event to the calendar at a given start time and length, after the user approves.",
            keywords: ["add", "book", "schedule", "create", "new", "set"],
            examples: ["Add lunch with Ana tomorrow at 13:00", "Book a haircut on Saturday at 11", "Schedule a call on Monday at 10"]),
        CatalogEntry(
            id: "moveEvent", title: "Move event", category: "Calendar",
            description: "Moves an existing calendar event to a new start time and keeps its length. Needs the event id from a calendar read. The user approves first.",
            keywords: ["move", "reschedule", "postpone", "delay", "shift", "push", "later", "earlier"],
            examples: ["Move my 10:00 meeting to 14:00", "Reschedule the dentist to Friday", "Push lunch back an hour"],
            requires: ["readCalendar"]),
        CatalogEntry(
            id: "deleteEvent", title: "Delete event", category: "Calendar",
            description: "Deletes an existing calendar event. Needs the event id from a calendar read. The user must confirm and it cannot be undone.",
            keywords: ["delete", "cancel", "remove", "drop", "clear"],
            examples: ["Cancel my 3pm meeting", "Delete the dentist appointment", "Remove lunch with Ana from my calendar"],
            requires: ["readCalendar"]),
        CatalogEntry(
            id: "createReminder", title: "Create reminder", category: "Reminders",
            description: "Creates a reminder in the Reminders app that is due after some minutes, after the user approves.",
            keywords: ["remind", "reminder", "remember", "forget", "nudge", "notify"],
            examples: ["Remind me to call mom in 30 minutes", "Don't let me forget to buy milk", "Set a reminder to pay rent"]),
        CatalogEntry(
            id: "listReminders", title: "List reminders", category: "Reminders",
            description: "Lists the user's open reminders and to-dos with their due dates, optionally filtered by words in the title.",
            keywords: ["list", "todo", "task", "pending", "outstanding", "overdue", "checklist"],
            examples: ["What's on my to-do list?", "Show my pending tasks", "Which reminders are overdue?"]),
        CatalogEntry(
            id: "openWebsite", title: "Open website", category: "Web",
            description: "Opens a website or searches the web in the in-app browser, to look something up online, check a price, find news or visit a page. Returns the page's buttons, links and fields.",
            keywords: ["website", "web", "browse", "browser", "online", "internet", "google", "duckduckgo", "wikipedia", "url", "site", "lookup", "price", "news"],
            examples: ["Search the web for the best pizza in Istanbul", "Open apple.com", "Look up the price of AirPods online", "Go to wikipedia and find Real Betis"],
            requires: ["lookAtPage", "actOnPage"]),
        CatalogEntry(
            id: "lookAtPage", title: "Look at page", category: "Web",
            description: "Looks at the open website: lists the numbered buttons, links and fields in view, or reads the page text in parts.",
            keywords: ["page", "article", "content", "summarize", "summary", "webpage", "text"],
            examples: ["What does this page say?", "Summarize the article on the page", "Show me what is on this page", "Read the rest of the page"],
            requires: ["openWebsite", "actOnPage"]),
        CatalogEntry(
            id: "actOnPage", title: "Use page", category: "Web",
            description: "Clicks, types, ticks boxes, chooses options, moves sliders and scrolls on the open website. Never fills passwords, card numbers or codes.",
            keywords: ["click", "tap", "type", "fill", "textbox", "scroll", "button", "link", "checkbox", "dropdown", "slider", "tick"],
            examples: ["Click the first result", "Scroll down the page", "Type red shoes in the search box", "Tick the box and press the button"],
            requires: ["openWebsite", "lookAtPage"]),
    ])
}

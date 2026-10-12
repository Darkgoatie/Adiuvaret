import Foundation

/// The skills that ship with the app. Tool names must exist in the tool catalog; a test checks it.
public enum BuiltinSkills {
    public static let all: [AgentSkill] = [
        AgentSkill(
            id: "weekly-review", name: "Weekly review",
            description: "Summarise the week and the open reminders, then suggest priorities",
            keywords: ["weekly", "review", "recap", "priorities"],
            examples: ["Do my weekly review", "Review my week", "Give me a recap of my week"],
            body: "Read the calendar for the week and list the open reminders. Summarise what happened and what is coming, point out overdue reminders, then suggest three priorities. Use only what the tools returned.",
            allowedTools: ["readCalendar", "listReminders"], source: .builtin),
        AgentSkill(
            id: "plan-my-day", name: "Plan my day",
            description: "Lay out today from the calendar, free time and reminders",
            keywords: ["plan", "agenda", "schedule", "organise", "organize"],
            examples: ["Plan my day", "Help me organise today", "Build me an agenda for today"],
            body: "Read today's calendar and the open reminders, find the free slots, and propose an order for the day that fits the reminders into the free time. Do not add or move anything unless the user asks.",
            allowedTools: ["readCalendar", "findFreeTime", "listReminders"], source: .builtin),
        AgentSkill(
            id: "find-and-add-event", name: "Find and add an event",
            description: "Look up a public event on the web and add it to the calendar",
            keywords: ["fixture", "concert", "match", "public", "event"],
            examples: ["Find the next football fixture and add it to my calendar", "Look up when the concert is and add the event", "Add the next public match to my calendar"],
            body: "Search the web for the date and time of the event, state what you found and where it came from, then create the calendar event. The user approves the event before it is added.",
            allowedTools: ["searchWeb", "createEvent"], source: .builtin),
    ]
}

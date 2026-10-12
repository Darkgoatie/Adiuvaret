import Foundation

public extension ToolCatalog {
    /// Every tool the app ships. Each id must match a tool name in the app; keep them in step.
    static let standard = ToolCatalog(entries: [
        CatalogEntry(
            id: "readCalendar", title: "Read calendar", category: "Calendar",
            description: "Reads the user's calendar events for a day or a date range, past or future, and can search event titles. Use it only for the user's own events, never for dates of public or world events such as sports finals, launches, holidays or conferences. Those need a web search.",
            keywords: ["calendar", "event", "agenda", "appointment", "meeting", "upcoming", "birthday", "week", "tomorrow", "today", "tonight", "weekend", "month", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
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
            id: "searchWeb", title: "Search the web", category: "Web",
            description: "Searches the web and returns result titles, sites and short summaries, to answer questions about news, scores, weather, prices, schedules, opening hours or anything that may have changed. Use it instead of telling the user to look something up.",
            keywords: ["search", "web", "google", "internet", "online", "news", "weather", "forecast", "score", "latest", "price", "lookup", "headline", "wikipedia"],
            examples: ["Search the web for the best pizza in Istanbul", "When is Real Betis' next match?", "What's the weather in Seville?", "Latest news about Apple", "How much are AirPods?", "Who won the match yesterday?"],
            requires: ["openWebsite", "lookAtPage"]),
        CatalogEntry(
            id: "openWebsite", title: "Open website", category: "Web",
            description: "Opens a website the user names, or a search result, in the in-app browser. Returns the page's buttons, links and fields.",
            keywords: ["open", "visit", "website", "site", "url", "browser", "homepage", "address"],
            examples: ["Open apple.com", "Go to the BBC website", "Visit github.com", "Take me to the Apple homepage"],
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
        CatalogEntry(
            id: "searchNotes", title: "Search notes", category: "Notes",
            description: "Searches the user's Obsidian or Markdown notes folder by words and returns note names with short excerpts. Use it when the user asks what their notes say.",
            keywords: ["obsidian", "vault", "notes", "markdown", "jotted", "wrote down"],
            examples: ["Search my Obsidian notes for the Seville trip", "What did I write in my notes about taxes?", "Find the note about the garden project in my vault"]),
        CatalogEntry(
            id: "readNote", title: "Read note", category: "Notes",
            description: "Reads one note from the user's notes folder, in parts when it is long. Needs the note path from a notes search.",
            keywords: ["open note", "read note", "show note", "full note", "contents"],
            examples: ["Read the full Spain trip note", "Show me the whole note about taxes", "Open that note and read it"],
            requires: ["searchNotes"]),
        CatalogEntry(
            id: "writeNote", title: "Write note", category: "Notes",
            description: "Creates a new note, or adds text to the end of an existing note, in the user's notes folder after the user approves.",
            keywords: ["jot", "append", "save a note", "new note", "write a note", "add to note"],
            examples: ["Create a note called Packing list with a passport and charger", "Add a line to my Ideas note about the new app", "Jot down a note that the dentist moved to Friday"],
            requires: ["searchNotes"]),
        CatalogEntry(
            id: "findContact", title: "Find contact", category: "Contacts",
            description: "Looks up a person in the user's contacts and returns their phone numbers, emails and birthday. Read only.",
            keywords: ["contact", "phone number", "email address", "birthday", "number of", "address book"],
            examples: ["What is Ana Ruiz's phone number?", "Look up Bob in my contacts", "When is Maria's birthday?"]),
        CatalogEntry(
            id: "runShortcut", title: "Run shortcut", category: "Shortcuts",
            description: "Runs a shortcut from the user's Shortcuts app by its name after the user approves. The result cannot be read back.",
            keywords: ["shortcut", "shortcuts", "automation", "routine", "run my"],
            examples: ["Run my Morning routine shortcut", "Start the Focus mode shortcut", "Trigger my Log water shortcut"]),
        CatalogEntry(
            id: "draftEmail", title: "Draft email", category: "Email",
            description: "Opens a draft email in the Mail app with the recipient, subject and text filled in. The user reads it and presses send.",
            keywords: ["email", "draft", "compose", "mail", "message to", "write an email"],
            examples: ["Draft an email to ana@example.com about dinner", "Write an email to my landlord saying the heater is broken", "Compose a mail to bob@example.org with the meeting notes"]),
        CatalogEntry(
            id: "listTodoistTasks", title: "List Todoist tasks", category: "Todoist",
            description: "Lists the user's open Todoist tasks with due dates, optionally filtered by words.",
            keywords: ["todoist", "tasks", "task list", "todos", "due today"],
            examples: ["What is on my Todoist today?", "List my Todoist tasks", "Do I have a Todoist task about the bank?"]),
        CatalogEntry(
            id: "addTodoistTask", title: "Add Todoist task", category: "Todoist",
            description: "Adds a task to the user's Todoist inbox, with an optional due date in plain words, after the user approves.",
            keywords: ["todoist", "add task", "new task", "put on todoist", "create task"],
            examples: ["Add buy milk to my Todoist", "Put renew passport on Todoist for next Friday", "Create a Todoist task to call the bank"]),
        CatalogEntry(
            id: "listGitHubIssues", title: "List GitHub work", category: "GitHub",
            description: "Lists open GitHub issues and pull requests, not repositories, that are assigned to the user, created by the user, or waiting for the user's review.",
            keywords: ["github", "pull request", "pull requests", "issues", "code review", "assigned"],
            examples: ["What GitHub issues are assigned to me?", "Which pull requests are waiting for my review?", "List my open GitHub pull requests"]),
        CatalogEntry(
            id: "listGitHubCommits", title: "List GitHub commits", category: "GitHub",
            description: "Lists the newest commits of one of the user's GitHub repositories, with message, author and day.",
            keywords: ["commit", "commits", "latest commits", "commit history", "recent changes", "pushed"],
            examples: ["Show the latest 3 commits on Adiuvaret", "What are the last commits in my Keply repo?", "List recent commits on arztalep"]),
        CatalogEntry(
            id: "listGitHubRepos", title: "List GitHub repositories", category: "GitHub",
            description: "Lists the user's GitHub repositories, most recently pushed first, with visibility, language and last push date.",
            keywords: ["repos", "repositories", "repository", "my projects on github", "github projects"],
            examples: ["What are my current GitHub repos?", "List my repositories", "Which repos did I push to lately?"]),
        CatalogEntry(
            id: "searchPastChats", title: "Search earlier chats", category: "Chats",
            description: "Searches the user's earlier conversations with this assistant and returns the matching messages with the chat name and day.",
            keywords: ["earlier chat", "we talked", "did we discuss", "what did i tell you", "last time we", "our conversation", "you said", "remember when"],
            examples: ["What did we say about the Seville hotel?", "What did I tell you about my trip last week?", "Find our earlier chat about the budget"]),
        CatalogEntry(
            id: "searchNotion", title: "Search Notion", category: "Notion",
            description: "Searches the titles of the user's Notion pages and databases and returns their names and last edit dates.",
            keywords: ["notion", "workspace", "wiki", "page in notion", "notion page"],
            examples: ["Find my roadmap page in Notion", "Search Notion for meeting notes", "Is there a Notion page about onboarding?"]),
        CatalogEntry(
            id: "skill_use", title: "Use a skill", category: "Skills",
            description: "Lists or reads the user's saved skills, which are named sets of steps. Find one by words, then read it and follow it with the other tools.",
            keywords: ["skill", "skills", "playbook"],
            examples: ["Use my weekly review skill", "What skills do you have?", "Run the plan my day skill", "Which saved skills are available?"]),
    ])
}

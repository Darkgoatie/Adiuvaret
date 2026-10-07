# ToolKit

## Responsibility
Pure logic for tool skills, testable without a device: calendar date ranges, search filter, conflict check, free-time slots. Works on `EventSlot` values, never on EventKit objects.

## Not responsible for
Reading or writing EventKit (App/Runtime/CalendarSkills.swift), approvals (PolicyEngine), or what the model says.

## Public interface
- `EventSlot(id, title, start, end, isAllDay, calendar)`
- `CalendarMath.range(startDate:days:now:calendar:)` -> half-open range or nil; days clamped 1...31, empty start = today
- `CalendarMath.dateTime(_:calendar:)` for `yyyy-MM-dd HH:mm` or `T` form
- `CalendarMath.filter(_:query:)`, `conflicts(_:start:end:ignoring:)`, `freeSlots(_:in:workStartHour:workEndHour:minMinutes:now:calendar:)`

## Invariants
- The model never computes dates; code resolves them. Bad input returns nil, never a guess.
- Intervals are half-open: back-to-back events do not conflict.
- All-day events never block time and never conflict.
- Free slots stay inside working hours (default 08:00-20:00), never start before `now`, and skip gaps shorter than `minMinutes`.

## Dependencies
Foundation only.

## Owned files
Packages/ToolKit/

## Test method
`swift test --filter CalendarMathTests` (10 cases, fixed UTC calendar).

## App side (not in this package)
Event handles (`e1`, `e2`) map the model's references to EventKit ids; moveEvent and deleteEvent resolve a handle and refuse read-only calendars. createEvent and moveEvent are reversibleWrite (approval card + Undo); deleteEvent is irreversible (approval always, no Undo).

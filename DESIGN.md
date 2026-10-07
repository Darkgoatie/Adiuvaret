# Design

Direction: plain native iOS (the standard exit from impeccable's direction roll, user-chosen 2026-10-07). Quality bar: ChatGPT iOS app, Apple Reminders, Messages. Concept directions rolled and declined: secretary's desk slips, friendly warm-card consumer surface.

## Principles
- System structure first: NavigationStack, sheets, grouped lists, SF Symbols, system materials. Custom only where the product needs it (the drawer, action and approval cards).
- Green #2AB985 is the single accent and marks things the user can act on. Labels on green fills are dark (white is 2.4:1). Green as text uses the darker accentText token.
- Warm neutral ground: background #FAF7F2 light, #171512 dark; surfaces white and #221F1B.
- Rounded rectangles, never pills. Radii 8, 12, 20. Spacing 4, 8, 12, 16, 24.
- No emoji. Decided states settle into calm 'Added' or 'Undone' states instead of vanishing.

## Typography
Chat title: Archivo Black (title only, above the chat bar). Headings, buttons, captions: Google Sans Flex. Chat text and body: Google Sans. All via Font.custom relativeTo text styles so Dynamic Type scales them. Navigation bar titles stay system. Files and OFL licences: Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts.

## Tokens
Source: Packages/DesignSystem/Sources/DesignSystem/Tokens.swift (values) and Theme.swift (SwiftUI). Every text colour is tested for 4.5:1 in light and dark (ContrastTests).

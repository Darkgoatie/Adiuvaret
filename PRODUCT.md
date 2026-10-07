# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Everyday iPhone owners who manage their day through calendar, reminders, notes and messages, in short moments between other things. They value privacy and control over raw power, and are not developers.

## Product Purpose
Adiuvaret is a private personal assistant that lives on the iPhone. It runs a local model, takes actions on the user's behalf, remembers what matters, and gets more capable as the user teaches it. Success: the user hands off small daily chores and trusts what happens, because every action is visible and approvable.

## Positioning
The model runs on the phone and every action passes through an approval step the user can see. It is also teachable: new skills (for example mail, or access to a university panel) are not built in but learned from the user during use, stored on the device as data the user can inspect, edit and delete.

## Operating Context
Used one-handed, in short sessions, often with a calendar or reminder question. Stage 1 uses Apple Intelligence only (8192-token context on the iPhone 18 Pro, 4096 as design floor), no cloud. Scheduled briefings are notifications first; full AI briefings generate on open.

## Capabilities and Constraints
- Built in: calendar, reminders, contacts, in-app notes and tasks, location and weather, Messages and Mail as drafts only (iOS gives no way to read or silently send them).
- Memory: a general, durable picture of the user (people, preferences, routines, projects), fully viewable, editable and deletable.
- Learnable skills: taught through conversation, stored as declarative data on the device, never downloaded executable code. A skill cannot grant itself permissions; the policy engine still decides every action.
- Undecided: what a skill can reach (mail account access, a university panel, custom web access) and how the user teaches credentials. See docs/decisions/005-learnable-skills.md.
- Local models only in Stage 1; cloud and downloadable models are Phase 3.

## Brand Commitments
- Fonts: Google Sans and Google Sans Flex app-wide, Archivo Black only for the chat title above the chat bar.
- Accent colour: #2AB985 (green), user-confirmed.
- Voice: warm and personal, a character.
- No emoji, no pill buttons.

## Evidence on Hand
Device measurements in docs/VERIFIED_FACTS.md. No user research, no testimonials, no pricing.

## Product Principles
1. Nothing consequential happens without the user seeing it first.
2. What the assistant knows and has learned is always inspectable and removable.
3. Capabilities grow through use, not through a bigger app.
4. Say plainly where data lives.
5. Fast to the answer; no ceremony for small things.

## Accessibility & Inclusion
Dynamic Type through the largest sizes, VoiceOver for every element, 4.5:1 contrast, Reduce Motion respected, 44 pt targets.

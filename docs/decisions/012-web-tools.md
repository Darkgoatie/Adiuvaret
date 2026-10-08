# 012 Web tools: an in-app browser the assistant can drive

Accepted 2026-10-08 on the user's instruction, using Projects/ios-web-agent/WALKTHROUGH.md as the plan.

## What was taken from the walkthrough

  Phase 1  Web view tool layer: one WKWebView, a page script that numbers interactive elements, click, type, choose,
           tick, slider, scroll, read text. Shadow DOM and same-origin frames are searched. Fields are found by number.
  Phase 2  The loop is the existing one (router, tools, session). Each action returns a fresh, capped snapshot.
  Phase 4  Sessions persist with WKWebsiteDataStore.default(). Passwords, card numbers and codes are never typed by the
           assistant: the user signs in from the browser panel. Settings has Clear browsing data.
  Phase 6  Visible action rows in the chat, a per-chat site allow list, page text treated as untrusted, step cap,
           Stop button (existing).

## What was changed or left out, and why

  - Tools are three, not nine: openWebsite, lookAtPage (controls or text), actOnPage (click, type, choose, tick,
    slider, scroll). Apple's model works best with 3 to 5 tools, and the router already adds only what a request needs.
  - Snapshots are capped at about 1,600 characters (about 400 tokens), not 4k tokens, because the window is 8192 tokens.
  - No separate Skills loader and no VaultTool in this pass. Skills are task 40. Face ID autofill (phase 4) is later.
  - No fetch tool and no screenshot tool: Apple's on-device model has no vision input.
  - Remote API and the walkthrough's "start with a remote model" are not used. Decision 003 and 011 still apply: the
    model is Apple's, or a local MLX model. Web tools run on the Apple model only for now.
  - Cross-origin iframes cannot be scripted. The user can use the browser panel.

## Safety rules (code, not prompt)

  - Only https. Local, private, IP-address, .local and custom-port addresses are refused (WebPolicy.normalize).
  - A chat may only open sites it has opened. A link or script that leaves the site is blocked and the user is asked
    in the panel. After the assistant has read any website, opening a different site needs an approval card.
  - Clicks on buttons that could buy, send, delete, sign in or submit need an approval card, and cannot be undone
    (tier irreversible). So does any button or Enter on a page that has a password field.
  - Password, card and one-time-code fields are refused in the page script itself and their values are never read.
  - Page text is labelled untrusted, and the tool result marks the content before the model sees it.
  - The page script runs in its own WKContentWorld, so page code cannot call or change it.
  - JavaScript alerts, confirms and prompts are answered with nothing. Pop-ups open in the same view and pass the same check.
  - Kill switch applies to every web tool. 15 tool calls per message.

## Verification so far

  - 16 Swift tests for the address rules, click rules, field rules and snapshot formatting (VM).
  - 35 checks of the page script against a real DOM in jsdom (Windows, node).
  - Compiles on the iOS 26.5 simulator SDK.
  - NOT verified: anything in a real WKWebView, the Apple model choosing and using these tools, real sites, sign-in
    flows, timing. These need the phone.

## Open

  - Whether the 3B-class Apple model can complete multi-step tasks with these tools inside 8192 tokens.
  - Search engine choice: the tool text points at DuckDuckGo; Google blocks unusual web views more often.
  - Face ID autofill, a domain list the user can edit, and web tools on MLX models.

# Decision 014: Built-in information sources

Status: accepted, 2026-10-11. Requested by the user.

## Why

Every new web question used to start a search and read pages, which is slow and often wrong for facts that have a proper data service (a league table, a price, the weather). Questions with a known shape now go straight to a built-in source. The web search stays as the fallback.

## Rules

- Only sources that answered a real request without an account or key when they were added. They were checked on 2026-10-11.
- Each category has an ordered list. The user picks the first one in Settings, Preferences. If it fails or has no answer, the next one in the same category is tried, then the web search.
- A request may only go to the host of the source it belongs to (`InfoSources.isAllowed`). Redirect targets are not followed to other hosts by the app's own checks.
- What leaves the phone is shown under each source: place coordinates, a ticker, a topic. Never the chat, memory, calendar or reminders. Query words pass through the existing scrubber first.
- Text from a source is untrusted data. News text is marked as such so a headline cannot give the model instructions.
- Preferences are stored in UserDefaults on the phone.

## Sources

Weather: Open-Meteo (default), MET Norway.
Football: ESPN (tables, scores, 10 leagues and the 3 European cups), TheSportsDB (fixtures and team lookups; its free tier lists only 5 table rows).
Other sports: ESPN scoreboards for the NBA, NFL, NHL and MLB. Formula 1, tennis and MMA scoreboards use a different shape and are not built.
News: BBC, The Guardian, NPR (general headlines), Google News (any topic).
Exchange rates: Frankfurter (ECB), ExchangeRate-API.
Crypto: Coinbase, CoinGecko.
Stocks and indices: Yahoo Finance (unofficial; can change without notice).
Facts: Wikipedia, DuckDuckGo instant answers.
Public holidays: Nager.Date.

## Considered and left out

- Stooq: answered 404 on the checks.
- GDELT: answered once, then returned non-JSON error pages.
- NASA APOD with the demo key: returned 500.
- Free Dictionary API: returned 522.
- Any source that needs a key (NewsAPI, Alpha Vantage, football-data.org, OpenWeather): a key in a public repo or in the app would be misused. They can return as optional keys in Settings later.

## Limits

- ESPN and Yahoo are not official public APIs. They have worked without a key for years, but may change. The fallback order exists for this reason.
- Formula 1, tennis and MMA are not built. Jolpica F1 answered the checks and can be added later.

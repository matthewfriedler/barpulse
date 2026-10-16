# BarPulse

A live bar capacity and wait-time tracker for the Marina and Cow Hollow
neighborhoods in San Francisco. Glance at a map and instantly see which bars
have no wait, which are filling up, and which have a line out the door — plus
a feel for each bar's vibe before you go.

> Rebuilt from the original Lovable-generated version (`bar-pulse-sf`). The
> frontend is now a static, dependency-free web app. The Supabase database is
> unchanged; its schema lives in `supabase/migrations/`.

## What it does

**Map and list**
- Interactive map of the Marina / Cow Hollow (Leaflet + CARTO/OpenStreetMap
  tiles, no API key), one pin per bar.
- A side list of all bars that stays in sync with the map.
- Compact, mobile-friendly filters: neighborhood (Marina / Cow Hollow), vibe,
  and current status. Filtering updates both the map and the list.
- Each bar shows whether it's open or closed right now, from the opening hours
  stored in the database.
- Light / dark mode toggle that remembers your choice.

**Status colours** (pins and cards use the same colours)
| Status | Capacity | Wait |
|---|---|---|
| Green | under 50% | no wait |
| Yellow | 50–85% | short wait |
| Red | 85%+ | line out the door |

**Live, verified updates**
- Sign up / sign in (Supabase auth); your session survives a page reload.
- To post an update you must be signed in **and** within about 300 m of that
  bar, checked with your phone's GPS. Too far away, or location denied → the
  app blocks it and explains why in plain language.
- The database enforces the same 300 m rule and a per-user rate limit, so the
  rules can't be bypassed by calling the API directly.
- The update form: capacity (slider), wait time (minutes), an optional quick
  vibe note from a preset list.
- Every bar shows who posted last and how long ago ("@username, 4 min ago" or
  "Staff update, 4 min ago") and flags stale reports (no update in 45+ min).
- Updates appear for everyone in real time (or on a short refresh), not just
  the person who posted.

## The bars (15, real SF bars)
**Marina:** Horseshoe Tavern, Bar Darling, The Tipsy Pig, Delarosa, The Dorian,
Rendezvous, Sully's Marina Lounge, Monaghan's Bar, The Patio
**Cow Hollow:** Balboa Cafe, The Brixton, Black Horse London Pub,
West Coast Wine & Cheese, Palm House, Wilder

Vibe tags: dive bar, cocktail lounge, sports bar, neighborhood pub, wine bar,
late night, tiki/tropical.

## Design direction
Light and lively, not a dark "tactical" dashboard. An energetic SF feel:
Golden Gate coral/orange as the primary colour, bay-water teal as the
secondary, soft off-white backgrounds, rounded cards, a bold display font for
headings. Mobile-first — it gets used on a phone standing outside a bar: big
tap targets, no horizontal scroll, no text overflow. Both light and dark
themes are contrast-checked.

## Stack
- Plain HTML, CSS and vanilla JavaScript. **Zero npm dependencies** — no
  `package.json`, no `node_modules`, no build step.
- Leaflet and `@supabase/supabase-js` are loaded from a CDN.
- Supabase URL and publishable key live in the committed `config.js`. This is
  intentional: the publishable key is designed to be public, and Row Level
  Security controls what it can do.
- Vercel serves the files directly, deployed from this GitHub repo.

## Run it locally
No install needed. Serve the folder with any static file server, for example:

```sh
python3 -m http.server 3000
```

then open http://localhost:3000.

## Deploy
Vercel is connected to this GitHub repository. Every push to `main` deploys
automatically; pull requests get preview URLs.

## Database
Supabase schema and history: `supabase/migrations/`. Tables: `bars`,
`bar_updates`, `bar_checkins`, `bar_baselines`, `bar_place_cache`,
`bar_reading_confirmations`, `bar_staff`, `profiles`, `user_roles`.

Note: the seeded opening hours are **placeholders** (see
`20261005000000_opening_hours_without_google.sql`) and should be checked
against each bar before relying on them.

# CLAUDE.md — BarPulse

Live bar capacity / wait-time tracker for SF's Marina and Cow Hollow. Owner:
Matthew Friedler (non-technical — explain changes in plain language). These
decisions are settled. **Do not propose a framework, bundler or npm package.**

## Stack rules (hard requirements)
- **Zero npm dependencies.** No `package.json`, no `node_modules`, no build step.
  If something seems to need a dependency, stop and ask Matthew first.
- Plain HTML, CSS and vanilla JavaScript. Vercel serves the files as-is.
- Leaflet and `@supabase/supabase-js` load from a CDN via `<script>` tags in
  `index.html`, **pinned to exact versions with `integrity` (SRI) hashes**:
  - Leaflet `1.9.4` (unpkg) — JS + CSS
  - supabase-js `2.117.2` (jsdelivr, `dist/umd/supabase.js`)
  To upgrade: change the version in the URL **and** recompute the hash
  (`openssl dgst -sha384 -binary FILE | openssl base64 -A` on the file from
  `npm pack <pkg>@<version>`), or the browser will refuse the script.
- Supabase URL + publishable key live in the committed **`config.js`**. This is
  intentional: the publishable key is public by design; Row Level Security
  decides what it can do. **Never use environment variables for these** (there's
  no build step to inject them — that's what broke the old Lovable deployment).
  Never put a `service_role` / secret key anywhere in this repo.
- Map tiles: CARTO Voyager (OpenStreetMap data), no API key.
- Display font Bricolage Grotesque is self-hosted (`assets/fonts`, SIL OFL);
  body text uses the system font stack.

## Files
| File | What it is |
|---|---|
| `index.html` | The single page: header, map, banners, CDN scripts |
| `styles.css` | The one stylesheet (tokens at the top) |
| `config.js` | Supabase URL + publishable key, map start view |
| `app.js` | All app logic (plain script, uses globals `L` and `supabase`) |
| `supabase/migrations/` | Database schema history — see `docs/database-setup.md` |

## Supabase
- Project: **`rhxhpirgjjcxrgwhtuci`** ("matthewfriedler's Project", us-east-2),
  owned by Matthew. (The original Lovable-owned project `rqgtneaotgcpttbcrlwo`
  is no longer used.)
- Tables: `bars`, `bar_updates`, `bar_checkins`, `bar_baselines`,
  `bar_place_cache`, `bar_reading_confirmations`, `bar_staff`, `profiles`,
  `user_roles`. View: `bar_open_status` (open/closed computed from
  `bars.opening_hours`, America/Los_Angeles).
- Enforced **in the database** (don't rely on the frontend for these):
  - `bar_updates` inserts need `reporter_lat`/`reporter_lng` within **300 m**
    of the bar (`bar_updates_require_proximity`), else errors
    `location_required` / `too_far` with a plain-language `hint`.
  - **1 report per user per bar per 10 min** (`bar_updates_rate_limit`), error
    `rate_limited` with a `hint`; `created_at` is always set by the DB.
  - Admin = `matthewfriedler@gmail.com` once its email is confirmed.
- Applying migrations via the Supabase connector: it stalls on any `DROP …`
  statement (waits for a confirmation that never arrives). Avoid `DROP` or
  apply those lines another way. Test risky SQL inside `begin; … ` without a
  commit first.
- Opening hours in the DB are **placeholders** — not verified per bar.

## Design tokens (`:root` in styles.css)
Consumer-friendly and lively (young, social SF Marina), not a dark dashboard.
Mobile-first: it's used on a phone outside a bar.

| Token | Value | Use | Contrast |
|---|---|---|---|
| `--coral` | `#c4422b` | primary buttons, brand, links | white on it 5.1:1 |
| `--coral-strong` | `#a8361f` | hover; coral text on `--coral-tint` | |
| `--coral-bright` | `#ff6b4a` | decoration only (never text on light) | |
| `--teal` | `#0b6e79` | secondary, info, focus ring | 6.0:1 on white |
| `--teal-tint` | `#e0f3f4` | chips | teal on it 5.2:1 |
| `--bg` | `#f5f8fa` | page ("bay mist" off-white) | ink 15.5:1 |
| `--ink` / `--muted` | `#14202b` / `#4f5d6b` | text | muted 6.3:1 on bg |
| `--status-green` | `#1e9e5a` (text `#157a45`) | < 50% / no wait | text 5.4:1 |
| `--status-amber` | `#d99a00` (text `#8a5d00`) | 50–85% / short wait | text 5.8:1 |
| `--status-red` | `#e0393e` (text `#b8262b`) | 85%+ / line out the door | text 6.3:1 |
| `--status-none` | `#7b8794` | no recent report | |

Pins: coloured fill + white halo + **dark ring (`--pin-ring`)** + a glyph, so
they're ≥3:1 against the map and never rely on colour alone (amber alone is
only ~2:1 on light tiles). Dark theme tokens come in stage 2.

Spacing: `--space-1`…`--space-6` (4/8/12/16/24/32px). Tap targets ≥ 44px
(`--tap`). Respect `prefers-reduced-motion`.

## Behaviour rules
- **Never fail silently.** Zero bars, a failed request or a hung request (12 s
  timeout) must show the error banner with "Try again" — a page that loads with
  zero bars is the bug this rebuild exists to fix.
- Build popups/list items with `textContent`, never `innerHTML` with DB text.

## Run locally
```
python3 -m http.server 3000     # then open http://localhost:3000
```
Any static file server works; there's nothing to install.

## Deploy
- GitHub `matthewfriedler/barpulse` is the source of truth. Work on a branch,
  one PR per stage; Matthew merges.
- Vercel is connected **to the GitHub repo** (Add New → Project → import
  `barpulse`, Framework Preset "Other", no build command, no env vars).
  Every push to `main` deploys automatically; PRs get preview URLs.
- After the first deploy, Supabase → Authentication → URL Configuration: set
  Site URL (and a Redirect URL) to the Vercel domain so confirmation emails
  link to the live site.
- "Done" = pushed + live URL returns 200 **and shows all 15 bars**.

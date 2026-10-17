# Database setup log

The original BarPulse database was created by Lovable inside Lovable's own
Supabase account (project `rqgtneaotgcpttbcrlwo`), so it couldn't be changed
or verified from Matthew's account. On 2026-10-16 the schema was rebuilt in
Matthew's own Supabase project:

- **Project:** "matthewfriedler's Project" — ref `rhxhpirgjjcxrgwhtuci`, region `us-east-2`
- **Data carried over:** the 15 bars and their (placeholder) opening hours, which
  come from the migrations. No accounts or past crowd reports were carried over.

## What was applied

All 9 files in `supabase/migrations/` (2026-08-12 → 2026-10-05), in order and
unchanged in effect, then `20261016230000_owner_is_admin.sql`.

Two practical notes, so the live history makes sense:

1. **Some files were applied in smaller pieces.** The Supabase connector used to
   apply them pauses for confirmation on any `DROP …` statement and then times
   out. On a brand-new database every `DROP … IF EXISTS` in these files is a
   no-op, so those lines were left out and the rest applied as-is. That's why the
   live migration list shows names like `…_part1a_roles`.
2. **`20260911043125` step "reading source"** (the `source` / `door_count`
   columns, check constraint and `enforce_reading_source()` function) was applied
   with plain SQL, and only its trigger through the migration tool.

## Verified after setup

- 9 tables in `public`, all with row-level security on
- 15 bars, all with opening hours; `bar_place_cache` filled; open/closed computes
- Triggers present: `on_auth_user_created`, `on_auth_user_owner_admin`,
  `bar_updates_enforce_source`
- Realtime on `bar_updates`, `bar_checkins`, `bar_reading_confirmations`
- Admin rule tested in a rolled-back transaction: a stranger who signs up first
  does **not** become admin; `matthewfriedler@gmail.com` becomes admin only after
  the email is confirmed. No test rows were left behind (0 users afterwards).

## Open items from Supabase's security advisor (inherited from the Lovable schema)

- `public.bar_open_status` view runs as SECURITY DEFINER (low risk: only reads
  public bar hours) → proposed fix: `security_invoker = on`
- `public.is_open_at()` is SECURITY DEFINER and callable by anyone (low risk:
  pure calculation) → proposed fix: switch to SECURITY INVOKER
- `public.has_role()` callable by signed-in users → keep: row-level security
  policies depend on it

To be proposed alongside the stage-3 security migrations (300 m GPS check and
rate limit).

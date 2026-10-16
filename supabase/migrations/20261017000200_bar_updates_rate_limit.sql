-- Rate limit: one crowd report per person, per bar, every 10 minutes.
--
-- Before: one account could post unlimited reports, e.g. flood a bar with fake
-- "line out the door" reports to put people off.
-- After: a second report for the same bar within 10 minutes is rejected, with a
-- message saying how long to wait. Posting at a *different* bar is unaffected,
-- so bar-hopping works normally.
--
-- Why 10 minutes: crowds change over tens of minutes, not seconds, and the app
-- marks a report stale after 45 minutes. 10 minutes lets someone correct a report
-- once the line has really moved, while stopping rapid-fire spam.
--
-- Also: the report's time is always set by the database. Before, the app could
-- send its own created_at, which would let someone back-date a report to get
-- around the limit or make an old report look fresh.

CREATE INDEX IF NOT EXISTS bar_updates_user_bar_created_idx
  ON public.bar_updates (user_id, bar_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.enforce_update_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  last_at timestamptz;
  wait_min integer;
BEGIN
  NEW.created_at := now();

  -- Serialise reports from the same person for the same bar, so two reports sent
  -- at the same instant can't both slip through.
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.user_id::text || '|' || NEW.bar_id, 0));

  SELECT max(created_at) INTO last_at
  FROM public.bar_updates
  WHERE user_id = NEW.user_id
    AND bar_id = NEW.bar_id
    AND created_at > now() - interval '10 minutes';

  IF last_at IS NOT NULL THEN
    wait_min := greatest(1, ceil(extract(epoch FROM (last_at + interval '10 minutes' - now())) / 60)::int);
    RAISE EXCEPTION 'rate_limited'
      USING HINT = format('You just posted for this bar. You can post again in %s min.', wait_min);
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_update_rate_limit() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER bar_updates_rate_limit
  BEFORE INSERT ON public.bar_updates
  FOR EACH ROW EXECUTE FUNCTION public.enforce_update_rate_limit();

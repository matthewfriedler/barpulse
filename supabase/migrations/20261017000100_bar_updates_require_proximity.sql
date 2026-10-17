-- Enforce the "within ~300 m of the bar" rule in the database, not just the app.
--
-- Before: the 300 m check only lived in the old app's code. Anyone could skip the
-- app and send a crowd report straight to the database from anywhere.
-- After: every new report must include where the reporter was (lat/lng), and the
-- database rejects it if that point is more than 300 m from the bar.
--
-- Limitation: the database can't see a phone's GPS. It checks the coordinates it
-- is sent, so a determined person could still type in fake coordinates. This
-- stops casual and accidental posting from elsewhere; it is not tamper-proof.

ALTER TABLE public.bar_updates
  ADD COLUMN IF NOT EXISTS reporter_lat double precision,
  ADD COLUMN IF NOT EXISTS reporter_lng double precision,
  ADD COLUMN IF NOT EXISTS reporter_accuracy_m double precision;

ALTER TABLE public.bar_updates
  ADD CONSTRAINT bar_updates_reporter_lat_range CHECK (reporter_lat IS NULL OR reporter_lat BETWEEN -90 AND 90),
  ADD CONSTRAINT bar_updates_reporter_lng_range CHECK (reporter_lng IS NULL OR reporter_lng BETWEEN -180 AND 180);

-- Great-circle distance in metres (haversine). No PostGIS needed.
CREATE OR REPLACE FUNCTION public.distance_m(lat1 double precision, lng1 double precision,
                                             lat2 double precision, lng2 double precision)
RETURNS double precision
LANGUAGE sql IMMUTABLE STRICT
SET search_path = public
AS $$
  SELECT 2 * 6371000 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

CREATE OR REPLACE FUNCTION public.enforce_update_proximity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  b public.bars%ROWTYPE;
  d double precision;
BEGIN
  IF NEW.reporter_lat IS NULL OR NEW.reporter_lng IS NULL THEN
    RAISE EXCEPTION 'location_required'
      USING HINT = 'Turn on location so we can check you''re at the bar before posting.';
  END IF;

  SELECT * INTO b FROM public.bars WHERE id = NEW.bar_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'unknown_bar';
  END IF;

  d := public.distance_m(NEW.reporter_lat, NEW.reporter_lng, b.lat, b.lng);
  IF d > 300 THEN
    RAISE EXCEPTION 'too_far'
      USING DETAIL = format('%s m from %s', round(d), b.name),
            HINT = format('You need to be within 300 m of %s to post an update. You''re about %s m away.', b.name, round(d));
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_update_proximity() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER bar_updates_require_proximity
  BEFORE INSERT ON public.bar_updates
  FOR EACH ROW EXECUTE FUNCTION public.enforce_update_proximity();

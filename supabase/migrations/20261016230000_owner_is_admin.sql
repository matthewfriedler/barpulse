-- Make Matthew (matthewfriedler@gmail.com) the admin, instead of "whoever signs
-- up first".
--
-- Why: the previous rule (20260917042241) made the very first account the admin.
-- On a fresh database that's a race: anyone who signs up before Matthew would
-- get admin. Tying it to his email is explicit.
--
-- Why only after the email is confirmed: anyone can *type* an address at
-- sign-up. Granting admin only once Supabase has confirmed the address (the
-- owner clicked the link in the email) means nobody else can claim it.

-- 1. New-user setup without the "first account becomes admin" step.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  meta_username text;
  base_username text;
  candidate text;
  n int := 0;
  confirmed boolean;
BEGIN
  meta_username := NULLIF(NEW.raw_user_meta_data->>'username', '');
  confirmed := meta_username IS NOT NULL;
  base_username := lower(regexp_replace(
    COALESCE(meta_username, split_part(COALESCE(NEW.email, 'patron'), '@', 1)),
    '[^a-z0-9_]', '', 'g'));
  IF length(base_username) < 3 THEN
    base_username := 'patron';
  END IF;
  base_username := left(base_username, 16);
  candidate := base_username;
  WHILE EXISTS (SELECT 1 FROM public.profiles p WHERE p.username = candidate) LOOP
    n := n + 1;
    candidate := base_username || n::text;
  END LOOP;

  INSERT INTO public.profiles (id, username, username_confirmed, avatar_url)
  VALUES (
    NEW.id,
    candidate,
    confirmed,
    NULLIF(NEW.raw_user_meta_data->>'avatar_url', '')
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$function$;

-- 2. Grant admin to the owner's account once its email is confirmed.
CREATE OR REPLACE FUNCTION public.grant_owner_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL
     AND lower(NEW.email) = 'matthewfriedler@gmail.com' THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'admin')
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.grant_owner_admin() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER on_auth_user_owner_admin
AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.grant_owner_admin();

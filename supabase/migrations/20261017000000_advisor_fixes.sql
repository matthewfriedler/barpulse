-- Tidy-ups flagged by Supabase's security advisor (inherited from the Lovable schema).
--
-- 1. bar_open_status ran with its creator's permissions instead of the viewer's.
--    It only exposes public bar hours, but there's no reason for the elevated
--    permissions. Make it run as the person asking.
ALTER VIEW public.bar_open_status SET (security_invoker = on);

-- 2. is_open_at() is a pure calculation on the hours you pass in; it doesn't
--    need elevated permissions either.
ALTER FUNCTION public.is_open_at(jsonb, timestamptz) SECURITY INVOKER;

-- (has_role() stays callable by signed-in users on purpose: the row-level
--  security policies on bar_staff call it, and they run as the signed-in user.)

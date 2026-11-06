// BarPulse runtime config. Committed on purpose.
//
// The Supabase URL and publishable key are designed to be public: anyone using
// the app can see them in their browser anyway. What the key can do is decided
// by Row Level Security in the database, not by keeping it secret.
// Do NOT move these into environment variables — Vercel serves this folder as
// plain files with no build step, so there is nothing to inject them at build
// time (that is exactly what broke the old deployment).
//
// Never put the service_role / secret key here.
window.BARPULSE_CONFIG = {
  supabaseUrl: "https://rhxhpirgjjcxrgwhtuci.supabase.co",
  supabasePublishableKey: "sb_publishable_fP5URDLZ7V4f52bIf2J6SQ_hy6TgxdF",

  // Map starting view (Marina / Cow Hollow). The map refits to the bars once loaded.
  mapCenter: [37.7992, -122.4345],
  mapZoom: 15,
};

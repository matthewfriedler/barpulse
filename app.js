// BarPulse — map of real bars from Supabase.
// Plain browser JavaScript. Leaflet (L) and supabase-js (supabase) come from the
// CDN <script> tags in index.html; config from config.js.
(function () {
  "use strict";

  var cfg = window.BARPULSE_CONFIG;
  var els = {
    count: document.getElementById("bar-count"),
    loading: document.getElementById("banner-loading"),
    error: document.getElementById("banner-error"),
    errorTitle: document.getElementById("error-title"),
    errorDetail: document.getElementById("error-detail"),
    retry: document.getElementById("retry"),
  };

  // Fail loudly, never silently: a page that loads but shows zero bars is a bug.
  function showError(title, detail) {
    els.loading.hidden = true;
    els.errorTitle.textContent = title;
    els.errorDetail.textContent = " " + detail;
    els.error.hidden = false;
    els.count.textContent = "No bars";
  }

  if (!window.L || !window.supabase || !cfg) {
    showError("BarPulse didn’t finish loading.", "Part of the app couldn’t be downloaded. Check your connection and reload.");
    return;
  }

  var db = window.supabase.createClient(cfg.supabaseUrl, cfg.supabasePublishableKey);

  // ---------- Map ----------
  var map = L.map("map", { zoomControl: true, attributionControl: true })
    .setView(cfg.mapCenter, cfg.mapZoom);

  L.tileLayer("https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png", {
    maxZoom: 19,
    subdomains: "abcd",
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
  }).addTo(map);

  var markerLayer = L.layerGroup().addTo(map);

  function pinIcon(statusClass, glyph) {
    return L.divIcon({
      className: "",
      html: '<span class="pin ' + statusClass + '"><span class="pin__glyph" aria-hidden="true">' + glyph + "</span></span>",
      iconSize: [36, 36],      // includes padding so the tap target is >= 36px
      iconAnchor: [18, 34],
      popupAnchor: [0, -30],
    });
  }

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  // Popup content is built from DOM nodes (textContent), never from HTML strings,
  // so text coming from the database can't inject markup.
  function popupFor(bar) {
    var root = el("div", "bar-pop");
    root.appendChild(el("p", "bar-pop__name", bar.name));
    root.appendChild(el("p", "bar-pop__addr", bar.address));
    var tags = el("div", "bar-pop__tags");
    if (bar.open_now === true) tags.appendChild(el("span", "tag tag--open", "Open now"));
    else if (bar.open_now === false) tags.appendChild(el("span", "tag tag--closed", "Closed"));
    tags.appendChild(el("span", "tag", bar.neighborhood));
    tags.appendChild(el("span", "tag", bar.vibe));
    root.appendChild(tags);
    return root;
  }

  function render(bars) {
    markerLayer.clearLayers();
    var bounds = [];
    bars.forEach(function (bar) {
      var m = L.marker([bar.lat, bar.lng], {
        icon: pinIcon("pin--none", "•"),
        title: bar.name,          // tooltip + accessible name
        alt: bar.name,
        keyboard: true,
        riseOnHover: true,
      });
      m.bindPopup(popupFor(bar), { closeButton: true, autoPanPadding: [16, 72] });
      m.addTo(markerLayer);
      bounds.push([bar.lat, bar.lng]);
    });
    if (bounds.length) map.fitBounds(bounds, { padding: [40, 40], maxZoom: 16 });
    els.count.textContent = bars.length + (bars.length === 1 ? " bar" : " bars");
  }

  // ---------- Data ----------
  async function load() {
    els.error.hidden = true;
    els.loading.hidden = false;
    els.count.textContent = "Loading…";

    try {
      // Give up after 12 s so a hung connection ends in a clear error, not an endless spinner.
      var signal = window.AbortSignal && AbortSignal.timeout ? AbortSignal.timeout(12000) : undefined;
      var barsQ = db.from("bars").select("id,name,address,neighborhood,vibe,lat,lng").order("name");
      var openQ = db.from("bar_open_status").select("bar_id,open_now");
      if (signal) { barsQ = barsQ.abortSignal(signal); openQ = openQ.abortSignal(signal); }
      var results = await Promise.all([barsQ, openQ]);
      var barsRes = results[0];
      var openRes = results[1];
      if (barsRes.error) throw barsRes.error;

      var bars = barsRes.data || [];
      if (!bars.length) {
        showError("No bars came back from the database.", "That shouldn’t happen. Try again, and if it keeps happening, tell Matthew.");
        return;
      }

      // Open/closed is a nice-to-have: if it fails, still show the bars.
      var openById = {};
      if (!openRes.error && openRes.data) {
        openRes.data.forEach(function (r) { openById[r.bar_id] = r.open_now; });
      } else if (openRes.error) {
        console.warn("BarPulse: open/closed status unavailable", openRes.error);
      }
      bars.forEach(function (b) { b.open_now = openById.hasOwnProperty(b.id) ? openById[b.id] : null; });

      render(bars);
      els.loading.hidden = true;
    } catch (err) {
      console.error("BarPulse: failed to load bars", err);
      showError("Couldn’t load bars.", "Check your connection and try again.");
    }
  }

  els.retry.addEventListener("click", load);
  load();

  // Expose for debugging in the console.
  window.BarPulse = { map: map, db: db, reload: load };
})();

// Host-page chrome for the canned web demo: the "this is a preview" notice
// (#demo-banner) and the desktop/mobile viewport switcher (#demo-toolbar).
// See web/index.html and web/demo_banner.css. Plain JS, no dependencies, no
// external requests — this file is copied verbatim into build/web/ by
// `flutter build web` and must run under a strict CSP.
//
// The banner never gets a "dismiss" — only collapse, which keeps a
// one-line title bar always visible — per the same rule the in-app
// DemoNotice widget it replaced followed (lib/widgets/demo_notice.dart):
// the demo disclosure must never be fully hideable. It also starts
// expanded on every page load; nothing here persists a collapsed
// preference.

// Unhides the demo chrome. Called from Dart via dart:js_interop, and only by
// a kDemoMode build — see lib/core/host_page_demo_notice_web.dart. Defined as
// a global so the Dart side needs no DOM access of its own (dart:html is
// deprecated, and package:web would be a new dependency for one line).
//
// Name kept as-is despite now revealing the viewport switcher too: it is the
// Dart-side contract, and renaming it would mean editing Dart for no
// behavioural gain.
window.revealDemoBanner = function () {
  var banner = document.getElementById('demo-banner');
  if (banner) banner.style.display = 'flex';
  var toolbar = document.getElementById('demo-toolbar');
  if (toolbar) toolbar.style.display = 'flex';
};

// Mirrors the app's own theme onto the host page chrome. Called from Dart
// (lib/core/host_page_demo_notice_web.dart) on first build and on every
// toggle, so the banner and the stage around the app never disagree with the
// app itself.
//
// Without this the chrome followed `prefers-color-scheme` while the app
// followed its in-app toggle, so flipping the theme inside the demo left a
// light page wrapped around a dark app.
window.setDemoTheme = function (theme) {
  var frame = document.getElementById('demo-frame');
  if (frame) frame.setAttribute('data-theme', theme === 'dark' ? 'dark' : 'light');
};

(function () {
  var toggle = document.getElementById('demo-banner-toggle');
  var body = document.getElementById('demo-banner-body');
  if (toggle && body) {
    toggle.addEventListener('click', function () {
      var expanded = toggle.getAttribute('aria-expanded') === 'true';
      var next = !expanded;
      toggle.setAttribute('aria-expanded', String(next));
      toggle.setAttribute(
        'aria-label',
        next ? 'Collapse the preview notice' : 'Expand the preview notice'
      );
      toggle.setAttribute('title', next ? 'Collapse' : 'Expand');
      body.style.display = next ? 'block' : 'none';
      toggle.textContent = next ? '−' : '+';
    });
  }
})();

// Viewport switcher. Setting `data-view` on #demo-frame is the whole
// mechanism: CSS resizes #demo-stage, and Flutter re-lays-out because it
// sizes itself from #flutter-host's bounding box (web/flutter_bootstrap.js).
// No reload and no Dart involvement — which is also why the app keeps its
// playback state across a switch.
(function () {
  var frame = document.getElementById('demo-frame');
  var desktop = document.getElementById('demo-view-desktop');
  var mobile = document.getElementById('demo-view-mobile');
  if (!frame || !desktop || !mobile) return;

  function select(view) {
    frame.setAttribute('data-view', view);
    var onMobile = view === 'mobile';
    mobile.classList.toggle('is-active', onMobile);
    desktop.classList.toggle('is-active', !onMobile);
    mobile.setAttribute('aria-pressed', String(onMobile));
    desktop.setAttribute('aria-pressed', String(!onMobile));
  }

  desktop.addEventListener('click', function () { select('desktop'); });
  mobile.addEventListener('click', function () { select('mobile'); });
  select('desktop');
})();

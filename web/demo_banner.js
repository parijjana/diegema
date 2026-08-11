// Collapse/expand affordance for the host-page demo banner (#demo-banner,
// see web/index.html and web/demo_banner.css). Plain JS, no dependencies,
// no external requests — this file is copied verbatim into build/web/ by
// `flutter build web` and must run under a strict CSP.
//
// The banner never gets a "dismiss" — only collapse, which keeps a
// one-line title bar always visible — per the same rule the in-app
// DemoNotice widget it replaced followed (lib/widgets/demo_notice.dart):
// the demo disclosure must never be fully hideable. It also starts
// expanded on every page load; nothing here persists a collapsed
// preference.
// Unhides the banner. Called from Dart via dart:js_interop, and only by a
// kDemoMode build — see lib/core/host_page_demo_notice_web.dart. Defined as
// a global so the Dart side needs no DOM access of its own (dart:html is
// deprecated, and package:web would be a new dependency for one line).
window.revealDemoBanner = function () {
  var banner = document.getElementById('demo-banner');
  if (banner) banner.style.display = 'flex';
};

(function () {
  var toggle = document.getElementById('demo-banner-toggle');
  var body = document.getElementById('demo-banner-body');
  var actions = document.getElementById('demo-banner-actions');
  if (!toggle || !body || !actions) return;

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
    actions.style.display = next ? 'flex' : 'none';
    toggle.textContent = next ? '−' : '+';
  });
})();

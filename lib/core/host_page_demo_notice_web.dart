import 'dart:js_interop';

/// Calls `window.revealDemoBanner()`, defined in `web/demo_banner.js`, which
/// unhides `#demo-banner` in `web/index.html`.
///
/// Called once from `main()`, and only when `kDemoMode` is true — see
/// `core/demo_mode.dart`. A non-demo web build never calls this, so the
/// banner element (present in the DOM, `display: none` by default in
/// `web/demo_banner.css`) is never touched and stays invisible: "the
/// non-demo build must be completely unaffected."
///
/// Goes through a global JS function rather than touching the DOM from Dart
/// because `dart:html` is deprecated and `package:web` would be a new
/// dependency for a single line.
@JS('revealDemoBanner')
external void _revealDemoBanner();

void revealHostPageDemoNotice() => _revealDemoBanner();

/// Calls `window.setDemoTheme(theme)`, defined in `web/demo_banner.js`, which
/// stamps `data-theme` on `#demo-frame` so the host page chrome (the preview
/// banner and the stage around the app) follows the app's own theme toggle
/// rather than the OS `prefers-color-scheme` setting.
///
/// Without it the two disagree the moment someone uses the in-app toggle: a
/// light page wrapped around a dark app.
@JS('setDemoTheme')
external void _setDemoTheme(JSString theme);

void setHostPageTheme({required bool dark}) =>
    _setDemoTheme((dark ? 'dark' : 'light').toJS);

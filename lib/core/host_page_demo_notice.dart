/// Platform seam for [revealHostPageDemoNotice].
///
/// Task 1 of the UI redesign moves the "this is a preview" notice OUT of
/// the Flutter app entirely: it now lives as plain HTML/CSS in
/// `web/index.html` / `web/demo_banner.css`, a sibling of the Flutter host
/// element rather than a widget inside `AppShell`. The banner element ships
/// in the DOM on every web build (demo or not) but starts `display: none`;
/// only a `kDemoMode` build ever calls [revealHostPageDemoNotice] to show
/// it, and only on web (see the stub for every other platform).
library;

export 'host_page_demo_notice_stub.dart'
    if (dart.library.html) 'host_page_demo_notice_web.dart';

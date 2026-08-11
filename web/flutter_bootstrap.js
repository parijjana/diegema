// Custom bootstrap template (see
// https://docs.flutter.dev/platform-integration/web/initialization).
// `flutter build web` fills in the two tokens below and writes the result
// to build/web/flutter_bootstrap.js, which web/index.html still loads via
// the ordinary `<script src="flutter_bootstrap.js" async>` tag.
//
// The only change from Flutter's default bootstrap is `hostElement`: the
// app mounts into `#flutter-host` (see web/index.html) instead of `<body>`,
// so the host page's demo banner (`#demo-banner`, a sibling of
// `#flutter-host`) can sit above it without Flutter's canvas covering the
// whole viewport. See Task 1 of the UI redesign.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    var hostElement = document.querySelector('#flutter-host');
    var appRunner = await engineInitializer.initializeEngine({
      hostElement: hostElement,
    });
    await appRunner.runApp();
  },
});

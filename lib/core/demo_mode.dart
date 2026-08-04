/// Whether this build is the canned, streaming-only web demo described in
/// rework_plan.md ("REVISED SHIPPING ORDER" / "Demo build approach").
///
/// Set at build time with `--dart-define=DEMO_MODE=true`. When false (the
/// default), the app behaves exactly as it does today: real LibriVox/
/// archive.org network calls, real drift database on native platforms.
/// When true, [DemoLibriVoxService] and [DemoDownloader] are wired in
/// instead of the real network-backed services, so browsing never makes a
/// LibriVox API call (which is CORS-blocked from a browser anyway — see
/// rework_plan.md's CORS findings).
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

/// Base URL (or relative path) the demo build's playable chapters are
/// served from. Defaults to a relative `./audio/` folder alongside the
/// deployed site; override with `--dart-define=DEMO_AUDIO_BASE=<url>` to
/// point at wherever the audio actually ends up being hosted (e.g. a
/// Cloudflare Pages/R2 URL).
const String kDemoAudioBase =
    String.fromEnvironment('DEMO_AUDIO_BASE', defaultValue: './audio/');

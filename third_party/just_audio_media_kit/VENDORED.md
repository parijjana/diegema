# just_audio_media_kit (vendored)

Copied from just_audio_media_kit 2.1.0 on pub.dev (public domain, see LICENSE).
`lib/` and `pubspec.yaml` only.

The upstream package builds its `Player` privately, so an app cannot set mpv
properties. libmpv defaults to `tls-verify=no`, which left Windows streaming
without HTTPS certificate checks (audit S-01). The patch adds
`JustAudioMediaKit.mpvProperties`, applied and read back before a player reports
ready. Search for "Diegema patch". Everything else is unchanged.

Drop this copy if upstream gains a way to set properties.

# Diegema app icon: campfire

A teepee of logs with the fire burning on top, embers drifting into a night sky,
grass in the firelight. Colours are the app's own (`lib/theme/app_colors.dart`):
teal/ink for the night, rust for the fire.

Drawn procedurally by `render_campfire.py` (numpy + Pillow, ~2 min):

    python design/icon/render_campfire.py design/icon

- Flame: Perlin fBm noise distorts its outline into tongues and varies its
  intensity; coloured by heat (pale core, orange body, red edges and tips).
- Fire glow: inverse-square falloff, 1 / (1 + (d/d0)^2), lighting the sky, the
  logs (warm rim on the fire-facing side), the ground and the grass.
- Grass: tallest in the middle to hide the log bottoms; blades fade into the
  dark away from the fire.
- Rendered 2x supersampled, downsampled with Lanczos. Seeded: same output each run.

Outputs:
- `campfire_1024.png`: rounded square (rx 224), transparent corners. Source of
  the Windows `.ico` and the MSIX logo.
- `campfire_1024_fullbleed.png`: square, no transparency (iOS / Android adaptive).

Status (2026-10-09): in use on Windows. iOS, macOS, Android and web still carry
Flutter's default icon.

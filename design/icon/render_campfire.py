"""Procedural campfire icon for Diegema: teepee logs, fire on top, Perlin-noise
flame, inverse-square glow, drifting embers, night sky. Renders 2x supersampled.

python render_campfire.py [out_dir]  ->  campfire_1024.png (rounded, transparent
corners) and campfire_1024_fullbleed.png (square, for iOS / Android adaptive).
"""
import sys
import numpy as np
from PIL import Image

SS = 2
N = 1024 * SS
rng = np.random.default_rng(7)

# ---------- noise ----------
_perm = rng.permutation(256)
_perm = np.concatenate([_perm, _perm])
_ang = rng.uniform(0, 2 * np.pi, 256)
_gx, _gy = np.cos(_ang), np.sin(_ang)


def perlin(x, y):
    xi = np.floor(x).astype(np.int64)
    yi = np.floor(y).astype(np.int64)
    xf, yf = x - xi, y - yi
    xi &= 255
    yi &= 255

    def grad(ix, iy, dx, dy):
        h = _perm[_perm[ix] + iy]
        return _gx[h] * dx + _gy[h] * dy

    n00 = grad(xi, yi, xf, yf)
    n10 = grad(xi + 1, yi, xf - 1, yf)
    n01 = grad(xi, yi + 1, xf, yf - 1)
    n11 = grad(xi + 1, yi + 1, xf - 1, yf - 1)
    u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    v = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
    a = n00 + u * (n10 - n00)
    b = n01 + u * (n11 - n01)
    return a + v * (b - a)


def fbm(x, y, octaves=5, lac=2.0, gain=0.5):
    s, amp, f, norm = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        s = s + amp * perlin(x * f + o * 17.3, y * f - o * 9.1)
        norm += amp
        amp *= gain
        f *= lac
    return s / norm  # ~[-0.6, 0.6]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255


# ---------- grid (1024-unit coordinates) ----------
ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
X = (xs + 0.5) / SS
Y = (ys + 0.5) / SS

# ---------- sky ----------
t = Y / 1024
top, midc, bot = rgb('#060F13'), rgb('#0E2127'), rgb('#173540')
sky = np.where((t < 0.6)[..., None],
               top + (midc - top) * (t / 0.6)[..., None],
               midc + (bot - midc) * ((t - 0.6) / 0.4)[..., None])
sky = sky + 0.012 * fbm(X / 220, Y / 220, 3)[..., None]  # faint haze
img = sky.copy()

# fire geometry
FX, FY = 512.0, 520.0           # glow centre (flame body)
APEX_Y = 618.0                  # where the logs meet

# ---------- stars ----------
stars = []
while len(stars) < 70:
    sx, sy = rng.uniform(60, 964), rng.uniform(50, 600)
    if np.hypot(sx - FX, sy - 420) < 300:
        continue
    stars.append((sx, sy, rng.uniform(0.5, 1.5), rng.uniform(0.25, 0.9)))
for sx, sy, sr, sb in stars:
    x0, x1 = int((sx - 8) * SS), int((sx + 8) * SS)
    y0, y1 = int((sy - 8) * SS), int((sy + 8) * SS)
    d2 = (X[y0:y1, x0:x1] - sx) ** 2 + (Y[y0:y1, x0:x1] - sy) ** 2
    g = sb * np.exp(-d2 / (2 * sr * sr))
    img[y0:y1, x0:x1] += g[..., None] * rgb('#F2F0EA')

# ---------- inverse-square glow (sky) ----------
d = np.hypot(X - FX, (Y - FY) * 1.08)
glow = 1.0 / (1.0 + (d / 58.0) ** 2)
wide = 1.0 / (1.0 + (d / 210.0) ** 2)
img += (0.95 * glow)[..., None] * rgb('#F27A28') + (0.10 * wide)[..., None] * rgb('#C2501E')

# ---------- ground ----------
ground_y = 900 - 10 * np.cos((X - 512) / 1024 * np.pi * 1.1) + 4 * fbm(X / 60, 0.5, 3)
gmask = smoothstep(-1.5, 1.5, Y - ground_y)
soil = fbm(X / 14, Y / 6, 4)
gcol = rgb('#0A1512')[None, None, :] * (0.75 + 0.6 * soil[..., None])
glit = 1.0 / (1.0 + (np.hypot(X - FX, (Y - 890) * 2.0) / 120.0) ** 2)
gcol = gcol + glit[..., None] * rgb('#B4561F') * (0.5 + 0.35 * soil[..., None])
img = img * (1 - gmask[..., None]) + gcol * gmask[..., None]

# ---------- logs ----------
LIGHT = 1.0 / (1.0 + (np.hypot(X - FX, Y - (APEX_Y - 40)) / 170.0) ** 2)
bark, bark_dk = rgb('#7A4A2A'), rgb('#3E2414')
char = rgb('#1C1410')
end_lt, end_dk = rgb('#D8A468'), rgb('#9C6A3A')


def draw_log(ax, ay, bx, by, r, front=True, seed=0.0):
    """Log from base (ax, ay) to top (bx, by), radius r."""
    global img
    vx, vy = bx - ax, by - ay
    L = np.hypot(vx, vy)
    ux, uy = vx / L, vy / L
    px, py = X - ax, Y - ay
    along = px * ux + py * uy               # 0 at base, L at top
    perp = -px * uy + py * ux               # signed distance across
    tcl = np.clip(along, 0, L)
    dist = np.hypot(px - tcl * ux, py - tcl * uy)
    m = smoothstep(r + 0.8, r - 0.8, dist)
    if not m.any():
        return
    s = np.clip(perp / r, -1, 1)
    tt = along / L
    # cylinder shading, lit from the fire above
    cyl = 0.45 + 0.55 * np.sqrt(np.clip(1 - s * s, 0, 1))
    lx, ly = FX - X, (APEX_Y - 90) - Y
    ln = np.hypot(lx, ly) + 1e-6
    facing = np.clip(s * (-uy * lx + ux * ly) / ln, 0, 1)
    rim = facing * smoothstep(0.25, 0.9, np.abs(s))
    groove = 1 - 0.38 * smoothstep(0.72, 1.0, np.abs(np.sin(s * np.pi * 3.5 + 2.2 * fbm(along / 22 + seed, s, 2))))
    ao = 0.5 + 0.5 * smoothstep(0, 110, ground_y - Y)
    grain = 0.6 * fbm(along / 7.0 + seed, s * 2.2 + seed, 4) + 0.7 * fbm(along / 26.0 - seed, s * 0.9, 3)
    knots = smoothstep(0.38, 0.5, fbm(along / 30 + seed * 3, s * 1.2, 2))
    col = bark[None, None] + (bark_dk - bark)[None, None] * np.clip(0.5 + 1.8 * grain, -0.1, 1.2)[..., None]
    col = col * (1 - 0.35 * knots[..., None])
    # bark edge outline
    col = col * (0.55 + 0.45 * smoothstep(1.0, 0.82, np.abs(s)))[..., None]
    # char toward the fire, with glowing cracks
    ch = smoothstep(0.48, 0.92, tt) * (0.85 + 0.3 * fbm(along / 15, s * 3 + seed, 3))
    ch = np.clip(ch, 0, 1)
    col = col * (1 - ch[..., None]) + char * ch[..., None]
    crack = smoothstep(0.16, 0.24, fbm(along / 9 + seed * 5, s * 4 - seed, 4)) * smoothstep(0.6, 0.95, tt)
    lit = (0.3 + 1.5 * LIGHT) * cyl * groove * ao
    col = col * lit[..., None] + (rim * LIGHT * 0.95)[..., None] * rgb('#FF9A4A') + crack[..., None] * rgb('#FF7A26') * 1.1
    # end grain on the cut base (front logs only)
    if front:
        de = np.hypot(X - ax, Y - ay)
        em = smoothstep(r * 0.92 + 0.8, r * 0.92 - 0.8, de) * (along < 0)
        rings = 0.5 + 0.5 * np.sin(de * 0.55 + 2.5 * fbm(X / 18 + seed, Y / 18, 3))
        ecol = end_dk[None, None] + (end_lt - end_dk)[None, None] * rings[..., None]
        ecol = ecol * (0.55 + 0.6 * smoothstep(r, 0, de))[..., None] * (0.55 + 0.9 * LIGHT)[..., None]
        col = col * (1 - em[..., None]) + ecol * em[..., None]
    img = img * (1 - m[..., None]) + col * m[..., None]


# back logs (darker, behind), then front logs
draw_log(452, 868, 548, 596, 25, front=False, seed=1.3)
draw_log(578, 872, 474, 594, 25, front=False, seed=2.7)
draw_log(512, 884, 512, 586, 27, front=False, seed=4.1)
draw_log(318, 858, 556, 606, 31, front=True, seed=5.9)
draw_log(706, 858, 468, 606, 31, front=True, seed=7.7)

# coals glow on the log tops
cg = 1.0 / (1.0 + (np.hypot(X - 512, (Y - APEX_Y + 4) * 1.6) / 62.0) ** 2)
img += (0.38 * cg)[..., None] * rgb('#FF8A30')

# ---------- grass (in front of the logs; lit by the fire) ----------
GLIGHT = 1.0 / (1.0 + (np.hypot(X - FX, (Y - 700) * 1.3) / 175.0) ** 2)
g_dark, g_mid, g_warm = rgb('#06110E'), rgb('#2F4A26'), rgb('#E08A3A')
blades = []
for i in range(270):
    rxp = rng.uniform(90, 934)
    centre = np.exp(-((rxp - 512) / 230) ** 2)
    h = rng.uniform(22, 48) + 82 * centre * rng.uniform(0.6, 1.0)
    lean = rng.normal(0, 1) * h * 0.35 + (rxp - 512) * 0.05
    w0 = rng.uniform(4.0, 8.5)
    blades.append((rxp, h, lean, w0, rng.uniform(0.85, 1.15)))
blades.sort(key=lambda b: -b[1])  # tall ones behind
for rxp, h, lean, w0, tint in blades:
    ry = 900 - 10 * np.cos((rxp - 512) / 1024 * np.pi * 1.1) + 6
    x0 = int(max(0, (min(rxp, rxp + lean) - w0 - 3) * SS)); x1 = int(min(N, (max(rxp, rxp + lean) + w0 + 3) * SS))
    y0 = int(max(0, (ry - h - 3) * SS)); y1 = int(min(N, (ry + 3) * SS))
    if x1 <= x0 or y1 <= y0:
        continue
    Xw, Yw = X[y0:y1, x0:x1], Y[y0:y1, x0:x1]
    u = (ry - Yw) / h
    uc = np.clip(u, 0, 1)
    cxb = rxp + lean * uc ** 2
    slope = 2 * lean * uc / h
    half = 0.5 * w0 * (1 - uc) ** 1.1 + 0.15
    dxb = (Xw - cxb) / np.sqrt(1 + slope ** 2)
    m = smoothstep(half + 0.5, half - 0.5, np.abs(dxb)) * (u >= 0) * smoothstep(1.0, 0.97, u)
    if not m.any():
        continue
    across = np.clip(dxb / np.maximum(half, 0.2), -1, 1)
    side = np.clip(-across * np.sign(rxp + lean * 0.5 - FX + 1e-3), 0, 1)   # side facing the fire
    L = GLIGHT[y0:y1, x0:x1]
    base = g_dark[None, None] + (g_mid - g_dark)[None, None] * (0.25 + 0.75 * uc)[..., None] * tint
    col = base * (0.25 + 1.6 * L)[..., None] + (L * (0.35 + 0.9 * side) * uc ** 0.6 * 0.85)[..., None] * g_warm
    vis = np.clip(0.35 + 1.4 * L, 0, 1)   # far blades melt into the dark ground
    bg = img[y0:y1, x0:x1]
    col = bg * (1 - vis[..., None]) + col * vis[..., None]
    img[y0:y1, x0:x1] = bg * (1 - m[..., None]) + col * m[..., None]

# ---------- flame (on top of the logs) ----------
BASE_Y, TIP_Y = 614.0, 190.0
H = BASE_Y - TIP_Y


def flame_field(cx, base_y, tip_y, half_w, seed, sway):
    h = base_y - tip_y
    v = (base_y - Y) / h                    # 0 at base, 1 at tip
    vv = np.clip(v, 0, 1)
    rise = Y / 70.0 + seed
    dx = fbm(X / 70.0 + seed, rise, 5) * (55 + 150 * vv ** 1.1)
    dx += sway * np.sin(vv * 3.1 + seed) * vv ** 1.5
    xd = X + dx - cx
    hw = half_w * (1 - vv) ** 0.9 * smoothstep(-0.12, 0.22, v) * (1 + 0.45 * np.sin(vv * np.pi))
    hw = np.maximum(hw, 1e-3)
    core = np.clip(1 - np.abs(xd) / hw, 0, 1)
    I = core ** 0.75 * smoothstep(-0.12, 0.1, v) * (1 - vv) ** 0.5
    detail = fbm(X / 40.0 + seed * 2, Y / 28.0 + seed, 5)
    I = I * (0.7 + 1.1 * detail)
    # licks: break the upper flame up with rising noise
    breakup = fbm(X / 60.0 - seed, Y / 40.0 + seed * 3, 4) + 0.5
    I = I - (0.22 + 0.5 * smoothstep(0.08, 0.9, vv)) * breakup
    return np.clip(I, 0, 1.4)


F = flame_field(512, BASE_Y, TIP_Y, 110, 0.0, 40)
F = np.maximum(F, 0.8 * flame_field(474, BASE_Y - 6, 320, 70, 3.3, -34))
F = np.maximum(F, 0.8 * flame_field(552, BASE_Y - 4, 290, 72, 6.1, 38))
F = np.maximum(F, 0.55 * flame_field(526, BASE_Y - 40, 140, 46, 9.4, 52))
F = F * 0.78

# colour ramp: deep red -> orange -> amber -> pale core
stops = [0.0, 0.12, 0.3, 0.55, 0.8, 1.05]
cols = np.array([rgb(c) for c in ('#300A02', '#9A2A0A', '#D9481A', '#F5862A', '#FFC25A', '#FFF1C8')])
vflame = np.clip((BASE_Y - Y) / (BASE_Y - TIP_Y), 0, 1)
Fc = np.clip(F * (1.05 - 0.55 * vflame ** 0.8), 0, 1.05)
fcol = np.stack([np.interp(Fc, stops, cols[:, k]) for k in range(3)], -1)
alpha = smoothstep(0.03, 0.3, F)[..., None]
# screen blend so the logs show through the flame's thin edges
img = 1 - (1 - np.clip(img, 0, 1)) * (1 - fcol * alpha)

# ---------- embers ----------
embers = []
for i in range(46):
    a = rng.uniform(0, 1) ** 0.8               # height fraction along the path
    x0 = rng.normal(520, 38)
    y0 = rng.uniform(300, 460)
    ex = x0 + 150 * a + 38 * np.sin(a * 7 + rng.uniform(0, 6.28))
    ey = y0 - a * (y0 - 40)
    size = (1 - a) * rng.uniform(1.4, 5.2) + 0.8
    bright = (1 - a) ** 1.2 * rng.uniform(0.35, 1.0) + 0.1
    embers.append((ex, ey, size, bright))
for ex, ey, sz, br in embers:
    R = sz * 8
    x0, x1 = max(0, int((ex - R) * SS)), min(N, int((ex + R) * SS))
    y0, y1 = max(0, int((ey - R * 1.6) * SS)), min(N, int((ey + R * 1.6) * SS))
    if x1 <= x0 or y1 <= y0:
        continue
    dxp = X[y0:y1, x0:x1] - ex
    dyp = Y[y0:y1, x0:x1] - ey
    # slight streak: stretched along the upward-right drift
    dd2 = (dxp * 0.94 + dyp * 0.34) ** 2 + ((-dxp * 0.34 + dyp * 0.94) / 1.35) ** 2
    halo = br * 0.28 * np.exp(-dd2 / (2 * (sz * 1.9) ** 2))
    core = 1.3 * br * np.exp(-dd2 / (2 * (sz * 0.38) ** 2))
    img[y0:y1, x0:x1] += halo[..., None] * rgb('#F2782A') + core[..., None] * rgb('#FFD48A')

# ---------- finish ----------
vig = 1 - 0.28 * smoothstep(0.55, 1.05, np.hypot(X - 512, Y - 560) / 620)
img *= vig[..., None]
img = np.clip(img, 0, 1)
# gentle filmic shoulder so highlights don't clip flat
img = 1 - np.exp(-img * 1.25)
img = img / (1 - np.exp(-1.25))

out = sys.argv[1] if len(sys.argv) > 1 else '.'
rgb8 = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
full = Image.fromarray(rgb8, 'RGB').resize((1024, 1024), Image.LANCZOS)
full.save(f'{out}/campfire_1024_fullbleed.png')

# rounded-square mask (rx 224 of 1024), antialiased
rx = 224 * SS
qx = np.maximum(np.abs(xs + 0.5 - N / 2) - (N / 2 - rx), 0)
qy = np.maximum(np.abs(ys + 0.5 - N / 2) - (N / 2 - rx), 0)
md = np.hypot(qx, qy) - rx
mask = (smoothstep(1.0, -1.0, md) * 255 + 0.5).astype(np.uint8)
rgba = np.dstack([rgb8, mask])
Image.fromarray(rgba, 'RGBA').resize((1024, 1024), Image.LANCZOS).save(f'{out}/campfire_1024.png')
print('ok')

#!/usr/bin/env python3
"""Builds the bundled ambience loops in assets/ambience/.

Reproducible and dependency-free (macOS `afconvert` + the Python stdlib). `--only a,b` rebuilds just those
recordings (AAC output can differ byte-wise between macOS versions):

    python3 tool/ambience/prepare_ambience.py ~/code/projects/Aulos/assets/audio/noise

(Sources outside the repo; the newer clips live in a folder of their own, e.g.
`~/code/projects/diegema/ambience-src`. Any recording whose source file is missing is skipped
with a note, so each folder can be built on its own.)

For each recording it:
  1. decodes the source MP3 to 16-bit PCM (`afconvert`; it reads OGG Vorbis too, so no ffmpeg is needed);
  2. keeps at most MAX_SECONDS and folds the tail back over the head with an
     equal-power crossfade, so the file loops with no seam or click;
  3. sets its level to TARGET_DBFS RMS, well under spoken word (LibriVox
     narration sits around -20 dBFS RMS), so at full slider an ambience sits
     roughly 12 dB below the book and can never drown it;
  4. encodes AAC in an .m4a (`afconvert`), whose priming metadata lets the
     player loop it gaplessly.

White, pink and brown noise are synthesised here, not recorded, so they carry
no licence at all. Sources: BigSoundBank (Joseph Sardin), CC0 1.0 — see
assets/ambience/CREDITS.md.
"""
import array, math, os, random, subprocess, sys, tempfile, wave

MAX_SECONDS = 75.0
TARGET_DBFS = -32.0
NOISE_DBFS = -34.0
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'ambience')

# id: (source file, keep stereo?)
RECORDINGS = {
    'ocean_surf': ('ocean_surf.mp3', True),
    'ocean_waves': ('ocean_rhythmic.mp3', False),
    'forest': ('forest_ambience.mp3', True),
    'deep_forest': ('forest_deep.mp3', True),
    'rain': ('rain_heavy.mp3', True),
    'thunderstorm': ('thunderstorm.mp3', True),
    'campfire': ('campfire.mp3', False),
    'city_street': ('city_street.mp3', True),
    # Added for Mimesis cue sheets. Source files are named after the sound id
    # (see assets/ambience/CREDITS.md for each clip's BigSoundBank page).
    'tavern_crowd': ('tavern_crowd.mp3', True),
    'wind': ('wind.mp3', True),
    'gulls': ('gulls.mp3', True),
    'ship_timbers': ('ship_timbers.mp3', True),
    'jungle_insects': ('jungle_insects.mp3', True),
    'night_crickets': ('night_crickets.mp3', True),
    'river': ('river.mp3', True),
    'horses': ('horses.mp3', True),
    'fireplace': ('fireplace.mp3', True),
    # Freesound (banan_, CC0); an OGG Vorbis file, which afconvert decodes directly.
    'battle': ('385895__banan__battlefield-ambience-loop.ogg', True),
}


def fix_extensible_header(path):
    """afconvert writes WAVE_FORMAT_EXTENSIBLE (tag 0xFFFE) for some decodes,
    e.g. OGG Vorbis; Python's `wave` only reads plain PCM. When the sub-format
    is PCM, relabel the tag in place (the sample data is unchanged)."""
    with open(path, 'r+b') as f:
        head = f.read(48)
        if head[20:22] == b'\xfe\xff' and head[44:46] == b'\x01\x00':
            f.seek(20)
            f.write(b'\x01\x00')


def read_wav(path):
    fix_extensible_header(path)
    with wave.open(path) as w:
        ch, rate = w.getnchannels(), w.getframerate()
        data = array.array('h', w.readframes(w.getnframes()))
    return ch, rate, data


def write_wav(path, ch, rate, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(array.array('h', samples).tobytes())


def loop_and_level(ch, rate, data, target_dbfs):
    frames = len(data) // ch
    keep = min(frames, int(MAX_SECONDS * rate))
    fade = min(int(3.0 * rate), keep // 6)
    body = keep - fade
    out = [0.0] * (body * ch)
    for i in range(body * ch):
        out[i] = float(data[i])
    # Equal-power crossfade: the tail (just after `body`) fades out over the
    # head, so the last sample of the loop flows into the first.
    for f in range(fade):
        t = f / fade
        g_in, g_out = math.sin(t * math.pi / 2), math.cos(t * math.pi / 2)
        for c in range(ch):
            head = out[f * ch + c]
            tail = float(data[(body + f) * ch + c])
            out[f * ch + c] = head * g_in + tail * g_out
    rms = math.sqrt(sum(s * s for s in out) / len(out)) or 1.0
    want = 32767 * 10 ** (target_dbfs / 20)
    gain = want / rms
    # Sparse sources (crackling fire, hooves) have peaks far above their RMS,
    # so levelling them would clip. Peaks go through a soft knee instead
    # (identity below half scale), and the gain is nudged until the result
    # still lands on the target RMS. Steady sources never reach the knee.
    for _ in range(6):
        leveled = [_soft(s * gain) for s in out]
        got = math.sqrt(sum(v * v for v in leveled) / len(leveled)) or 1.0
        if abs(20 * math.log10(got / want)) < 0.05:
            break
        gain *= want / got
    return [int(round(v)) for v in leveled]


def _soft(x, knee=16384.0, top=32767.0):
    a = abs(x)
    if a <= knee:
        return x
    y = knee + (top - knee) * math.tanh((a - knee) / (top - knee))
    return math.copysign(min(y, top), x)


def noise(colour, rate=44100, seconds=20.0):
    rnd = random.Random(colour)  # deterministic: rebuilds are identical
    n = int(rate * seconds) + int(3.0 * rate)
    out, b = [], [0.0] * 7
    brown = 0.0
    for _ in range(n):
        w = rnd.uniform(-1, 1)
        if colour == 'white':
            s = w
        elif colour == 'pink':  # Paul Kellet's refined pink filter
            b[0] = 0.99886 * b[0] + w * 0.0555179
            b[1] = 0.99332 * b[1] + w * 0.0750759
            b[2] = 0.96900 * b[2] + w * 0.1538520
            b[3] = 0.86650 * b[3] + w * 0.3104856
            b[4] = 0.55000 * b[4] + w * 0.5329522
            b[5] = -0.7616 * b[5] - w * 0.0168980
            s = b[0] + b[1] + b[2] + b[3] + b[4] + b[5] + b[6] + w * 0.5362
            b[6] = w * 0.115926
        else:  # brown: leaky integrated white noise
            brown = (brown + 0.02 * w) / 1.02
            s = brown * 3.5
        out.append(s * 8000)
    return 1, rate, array.array('h', [max(-32768, min(32767, int(s))) for s in out])


def encode(wav, name, ch):
    dst = os.path.join(OUT, name + '.m4a')
    bitrate = '96000' if ch == 2 else '64000'
    subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', bitrate,
                    wav, dst], check=True)
    print(f'{name}.m4a  {os.path.getsize(dst) // 1024} KB')


def main(src_dir, noises=True, only=None):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, (src, stereo) in RECORDINGS.items():
            if only and name not in only:
                continue
            if not os.path.exists(os.path.join(src_dir, src)):
                print(f'skip {name}: {src} not in {src_dir}')
                continue
            raw = os.path.join(tmp, name + '.wav')
            args = ['afconvert', '-f', 'WAVE', '-d', 'LEI16']
            if not stereo:
                args += ['-c', '1']
            subprocess.run(args + [os.path.join(src_dir, src), raw], check=True)
            ch, rate, data = read_wav(raw)
            looped = os.path.join(tmp, name + '_loop.wav')
            write_wav(looped, ch, rate, loop_and_level(ch, rate, data, TARGET_DBFS))
            encode(looped, name, ch)
        for colour in ('white', 'pink', 'brown') if noises else ():
            ch, rate, data = noise(colour)
            looped = os.path.join(tmp, colour + '_loop.wav')
            write_wav(looped, ch, rate, loop_and_level(ch, rate, data, NOISE_DBFS))
            encode(looped, colour + '_noise', ch)


if __name__ == '__main__':
    only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
    main(os.path.expanduser(sys.argv[1]),
         noises='--no-noise' not in sys.argv and not only, only=only)

#!/usr/bin/env python3
"""Builds the bundled ambience loops in assets/ambience/.

Reproducible and dependency-free (macOS `afconvert` + the Python stdlib):

    python3 tool/ambience/prepare_ambience.py ~/code/projects/Aulos/assets/audio/noise

For each recording it:
  1. decodes the source MP3 to 16-bit PCM (`afconvert`);
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
}


def read_wav(path):
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
    gain = (32767 * 10 ** (target_dbfs / 20)) / rms
    return [max(-32768, min(32767, int(round(s * gain)))) for s in out]


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


def main(src_dir):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, (src, stereo) in RECORDINGS.items():
            raw = os.path.join(tmp, name + '.wav')
            args = ['afconvert', '-f', 'WAVE', '-d', 'LEI16']
            if not stereo:
                args += ['-c', '1']
            subprocess.run(args + [os.path.join(src_dir, src), raw], check=True)
            ch, rate, data = read_wav(raw)
            looped = os.path.join(tmp, name + '_loop.wav')
            write_wav(looped, ch, rate, loop_and_level(ch, rate, data, TARGET_DBFS))
            encode(looped, name, ch)
        for colour in ('white', 'pink', 'brown'):
            ch, rate, data = noise(colour)
            looped = os.path.join(tmp, colour + '_loop.wav')
            write_wav(looped, ch, rate, loop_and_level(ch, rate, data, NOISE_DBFS))
            encode(looped, colour + '_noise', ch)


if __name__ == '__main__':
    main(os.path.expanduser(sys.argv[1]))

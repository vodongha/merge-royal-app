"""Synthesize all Merge Royal SFX + a looping music bed as 16-bit mono WAVs."""
import wave, struct, math, random, os

SR = 44100
OUT = r"C:\Users\ADMIN\Documents\Personal\merge-royal-app\assets\audio"
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def _wave(kind, ph):
    if kind == "sine":
        return math.sin(ph)
    if kind == "square":
        return 1.0 if math.sin(ph) >= 0 else -1.0
    if kind == "saw":
        x = (ph / (2 * math.pi)) % 1.0
        return 2 * x - 1
    if kind == "tri":
        x = (ph / (2 * math.pi)) % 1.0
        return 4 * abs(x - 0.5) - 1
    return 0.0


def tone(buf, start, freq0, freq1, dur, vol=0.5, kind="sine",
         a=0.01, d=0.04, s=0.7, r=0.06):
    n = int(dur * SR)
    ph = 0.0
    for i in range(n):
        t = i / n
        f = freq0 + (freq1 - freq0) * t
        ph += 2 * math.pi * f / SR
        # ADSR-ish envelope
        ta = a
        td = a + d
        tr = dur - r
        tt = i / SR
        if tt < ta:
            env = tt / ta if ta > 0 else 1
        elif tt < td:
            env = 1 - (1 - s) * ((tt - ta) / d) if d > 0 else s
        elif tt < tr:
            env = s
        else:
            env = s * max(0.0, (dur - tt) / r) if r > 0 else 0
        idx = start + i
        if idx < len(buf):
            buf[idx] += vol * env * _wave(kind, ph)


def noise(buf, start, dur, vol=0.5, decay=True, lp=0.0):
    n = int(dur * SR)
    prev = 0.0
    for i in range(n):
        env = (1 - i / n) if decay else 1.0
        s = random.uniform(-1, 1)
        if lp > 0:  # simple one-pole low-pass
            prev = prev + lp * (s - prev)
            s = prev
        idx = start + i
        if idx < len(buf):
            buf[idx] += vol * env * s


def save(name, buf):
    # normalize softly to avoid clipping
    peak = max(1e-6, max(abs(x) for x in buf))
    scale = min(1.0, 0.92 / peak)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for x in buf:
            v = int(max(-1, min(1, x * scale)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print(name, f"{len(buf)/SR:.2f}s")


def blank(dur):
    return [0.0] * int(dur * SR)


# tap: short bright click
b = blank(0.08)
tone(b, 0, 1500, 1700, 0.06, vol=0.5, kind="square", a=0.002, d=0.02, s=0.3, r=0.03)
save("tap.wav", b)

# merge: satisfying pop sweeping up
b = blank(0.22)
tone(b, 0, 420, 880, 0.18, vol=0.55, kind="sine", a=0.005, d=0.05, s=0.6, r=0.09)
tone(b, 0, 840, 1320, 0.12, vol=0.25, kind="tri", a=0.005, d=0.04, s=0.4, r=0.06)
save("merge.wav", b)

# combo: quick ascending arpeggio (sparkly)
b = blank(0.34)
notes = [660, 880, 1175, 1320]
for k, f in enumerate(notes):
    tone(b, int(k * 0.05 * SR), f, f, 0.12, vol=0.4, kind="square",
         a=0.003, d=0.03, s=0.5, r=0.06)
save("combo.wav", b)

# mistake: low descending buzz
b = blank(0.3)
tone(b, 0, 320, 140, 0.26, vol=0.5, kind="saw", a=0.004, d=0.05, s=0.6, r=0.1)
save("mistake.wav", b)

# bomb: noise boom + low thump
b = blank(0.5)
noise(b, 0, 0.4, vol=0.6, decay=True, lp=0.05)
tone(b, 0, 120, 50, 0.45, vol=0.6, kind="sine", a=0.002, d=0.1, s=0.5, r=0.2)
save("bomb.wav", b)

# shuffle: filtered noise swish up
b = blank(0.35)
noise(b, 0, 0.32, vol=0.4, decay=False, lp=0.2)
tone(b, 0, 300, 900, 0.3, vol=0.25, kind="tri", a=0.02, d=0.05, s=0.5, r=0.1)
save("shuffle.wav", b)

# levelup: ascending major triad chime
b = blank(0.8)
for k, f in enumerate([523, 659, 784, 1047]):
    tone(b, int(k * 0.09 * SR), f, f, 0.5, vol=0.4, kind="sine",
         a=0.01, d=0.08, s=0.6, r=0.3)
save("levelup.wav", b)

# gameover: descending minor tones
b = blank(0.9)
for k, f in enumerate([440, 349, 277, 220]):
    tone(b, int(k * 0.16 * SR), f, f, 0.4, vol=0.45, kind="tri",
         a=0.01, d=0.06, s=0.6, r=0.2)
save("gameover.wav", b)

# music: seamless looping chiptune bed (~8s), low volume
BPM = 96
beat = 60.0 / BPM
bars = 4
dur = beat * 4 * bars
b = blank(dur)
# bass (root notes per bar): A minor vibe -> A, F, C, G
bass = [110.0, 87.31, 130.81, 98.0]
for bar in range(bars):
    for step in range(8):  # eighth notes
        t = (bar * 4 + step * 0.5) * beat
        tone(b, int(t * SR), bass[bar], bass[bar], beat * 0.45,
             vol=0.16, kind="square", a=0.005, d=0.05, s=0.5, r=0.05)
# arpeggio melody (pentatonic) per bar
arps = [
    [440, 523, 659, 523],
    [349, 440, 523, 440],
    [523, 659, 784, 659],
    [392, 494, 587, 494],
]
for bar in range(bars):
    seq = arps[bar]
    for step in range(8):
        t = (bar * 4 + step * 0.5) * beat
        f = seq[step % len(seq)]
        tone(b, int(t * SR), f, f, beat * 0.4,
             vol=0.10, kind="tri", a=0.005, d=0.04, s=0.4, r=0.05)
save("music.wav", b)

print("done ->", OUT)

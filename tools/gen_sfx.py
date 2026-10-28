"""Genera los efectos de sonido y la musica de Hitdash por sintesis.

Todo el audio sale de este script (sin samples externos), asi que es
100% libre de derechos. Para regenerarlo:

    python tools/gen_sfx.py

Escribe archivos .wav (44.1 kHz, mono, 16 bits) en sounds/.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")

random.seed(7)


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def env(i, n, attack=0.005, curve=3.0):
    """Envolvente: ataque lineal corto y caida exponencial."""
    t = i / RATE
    a = min(t / attack, 1.0) if attack > 0 else 1.0
    return a * (1.0 - i / n) ** curve


def tone(freq_start, freq_end, seconds, shape="sine", curve=3.0, vol=1.0, attack=0.005):
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        k = i / n
        f = freq_start * (freq_end / freq_start) ** k
        phase += 2 * math.pi * f / RATE
        if shape == "sine":
            s = math.sin(phase)
        elif shape == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        elif shape == "saw":
            s = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
        else:  # triangle
            s = 2.0 * abs(2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0) - 1.0
        out.append(s * env(i, n, attack, curve) * vol)
    return out


def noise(seconds, curve=3.0, vol=1.0, lowpass=0.0, attack=0.002):
    """Ruido blanco con un filtro paso bajo de un polo (0 = sin filtro)."""
    n = int(RATE * seconds)
    out = []
    last = 0.0
    for i in range(n):
        s = random.uniform(-1.0, 1.0)
        if lowpass > 0.0:
            last = last + (s - last) * (1.0 - lowpass)
            s = last * (1.0 + lowpass * 3.0)
        out.append(s * env(i, n, attack, curve) * vol)
    return out


def sweep_noise(seconds, lp_start, lp_end, curve=2.0, vol=1.0):
    """Ruido cuyo filtro se abre o cierra con el tiempo (whoosh)."""
    n = int(RATE * seconds)
    out = []
    last = 0.0
    for i in range(n):
        k = i / n
        lp = lp_start + (lp_end - lp_start) * k
        last = last + (random.uniform(-1, 1) - last) * (1.0 - lp)
        # Envolvente en campana para que entre y salga suave.
        e = math.sin(math.pi * k) ** curve
        out.append(last * e * vol * 3.0)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def offset(track, seconds):
    return silence(seconds) + track


def save(name, samples, peak=0.85):
    top = max(1e-9, max(abs(s) for s in samples))
    gain = peak / top
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples
        ))
    print("ok", path)


# --- Efectos ----------------------------------------------------------------

def sfx():
    save("hit", mix(
        tone(180, 60, 0.09, "sine", 2.5),
        noise(0.06, 4.0, 0.6, 0.35),
    ), 0.7)

    save("crit", mix(
        tone(220, 60, 0.12, "sine", 2.5),
        noise(0.08, 4.0, 0.5, 0.2),
        offset(tone(1760, 1700, 0.22, "triangle", 2.0, 0.35), 0.01),
        offset(tone(2640, 2600, 0.18, "sine", 2.0, 0.2), 0.01),
    ), 0.75)

    save("kill", mix(
        tone(140, 40, 0.25, "sine", 2.0),
        noise(0.2, 2.5, 0.5, 0.6),
        tone(600, 120, 0.18, "square", 3.0, 0.12),
    ), 0.8)

    save("dash", sweep_noise(0.2, 0.95, 0.55, 1.5, 0.9), 0.6)

    save("hurt", mix(
        tone(320, 110, 0.22, "square", 2.0, 0.5),
        noise(0.08, 3.0, 0.4, 0.5),
    ), 0.7)

    notes = [523.25, 659.25, 783.99, 1046.5]
    save("rank_up", concat(*[tone(f, f, 0.07, "square", 1.2, 0.5) for f in notes[:-1]],
                           tone(notes[-1], notes[-1], 0.25, "square", 2.0, 0.5)), 0.5)

    save("pickup", concat(
        tone(880, 1320, 0.07, "sine", 1.0),
        tone(1320, 1760, 0.12, "sine", 2.5),
    ), 0.55)

    save("bolt", mix(
        tone(900, 260, 0.14, "square", 2.0, 0.35),
        tone(1200, 400, 0.14, "sine", 2.0, 0.4),
    ), 0.45)

    save("wave", concat(
        tone(392, 392, 0.16, "saw", 1.0, 0.5),
        tone(587.33, 587.33, 0.4, "saw", 2.0, 0.5),
    ), 0.55)

    save("slam", mix(
        tone(90, 30, 0.45, "sine", 1.6),
        noise(0.35, 2.0, 0.6, 0.8),
    ), 0.9)

    save("summon", mix(
        tone(200, 800, 0.4, "triangle", 1.2, 0.5, 0.05),
        sweep_noise(0.4, 0.95, 0.7, 1.0, 0.4),
    ), 0.6)

    save("teleport", mix(
        tone(1500, 300, 0.25, "sine", 1.0, 0.5),
        sweep_noise(0.25, 0.6, 0.95, 1.0, 0.5),
    ), 0.55)

    # Rugido del jefe: sierra grave con vibrato y ruido.
    n = int(RATE * 1.3)
    roar = []
    phase = 0.0
    last = 0.0
    for i in range(n):
        k = i / n
        f = 75 + 25 * math.sin(2 * math.pi * 6 * k) + 30 * (1 - k)
        phase += 2 * math.pi * f / RATE
        saw = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
        last = last + (random.uniform(-1, 1) - last) * 0.2
        e = min(k / 0.08, 1.0) * (1 - k) ** 1.5
        roar.append((saw * 0.7 + last * 1.2) * e)
    save("boss_roar", roar, 0.9)

    save("boss_death", mix(
        tone(220, 30, 1.6, "saw", 1.5, 0.6),
        noise(1.4, 1.8, 0.7, 0.85),
        offset(tone(880, 110, 1.0, "square", 2.0, 0.15), 0.1),
    ), 0.9)

    # Desenvainar: chirrido metalico brillante.
    save("equip", mix(
        sweep_noise(0.25, 0.3, 0.05, 1.0, 0.25),
        offset(tone(2200, 2400, 0.35, "triangle", 2.5, 0.35), 0.03),
        offset(tone(3300, 3500, 0.3, "sine", 2.5, 0.2), 0.05),
    ), 0.6)

    # Cofre: golpe de madera y campanitas subiendo.
    save("chest", concat(
        mix(tone(120, 60, 0.12, "sine", 2.0), noise(0.08, 3.0, 0.5, 0.7)),
        tone(784, 784, 0.07, "triangle", 1.5, 0.5),
        tone(988, 988, 0.07, "triangle", 1.5, 0.5),
        tone(1319, 1319, 0.3, "triangle", 2.5, 0.5),
    ), 0.6)

    # Rayo: chisporroteo agudo.
    zap = []
    for i in range(int(RATE * 0.22)):
        k = i / (RATE * 0.22)
        s = random.uniform(-1, 1) if random.random() < 0.35 else 0.0
        zap.append(s * (1 - k) ** 2)
    save("zap", mix(zap, tone(1800, 600, 0.2, "square", 2.0, 0.2)), 0.5)

    # Bloqueo con escudo: golpe metalico grave.
    save("block", mix(
        tone(520, 500, 0.3, "triangle", 3.0, 0.5),
        tone(780, 760, 0.25, "sine", 3.0, 0.3),
        noise(0.05, 4.0, 0.5, 0.3),
    ), 0.6)

    # Portal: barrido que sube, acorde brillante y zumbido grave.
    save("portal_open", mix(
        sweep_noise(0.9, 0.97, 0.6, 1.2, 0.5),
        tone(110, 220, 1.2, "saw", 1.5, 0.25, 0.2),
        offset(tone(659.25, 659.25, 0.9, "triangle", 2.0, 0.25, 0.05), 0.35),
        offset(tone(987.77, 987.77, 0.8, "triangle", 2.0, 0.2, 0.05), 0.45),
        offset(tone(1318.5, 1318.5, 0.7, "sine", 2.0, 0.2, 0.05), 0.55),
    ), 0.7)

    # Muerte del jugador: golpe seco, dos latidos que se apagan y un
    # zumbido grave que cae.
    save("player_death", mix(
        tone(160, 35, 0.5, "sine", 1.5),
        noise(0.4, 2.0, 0.6, 0.85),
        offset(tone(70, 45, 0.18, "sine", 2.0, 0.9), 0.55),
        offset(tone(70, 45, 0.18, "sine", 2.0, 0.6), 0.8),
        offset(tone(110, 40, 1.8, "saw", 1.2, 0.25, 0.3), 0.1),
        offset(tone(440, 110, 1.4, "triangle", 2.0, 0.12, 0.2), 0.2),
    ), 0.9)


# --- Musica -----------------------------------------------------------------

def music():
    """Bucle oscuro tipo chiptune en La menor, 140 BPM, 8 compases."""
    bpm = 140
    beat = 60.0 / bpm
    bars = 8
    total = int(RATE * beat * 4 * bars)
    out = [0.0] * total

    def put(track, start_sec, vol=1.0):
        s = int(start_sec * RATE)
        for i, v in enumerate(track):
            if s + i < total:
                out[s + i] += v * vol

    # Progresion: Am - F - G - Em (x2)
    roots = [110.0, 87.31, 98.0, 82.41] * 2
    chords = [
        [220.0, 261.63, 329.63],
        [174.61, 220.0, 261.63],
        [196.0, 246.94, 293.66],
        [164.81, 196.0, 246.94],
    ] * 2

    for bar in range(bars):
        t0 = bar * 4 * beat
        root = roots[bar]
        # Bajo en corcheas con octava.
        for step in range(8):
            f = root if step % 2 == 0 else root * 2
            put(tone(f, f, beat * 0.45, "triangle", 1.5), t0 + step * beat / 2, 0.55)
        # Arpegio en semicorcheas.
        chord = chords[bar]
        pattern = [0, 1, 2, 1, 0, 2, 1, 2]
        for step in range(16):
            f = chord[pattern[step % 8]] * 2
            put(tone(f, f, beat * 0.22, "square", 2.5), t0 + step * beat / 4, 0.12)
        # Bombo en cada pulso y caja en 2 y 4.
        for b in range(4):
            put(tone(150, 45, 0.16, "sine", 2.5), t0 + b * beat, 0.9)
            if b % 2 == 1:
                put(noise(0.12, 3.0, 1.0, 0.3), t0 + b * beat, 0.35)
        # Hi-hat en contratiempo.
        for b in range(4):
            put(noise(0.03, 4.0, 1.0, 0.0), t0 + b * beat + beat / 2, 0.12)

    save("music_loop", out, 0.6)

    # Tema del jefe: mas rapido y agresivo, en Re menor con bajo en sierra.
    bpm = 165
    beat = 60.0 / bpm
    total = int(RATE * beat * 4 * bars)
    out = [0.0] * total
    roots = [73.42, 73.42, 87.31, 65.41, 73.42, 73.42, 58.27, 65.41]
    lead = [587.33, 698.46, 659.25, 523.25, 587.33, 880.0, 698.46, 659.25]
    for bar in range(bars):
        t0 = bar * 4 * beat
        root = roots[bar]
        for step in range(16):
            f = root if step % 4 != 3 else root * 2
            put(tone(f, f, beat * 0.22, "saw", 2.0), t0 + step * beat / 4, 0.32)
        put(tone(lead[bar], lead[bar] * 0.98, beat * 1.8, "square", 1.2), t0, 0.1)
        put(tone(lead[bar] * 1.5, lead[bar] * 1.5, beat * 1.6, "square", 1.2), t0 + beat * 2, 0.08)
        for b in range(8):
            put(tone(160, 45, 0.12, "sine", 2.5), t0 + b * beat / 2, 0.8 if b % 2 == 0 else 0.45)
        for b in (1, 3):
            put(noise(0.14, 2.5, 1.0, 0.25), t0 + b * beat, 0.4)

    save("music_boss", out, 0.6)


if __name__ == "__main__":
    sfx()
    music()

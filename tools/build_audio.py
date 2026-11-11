#!/usr/bin/env python3
"""Build original loopable music for the Godot Web edition.
Pure Python WAV synth; no external encoder, samples,
no copyrighted melodies. WAV samples are generated, not images.
Run: python3 tools/build_audio.py
"""
import math, wave, array, pathlib, subprocess, tempfile
from random import Random

OUT = pathlib.Path(__file__).resolve().parents[1] / "godot" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
SEMITONES = dict(C=0, D=2, E=4, F=5, G=7, A=9, B=11)

def hz(name):
    letter = name[0]
    index = 1
    accidental = 0
    if name[index] == "#":
        accidental = 1
        index += 1
    octave = int(name[index:])
    return 440.0 * 2 ** (((octave + 1) * 12 + SEMITONES[letter] + accidental - 69) / 12)

def wave_shape(phase, kind):
    if kind == "square":
        return 0.84 if (phase % 1.0) < 0.48 else -0.84
    if kind == "triangle":
        return 1.0 - 4.0 * abs((phase % 1.0) - 0.5)
    if kind == "saw":
        return 2.0 * (phase % 1.0) - 1.0
    if kind == "organ":
        return math.sin(phase * math.tau) + 0.28 * math.sin(phase * 2 * math.tau)
    return math.sin(phase * math.tau)

def add_note(buffer, start, duration, note, volume, kind):
    if note == "-":
        return
    start_idx = int(start * SR)
    count = min(int(duration * SR), len(buffer) - start_idx)
    freq = hz(note)
    if count <= 0 or start_idx < 0:
        return
    for j in range(count):
        t = j / SR
        progress = j / max(1, count - 1)
        attack = min(1.0, t * 65.0)
        fade = max(0.0, min(1.0, (1.0 - progress) * 13.0))
        # Gentle vibrato on sustained strings; stable for tracker lead.
        osc_phase = freq * t + (0.003 * math.sin(t * 4.7) if kind == "organ" else 0.0)
        buffer[start_idx + j] += wave_shape(osc_phase, kind) * volume * attack * fade

def add_drum(buffer, start, kind, rng):
    start_idx = int(start * SR)
    duration = {"kick":0.18, "snare":0.13, "hat":0.045}[kind]
    count = min(int(duration * SR), len(buffer) - start_idx)
    if start_idx < 0 or count < 1:
        return
    for j in range(count):
        t = j / SR
        amp = math.exp(-t * {"kick":28,"snare":38,"hat":90}[kind])
        if kind == "kick":
            v = math.sin(math.tau * (58*t + 90*t*math.exp(-t*22))) * 0.52
        else:
            noise = rng.uniform(-1,1)
            v = noise * (0.21 if kind == "snare" else 0.095)
        buffer[start_idx + j] += v * amp

def render(title, bpm, roots, lead, style):
    assert len(lead) % 16 == 0
    steps = len(lead)
    step_time = 60 / bpm / 4
    length = steps * step_time
    audio = array.array("f", [0]) * int(length * SR)
    rng = Random(173)
    chord_map = {
      "Em": ["E3","G3","B3"], "C": ["C3","E3","G3"],
      "G": ["G3","B3","D4"], "D": ["D3","F#3","A3"],
      "Am": ["A2","C3","E3"], "Bm": ["B2","D3","F#3"],
      "B": ["B2","D#3","F#3"], "F": ["F3","A3","C4"]
    }
    bass_map = {"Em":"E2","C":"C2","G":"G2","D":"D2",
                "Am":"A2","Bm":"B2","B":"B1","F":"F2"}
    for i, name in enumerate(lead):
        measure = i // 16
        pos = i % 16
        chord = roots[measure % len(roots)]
        now = i * step_time
        if name != "-":
            add_note(audio, now, step_time * (0.91 if style=="battle" else 1.8),
                     name, 0.15 if style=="battle" else 0.12,
                     "square" if style=="battle" else "triangle")
        if pos % 4 == 0:
            add_note(audio, now, step_time * 3.6, bass_map[chord],
                     0.125 if style=="battle" else 0.10,"saw" if style=="battle" else "triangle")
        if pos == 0 or pos == 8:
            for cn in chord_map[chord]:
                add_note(audio, now, step_time * 7.6, cn, 0.028,
                         "saw" if style=="battle" else "organ")
        if style == "battle":
            if pos in (0, 8): add_drum(audio, now, "kick", rng)
            if pos in (4, 12): add_drum(audio, now, "snare", rng)
            if pos % 2 == 0: add_drum(audio, now, "hat", rng)
        elif style == "field":
            if pos == 0: add_drum(audio, now, "kick", rng)
            if pos in (4,12): add_drum(audio, now, "hat", rng)
    # Shape the headroom; fades only between samples at the seam
    peak = max(0.01, max(abs(x) for x in audio))
    gain = min(1.0, 0.68 / peak)
    fade_samples = int(0.006 * SR)
    pcm = array.array("h")
    for i,x in enumerate(audio):
        seam = min(1.0, i / max(1,fade_samples),
                   (len(audio)-i-1) / max(1,fade_samples))
        pcm.append(int(max(-1.0, min(1.0,x*gain*seam)) * 32767))
    target = OUT / (title + ".wav")
    with wave.open(str(target), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(title, f"{length:.1f}s", f"{target.stat().st_size} bytes")

def repeat_to_8bars(patterns):
    return [n for p in patterns for n in p.split()]

battle = [
"E5 G5 B5 D6 B5 G5 A5 B5 E6 D6 B5 A5 G5 B5 D6 B5",
"C6 B5 G5 E5 G5 A5 B5 G5 A5 G5 E5 D5 E5 G5 A5 B5",
"D6 B5 A5 F#5 A5 B5 D6 F#6 E6 D6 B5 A5 B5 D6 E6 D6",
"B5 A5 G5 E5 G5 B5 E6 D6 B5 G5 F#5 E5 D5 E5 G5 B5",
"E6 D6 B5 G5 A5 B5 G5 E5 C6 B5 G5 E5 G5 A5 B5 D6",
"E6 F#6 G6 E6 D6 B5 A5 G5 B5 D6 E6 D6 B5 A5 G5 F#5",
"G5 B5 E6 G6 F#6 E6 D6 B5 A5 B5 D6 B5 G5 A5 B5 D6",
"E6 D6 B5 A5 G5 F#5 E5 D5 E5 G5 B5 D6 B5 G5 F#5 E5",
]
field = [
"E5 - G5 - B5 - G5 - F#5 - E5 - D5 - E5 -",
"G5 - A5 - B5 - A5 - G5 - E5 - D5 - - -",
"C5 - E5 - G5 - E5 - D5 - C5 - D5 - E5 -",
"D5 - F#5 - A5 - F#5 - E5 - D5 - B4 - D5 -",
"E5 - B5 - A5 - G5 - E5 - G5 - B5 - - -",
"C6 - B5 - G5 - E5 - D5 - E5 - G5 - - -",
"A5 - G5 - F#5 - D5 - E5 - F#5 - A5 - - -",
"B5 - G5 - F#5 - E5 - D5 - E5 - - - - -",
]
cave = [
"E4 - - B4 - - G4 - E4 - - D4 - - - -",
"C4 - - G4 - - E4 - D4 - - C4 - - - -",
"D4 - - A4 - - F#4 - D4 - - B3 - - - -",
"B3 - - F#4 - - D#4 - B3 - - D#4 - - - -",
"E4 - B4 - - G4 - - E5 - B4 - - G4 - -",
"F4 - C5 - - A4 - - F4 - C5 - - A4 - -",
"D4 - A4 - - F#4 - - D5 - A4 - - F#4 - -",
"B3 - F#4 - - D#4 - - B4 - F#4 - - D#4 - -",
]
if __name__ == "__main__":
    render("battle",164,["Em","C","D","Em","C","D","Em","B"],repeat_to_8bars(battle),"battle")
    render("field",96,["Em","C","G","D","C","Am","D","Em"],repeat_to_8bars(field),"field")
    render("cave",80,["Em","C","D","B","Em","F","D","B"],repeat_to_8bars(cave),"cave")

def render_sfx(name, notes, duration=0.16, noise=0.0):
    """Short original mono WAV effects, deliberately separate from music tracks."""
    rng = Random(1234)
    samples = array.array("h")
    for i in range(int(duration * SR)):
        t = i / SR
        u = t / duration
        amp = max(0.0, (1.0-u)**2) * min(1.0, t * 120)
        note = notes[min(len(notes)-1, int(u*len(notes)))]
        pitch = hz(note)
        wave_v = math.sin(math.tau*pitch*t) * 0.65 + math.sin(math.tau*pitch*2*t)*0.14
        wave_v += rng.uniform(-1,1)*noise
        samples.append(int(max(-1.0,min(1.0,wave_v*amp*0.7))*32767))
    target=OUT/(name+".wav")
    with wave.open(str(target),"wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(samples.tobytes())
    print("SE",name,target.stat().st_size)

if __name__ == "__main__":
    render_sfx("confirm", ["E5","B5","E6"],0.19)
    render_sfx("step", ["C4","G3"],0.085,0.06)
    render_sfx("attack", ["E5","B4","E4"],0.23,0.12)
    render_sfx("hit", ["D4","A3","D3"],0.19,0.22)

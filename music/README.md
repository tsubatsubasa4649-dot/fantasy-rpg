# Original Battle BGM — Fate at the Broken Bridge
- Original music composed specifically for this project. Not an arrangement or transcription.
- **164 BPM, E minor, 4/4, 8 bars / ~11.7-second looping phrase**.
- Mood: heated melodic fantasy battle; aggressive bass line, bright lead melody, rock-like drum drive.
- Browser implementation: `music/battle.js` uses Web Audio oscillators and percussion synthesis. No externally loaded copyrighted audio or image assets.
- Integrated in the root `index.html`: combat entry starts BGM if enabled, battle exit stops; manual sound switch `♪ BGM` supports iOS gesture-based audio unlocking.
- The standalone WAV export is available from the chat conversation, but has **not been committed to this GitHub repository**. The Godot 4 implementation currently remains in its data foundation phase and does not yet use audio.
- Next music milestone: longer variation with a distinct boss theme, separate field theme, and reusable OGG files for Godot.

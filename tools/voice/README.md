# Chandu's voice clips (docs/voice/)

Each mp3 is one sentence Chandu says, read by the Kokoro-82M TTS model (Apache-2.0) with the Japanese voice `jf_tebukuro`,
named by the hash `voiceKey()` in src/chandu.html. To regenerate after changing lines:

1. `./build.sh`, then `node collect.js lines.json` (needs Playwright) collects every Chandu line.
2. `node split.js lines.json pieces.json` splits them into sentences with the same rule as the game.
3. `python gen.py pieces.json ../../docs/voice 0 1` (kokoro-onnx, misaki[ja], soundfile, ffmpeg) makes the missing clips.
   It expects the Kokoro ONNX model and the Japanese voice vectors next to it (see the paths at the top).

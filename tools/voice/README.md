# Chandu's voice clips (docs/voice/)

Each mp3 is one sentence Chandu says, read by VOICEVOX CORE with the voice 猫使ビィ (ノーマル, style 58),
named by the hash `voiceKey()` in src/chandu.html. The voice's terms ask for the credit "VOICEVOX:猫使ビィ",
which the settings screen shows. To regenerate after changing lines:

1. `./build.sh`, then `node collect.js lines.json` (needs Playwright) collects every Chandu line.
2. `node split.js lines.json pieces.json` splits them into sentences with the same rule as the game.
3. `python gen.py pieces.json ../../docs/voice 0 1` makes the missing clips (run several parts in parallel, e.g. `0 4` … `3 4`).
   It needs the voicevox_core 0.17 wheel, VOICEVOX ONNX Runtime 1.23, the Open JTalk dictionary (all from GitHub releases)
   and `vvms/13.vvm` from github.com/VOICEVOX/voicevox_vvm, under `VV_DIR` (see the paths at the top), plus ffmpeg.

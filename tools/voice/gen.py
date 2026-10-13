import json, sys, os, re, time, subprocess, numpy as np, soundfile as sf
from kokoro_onnx import Kokoro
from misaki import ja
D = '/tmp/claude-0/tts/'
pieces = json.load(open(sys.argv[1])); out = sys.argv[2]; part, nparts = int(sys.argv[3]), int(sys.argv[4])
voice = os.environ.get('VOICE', 'jf_tebukuro'); speed = float(os.environ.get('SPEED', '1.05'))
os.makedirs(out, exist_ok=True)
g = ja.JAG2P(); k = Kokoro(D + 'ek/package/build/kokoro-quantized.onnx', D + 'voices-ja.bin')
emoji = re.compile('[\U0001F000-\U0001FFFF☀-➿️]')
items = sorted(pieces.items())[part::nparts]; t0 = time.time()
for i, (key, s) in enumerate(items):
    dst = f'{out}/{key}.mp3'
    if os.path.exists(dst): continue
    t = emoji.sub('', s.replace('{name}', 'きみ').replace('？？？', 'ひみつの おたから')).strip()
    ph = g(t); ph = ph[0] if isinstance(ph, tuple) else ph
    a, sr = k.create(ph, voice=voice, speed=speed, is_phonemes=True)
    nz = np.where(np.abs(a) > 0.01)[0]
    if len(nz): a = a[max(0, nz[0] - int(sr * .03)): nz[-1] + int(sr * .08)]
    wav = f'/tmp/claude-0/tts/tmp-{part}.wav'; sf.write(wav, a, sr)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-af', 'loudnorm=I=-16:TP=-1.5', '-ar', '24000', '-ac', '1', '-c:a', 'libmp3lame', '-b:a', '40k', dst], check=True)
    if i % 50 == 0: print(part, i, len(items), round(time.time() - t0), flush=True)

# Reads Chandu's sentences with VOICEVOX CORE (voice: 猫使ビィ ノーマル) and writes one mp3 per sentence.
# Usage: python gen.py pieces.json ../../docs/voice PART NPARTS   (needs the voicevox_core wheel, ffmpeg and the files below)
import json, sys, os, re, time, subprocess
from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile
D = os.environ.get('VV_DIR', '/home/user/dl/')
ORT = D + 'assets/voicevox_onnxruntime-linux-x64-1.23.2/lib/libvoicevox_onnxruntime.so'
DIC = D + 'assets/open_jtalk_dic_utf_8-1.11'
VVM = D + 'voicevox_vvm/vvms/13.vvm'
STYLE = int(os.environ.get('STYLE', '58')); SPEED = float(os.environ.get('SPEED', '1.05')); INTON = float(os.environ.get('INTON', '1.25'))
pieces = json.load(open(sys.argv[1])); out = sys.argv[2]; part, nparts = int(sys.argv[3]), int(sys.argv[4])
os.makedirs(out, exist_ok=True)
syn = Synthesizer(Onnxruntime.load_once(filename=ORT), OpenJtalk(DIC), cpu_num_threads=1)
with VoiceModelFile.open(VVM) as m: syn.load_voice_model(m)
emoji = re.compile('[\U0001F000-\U0001FFFF☀-➿️♪]')
items = sorted(pieces.items())[part::nparts]; t0 = time.time()
for i, (key, s) in enumerate(items):
    dst = f'{out}/{key}.mp3'
    if os.path.exists(dst): continue
    t = emoji.sub('', s.replace('{name}', 'きみ').replace('？？？', 'ひみつの おたから')).replace('〜', 'ー').strip()
    aq = syn.create_audio_query(t, STYLE)
    aq.speed_scale, aq.intonation_scale, aq.pre_phoneme_length, aq.post_phoneme_length = SPEED, INTON, 0.05, 0.08
    wav = f'{out}/.tmp-{part}.wav'; open(wav, 'wb').write(syn.synthesis(aq, STYLE))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-af', 'loudnorm=I=-16:TP=-1.5', '-ar', '24000', '-ac', '1', '-c:a', 'libmp3lame', '-b:a', '40k', dst], check=True)
    if i % 50 == 0: print(part, i, len(items), round(time.time() - t0), flush=True)
os.remove(f'{out}/.tmp-{part}.wav') if os.path.exists(f'{out}/.tmp-{part}.wav') else None

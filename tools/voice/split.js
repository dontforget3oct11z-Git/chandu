// Must match voicePieces() in src/chandu.html
const voicePieces = (t) => (String(t).replace(/\s+/g, " ").match(/[^！？。!?…〜♪]*[！？。!?…〜♪]+|[^！？。!?…〜♪]+$/g) || [])
  .map((s) => s.trim()).filter((s) => s && !s.includes("${") && /[ぁ-んァ-ヶ一-龯]/.test(s));
const voiceKey = (s) => { let h = 0x811c9dc5; for (const ch of s) { h ^= ch.codePointAt(0); h = Math.imul(h, 0x01000193) >>> 0; } return h.toString(16).padStart(8, "0"); };
const lines = JSON.parse(require('fs').readFileSync(process.argv[2]));
const out = {}; for (const l of lines) for (const p of voicePieces(l)) out[voiceKey(p)] = p;
require('fs').writeFileSync(process.argv[3], JSON.stringify(out, null, 0));
console.log(Object.keys(out).length, [...Object.values(out)].reduce((a, s) => a + s.length, 0));

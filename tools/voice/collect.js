// Collects every sentence Chandu can say: his story lines (with the お宝 name hidden too) and the say() lines.
const { chromium } = require('playwright'); const fs = require('fs');
const src = fs.readFileSync('/home/claude/chandu/src/chandu.html', 'utf8').split('\n');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file:///home/claude/chandu/docs/test.html'); await p.waitForTimeout(500);
  const areas = await p.evaluate(() => window.chanduExport().areas); await b.close();
  const lines = [];
  for (const a of areas) for (const col of ['前編の会話', '後編の会話', 'お宝の会話']) for (const l of (a[col] || '').split('\n')) {
    const m = l.match(/^チャンドゥ: (.*)$/); if (!m) continue;
    lines.push(m[1]); if (a['お宝'] && m[1].includes(a['お宝'])) lines.push(m[1].split(a['お宝']).join('？？？'));
  }
  const sayLines = src.map((l, i) => [l, i]).filter(([l]) => /say\(|const msg = \{|const line = rate|setVoiceTry/.test(l));
  for (const [l] of sayLines) {
    for (const m of l.matchAll(/"((?:[^"\\]|\\.)*)"/g)) lines.push(m[1]);
    for (const m of l.matchAll(/`([^`]*)`/g)) lines.push(m[1]);
  }
  fs.writeFileSync(process.argv[2], JSON.stringify(lines));
  console.log(lines.length);
})();

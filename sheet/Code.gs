// チャンドゥの大冒険: スプレッドシートと アプリを つなぐ Apps Script
// シートの「拡張機能 → Apps Script」に まるごと はりつけて、ウェブアプリとして デプロイします。
//   GET  … エリア / キャラクター / はいけい の 3つの シートと、キャラの がぞうを JSONで かえす
//          キャラクター シートの アイコン欄に いれた がぞう（セル内の がぞう / =IMAGE("URL")）も icons で かえす
//          「チャンドゥ」シートに ならべた がぞうは chandu（リスト）で かえす。アプリが ランダムに つかう
//   POST … {op:"image", name, data}            キャラの がぞうを「がぞう」シートに しまう（data が からなら けす）
//          {op:"rows", tab, rows:[{No:…, 列名:値}]}  No が おなじ ぎょうを うわがき（なければ ついか）
//          {op:"tab", tab, values:[[…],[…]]}     シートを まるごと いれかえる
const IMG = "がぞう";
const CHANDU = "チャンドゥ";
const TABS = { areas: "エリア", chars: "キャラクター", bgs: "はいけい" };

function doGet() {
  const ss = SpreadsheetApp.getActive(), out = {};
  Object.keys(TABS).forEach((k) => (out[k] = readTab(ss.getSheetByName(TABS[k]))));
  out.images = readImages(ss);
  Object.assign(out, readIcons(ss.getSheetByName(TABS.chars)));
  let ch = ss.getSheetByName(CHANDU);
  if (!ch) { ch = ss.insertSheet(CHANDU); ch.getRange(1, 1, 21, 3).setValues([["No", "キャラクター", "アイコン"]].concat(Array.from({ length: 20 }, (_, i) => [i + 1, "チャンドゥ", "🐯"]))); }
  out.chandu = readChandu(ch);
  return json(out);
}

function doPost(e) {
  const b = JSON.parse(e.postData.contents), ss = SpreadsheetApp.getActive();
  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    if (b.op === "image") return json(saveImage(ss, String(b.name || ""), String(b.data || "")));
    if (b.op === "rows") return json(saveRows(ss.getSheetByName(b.tab), b.rows || [], b.key || "No"));
    if (b.op === "tab") {
      const sh = ss.getSheetByName(b.tab) || ss.insertSheet(b.tab);
      sh.clearContents();
      const w = Math.max(...b.values.map((r) => r.length));
      const vals = b.values.map((r) => r.concat(Array(w - r.length).fill("")));
      if (sh.getMaxColumns() < w) sh.insertColumnsAfter(sh.getMaxColumns(), w - sh.getMaxColumns());
      if (sh.getMaxRows() < vals.length) sh.insertRowsAfter(sh.getMaxRows(), vals.length - sh.getMaxRows());
      sh.getRange(1, 1, vals.length, w).setValues(vals);
      return json({ ok: true, rows: vals.length });
    }
    return json({ ok: false, error: "unknown op" });
  } finally {
    lock.releaseLock();
  }
}

function readTab(sh) {
  if (!sh || sh.getLastRow() < 1) return [];
  const v = sh.getDataRange().getDisplayValues(), h = v.shift().map(String);
  return v.filter((r) => r.some((x) => x !== "")).map((r) => Object.fromEntries(h.map((k, i) => [k, r[i]])));
}

// Pictures put in the アイコン columns of the キャラクター tab → {character name: image URL}.
// Works for "insert image in cell" and for =IMAGE("https://…"); a picture floating over the cells has no
// readable link unless it was inserted from a URL, so those only count toward iconsMissed.
function cellImageUrl(x, fx) {
  const m = String(fx || "").match(/^=IMAGE\(\s*"([^"]+)"/i);
  if (m) return m[1];
  if (x && typeof x === "object" && x.getContentUrl) { try { return x.getContentUrl() || x.getUrl() || ""; } catch (e) { return x.getUrl ? x.getUrl() || "" : ""; } }
  return /^https?:\/\/\S+$/.test(String(x)) ? String(x) : "";
}

// Every picture on the チャンドゥ tab below the header row (put in the アイコン column, like the キャラクター tab), top to bottom.
function readChandu(sh) {
  const out = [];
  if (!sh || sh.getLastRow() < 2) return out;
  const r = sh.getDataRange(), v = r.getValues(), f = r.getFormulas();
  for (let i = 1; i < v.length; i++) v[i].forEach((x, j) => { const u = cellImageUrl(x, f[i][j]); if (u) out.push(u); });
  sh.getImages().forEach((im) => { let u = ""; try { u = im.getUrl() || ""; } catch (e) {} if (u && im.getAnchorCell().getRow() > 1) out.push(u); });
  return out;
}

function readIcons(sh) {
  const out = {};
  let missed = 0;
  if (!sh || sh.getLastRow() < 2) return { icons: out, iconsMissed: 0 };
  const r = sh.getDataRange(), v = r.getValues(), f = r.getFormulas(), h = v[0].map(String);
  for (let i = 1; i < v.length; i++) h.forEach((c, j) => {
    const k = c.match(/^アイコン(\d*)$/); if (!k) return;
    const ni = h.indexOf(k[1] ? "キャラクター" + k[1] : "なまえ"), name = ni >= 0 ? String(v[i][ni]).trim() : "";
    if (!name || out[name]) return;
    const u = cellImageUrl(v[i][j], f[i][j]); if (u) out[name] = u;
  });
  sh.getImages().forEach((im) => {
    const a = im.getAnchorCell(), col = h[a.getColumn() - 1] || "", k = col.match(/^アイコン(\d*)$/);
    if (!k || a.getRow() < 2) return;
    const ni = h.indexOf(k[1] ? "キャラクター" + k[1] : "なまえ"), name = ni >= 0 ? String(v[a.getRow() - 1][ni]).trim() : "";
    let u = ""; try { u = im.getUrl() || ""; } catch (e) {}
    if (name && !out[name]) { if (u) out[name] = u; else missed++; }
  });
  return { icons: out, iconsMissed: missed };
}

// A picture can be longer than one cell allows (50,000 characters), so it is split across columns C, D, E…
function readImages(ss) {
  const sh = ss.getSheetByName(IMG), out = {};
  if (!sh || sh.getLastRow() < 2) return out;
  sh.getDataRange().getValues().slice(1).forEach((r) => { if (r[0]) out[r[0]] = r.slice(2).join(""); });
  return out;
}

function saveImage(ss, name, data) {
  if (!name) return { ok: false, error: "no name" };
  let sh = ss.getSheetByName(IMG);
  if (!sh) { sh = ss.insertSheet(IMG); sh.appendRow(["なまえ", "こうしん", "がぞう（データ）"]); }
  const names = sh.getRange(1, 1, sh.getLastRow(), 1).getValues().map((r) => r[0]);
  let row = names.indexOf(name) + 1;
  if (!data) { if (row > 1) sh.deleteRow(row); return { ok: true }; }
  const parts = data.match(/[\s\S]{1,45000}/g), w = 2 + parts.length;
  if (sh.getMaxColumns() < w) sh.insertColumnsAfter(sh.getMaxColumns(), w - sh.getMaxColumns());
  if (row < 2) row = sh.getLastRow() + 1;
  sh.getRange(row, 1, 1, sh.getMaxColumns()).clearContent();
  sh.getRange(row, 1, 1, w).setValues([[name, new Date()].concat(parts)]);
  return { ok: true };
}

function saveRows(sh, rows, key) {
  if (!sh) return { ok: false, error: "no tab" };
  const v = sh.getDataRange().getValues(), h = v[0], ki = h.indexOf(key);
  rows.forEach((r) => {
    Object.keys(r).forEach((c) => { if (h.indexOf(c) < 0) { h.push(c); sh.getRange(1, h.length).setValue(c); } });
    const i = v.findIndex((x, j) => j > 0 && String(x[ki]) === String(r[key]));
    const line = h.map((c, ci) => (c in r ? r[c] : i > 0 ? (v[i][ci] ?? "") : ""));
    if (i > 0) { sh.getRange(i + 1, 1, 1, h.length).setValues([line]); v[i] = line; }
    else { sh.appendRow(line); v.push(line); }
  });
  return { ok: true, rows: rows.length };
}

function json(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

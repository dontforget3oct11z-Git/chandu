// チャンドゥの大冒険: スプレッドシートと アプリを つなぐ Apps Script
// シートの「拡張機能 → Apps Script」に まるごと はりつけて、ウェブアプリとして デプロイします。
//   GET  … エリア / キャラクター / はいけい の 3つの シートと、キャラの がぞうを JSONで かえす
//          キャラクター シートの アイコン欄に いれた がぞう（セル内の がぞう / =IMAGE("URL")）も icons で かえす
//          「アイコン」シートの がぞうは キャラクター シートの おなじ なまえの アイコン欄にも コピーする
//          「チャンドゥ」シートに ならべた がぞうは chandu（リスト）で かえす。アプリが ランダムに つかう
//   POST … {op:"image", name, data}            キャラの がぞうを「がぞう」シートに しまう（data が からなら けす）
//          {op:"rows", tab, rows:[{No:…, 列名:値}]}  No が おなじ ぎょうを うわがき（なければ ついか）
//          {op:"tab", tab, values:[[…],[…]]}     シートを まるごと いれかえる
//          {op:"chanduImages", data:["data:image/jpeg;base64,…"]}  チャンドゥ シートの アイコン欄の あいている ところに じゅんに いれる
const IMG = "がぞう";
const ICONS = "アイコン";   // one row per character: put its picture in the アイコン column
const CHANDU = "チャンドゥ";
const TABS = { areas: "エリア", chars: "キャラクター", bgs: "はいけい" };

function doGet() {
  const ss = SpreadsheetApp.getActive(), out = {};
  try { out.iconsSynced = syncIcons(ss); } catch (e) { out.iconsSynced = "error: " + e.message; }
  Object.keys(TABS).forEach((k) => (out[k] = readTab(ss.getSheetByName(TABS[k]))));
  out.images = readImages(ss);
  const a = readIcons(ss.getSheetByName(TABS.chars)), b = readIcons(ss.getSheetByName(ICONS));
  out.icons = Object.assign(a.icons, b.icons); out.iconsMissed = a.iconsMissed + b.iconsMissed;
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
    if (b.op === "chanduImages") return json(addChanduImages(ss, b.data || []));
    if (b.op === "rows") return json(saveRows(ss.getSheetByName(b.tab), b.rows || [], b.key || "No"));
    if (b.op === "tab") {
      const sh = ss.getSheetByName(b.tab) || ss.insertSheet(b.tab);
      sh.clearContents();
      const w = Math.max(...b.values.map((r) => r.length));
      const vals = b.values.map((r) => r.concat(Array(w - r.length).fill("")));
      if (sh.getMaxColumns() < w) sh.insertColumnsAfter(sh.getMaxColumns(), w - sh.getMaxColumns());
      if (sh.getMaxRows() < vals.length) sh.insertRowsAfter(sh.getMaxRows(), vals.length - sh.getMaxRows());
      sh.getRange(1, 1, vals.length, w).setValues(vals);
      if (b.tab === TABS.chars) { forgetSync(); syncIcons(ss); }
      return json({ ok: true, rows: vals.length });
    }
    return json({ ok: false, error: "unknown op" });
  } finally {
    lock.releaseLock();
  }
}

// Pictures put in the アイコン tab are copied into the matching アイコン cells of the キャラクター tab
// (same name in the キャラクター column next to it). Runs when the app reads the sheet, when the アイコン tab is
// edited, and from the 🐯チャンドゥ menu. Each copied cell remembers name + picture, so it is copied only once.
function syncIcons(ss) {
  const src = ss.getSheetByName(ICONS), dst = ss.getSheetByName(TABS.chars);
  if (!src || !dst || src.getLastRow() < 2 || dst.getLastRow() < 2) return 0;
  const sr = src.getDataRange(), sv = sr.getValues(), sf = sr.getFormulas(), sh = sv[0].map(String);
  const ni = sh.indexOf("キャラクター"), ii = sh.indexOf("アイコン"), want = {};
  if (ni < 0 || ii < 0) return 0;
  for (let i = 1; i < sv.length; i++) {
    const name = String(sv[i][ni]).trim(), u = cellImageUrl(sv[i][ii], sf[i][ii]);
    if (name && u && !want[name]) want[name] = { row: i + 1, tag: name + "|" + hash(u) };
  }
  const dv = dst.getDataRange().getDisplayValues(), dh = dv[0].map(String);
  const props = PropertiesService.getScriptProperties(), done = props.getProperties(), put = {};
  dh.forEach((c, j) => {
    const k = c.match(/^アイコン(\d*)$/); if (!k) return;
    const nj = k[1] ? dh.indexOf("キャラクター" + k[1]) : dh.indexOf("キャラクター"); if (nj < 0) return;
    for (let i = 1; i < dv.length; i++) {
      const w = want[String(dv[i][nj]).trim()], key = "s:" + (i + 1) + ":" + (j + 1);
      if (!w || done[key] === w.tag) continue;
      src.getRange(w.row, ii + 1).copyTo(dst.getRange(i + 1, j + 1));
      put[key] = w.tag;
    }
  });
  if (Object.keys(put).length) props.setProperties(put);
  return Object.keys(put).length;
}

function forgetSync() {
  const props = PropertiesService.getScriptProperties();
  Object.keys(props.getProperties()).forEach((k) => { if (k.startsWith("s:")) props.deleteProperty(k); });
}

function hash(t) { let h = 0; for (let i = 0; i < t.length; i++) h = (h * 31 + t.charCodeAt(i)) | 0; return (h >>> 0).toString(36); }

function onEdit(e) {
  if (e && e.range && e.range.getSheet().getName() === ICONS) syncIcons(e.source);
}

function onOpen() {
  SpreadsheetApp.getUi().createMenu("🐯チャンドゥ").addItem("アイコンをキャラクタータブに反映", "syncNow").addToUi();
}

function syncNow() {
  const n = syncIcons(SpreadsheetApp.getActive());
  SpreadsheetApp.getActive().toast(n + "か所に アイコンを はりました", "チャンドゥ");
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

// Pictures sent as data URLs go, in order, into the チャンドゥ tab's アイコン cells that hold no picture yet
// (an emoji or nothing); new rows are added below when the list runs out.
function addChanduImages(ss, data) {
  const sh = ss.getSheetByName(CHANDU);
  if (!sh) return { ok: false, error: "no チャンドゥ tab" };
  const h = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0].map(String), ic = h.indexOf("アイコン") + 1;
  if (ic < 1) return { ok: false, error: "no アイコン column" };
  const last = sh.getLastRow(), r = last > 1 ? sh.getRange(2, 1, last - 1, sh.getLastColumn()) : null;
  const v = r ? r.getValues() : [], f = r ? r.getFormulas() : [], free = [];
  v.forEach((row, i) => { if (!cellImageUrl(row[ic - 1], f[i][ic - 1])) free.push(i + 2); });
  let next = last + 1, n = 0, no = v.reduce((m, row) => Math.max(m, Number(row[0]) || 0), 0);
  const errors = [];
  data.forEach((d, k) => {
    const row = free.length ? free.shift() : next++;
    try {
      const img = SpreadsheetApp.newCellImage().setSourceUrl(d).setAltTextTitle("チャンドゥ").build();
      if (row > last) sh.getRange(row, 1, 1, Math.max(2, ic - 1)).setValues([[++no, "チャンドゥ"].concat(Array(Math.max(0, ic - 3)).fill(""))]);
      sh.getRange(row, ic).setValue(img); n++;
    } catch (e) { errors.push((k + 1) + ": " + e.message); }
  });
  return { ok: !errors.length, added: n, errors };
}

function readIcons(sh) {
  const out = {};
  let missed = 0;
  if (!sh || sh.getLastRow() < 2) return { icons: out, iconsMissed: 0 };
  const r = sh.getDataRange(), v = r.getValues(), f = r.getFormulas(), h = v[0].map(String);
  for (let i = 1; i < v.length; i++) h.forEach((c, j) => {
    const k = c.match(/^アイコン(\d*)$/); if (!k) return;
    const ni = k[1] ? h.indexOf("キャラクター" + k[1]) : Math.max(h.indexOf("なまえ"), h.indexOf("キャラクター")), name = ni >= 0 ? String(v[i][ni]).trim() : "";
    if (!name || out[name]) return;
    const u = cellImageUrl(v[i][j], f[i][j]); if (u) out[name] = u;
  });
  sh.getImages().forEach((im) => {
    const a = im.getAnchorCell(), col = h[a.getColumn() - 1] || "", k = col.match(/^アイコン(\d*)$/);
    if (!k || a.getRow() < 2) return;
    const ni = k[1] ? h.indexOf("キャラクター" + k[1]) : Math.max(h.indexOf("なまえ"), h.indexOf("キャラクター")), name = ni >= 0 ? String(v[a.getRow() - 1][ni]).trim() : "";
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
    if (i < 0) { const line = h.map((c) => (c in r ? r[c] : "")); sh.appendRow(line); v.push(line); return; }
    // Only the given cells are written, in runs of neighbouring columns, so pictures in other cells stay put.
    const cols = Object.keys(r).map((c) => h.indexOf(c)).sort((a, b) => a - b);
    if (sh.getName() === TABS.chars) cols.forEach((ci) => { if (/^アイコン/.test(h[ci])) PropertiesService.getScriptProperties().deleteProperty("s:" + (i + 1) + ":" + (ci + 1)); });
    for (let s = 0; s < cols.length;) {
      let e = s; while (e + 1 < cols.length && cols[e + 1] === cols[e] + 1) e++;
      sh.getRange(i + 1, cols[s] + 1, 1, e - s + 1).setValues([cols.slice(s, e + 1).map((ci) => r[h[ci]])]);
      s = e + 1;
    }
  });
  return { ok: true, rows: rows.length };
}

function json(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

#!/usr/bin/env python3
"""Build src/jp-muni-items.json (code -> [item name, emoji, words]) from tools/muni-items.tsv.
The TSV has one line per municipality: code, item name, emoji, words."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
items = {}
for line in (root / "tools/muni-items.tsv").read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    code, name, emoji, words = line.split("\t")
    items[code] = [name, emoji, words]
(root / "src/jp-muni-items.json").write_text(json.dumps(items, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(len(items), "items")

# each charm's own drawing: tools/muni-art.jsonl has {"c": code, "s": inner SVG (64×64)} per line
art = {}
for line in (root / "tools/muni-art.jsonl").read_text(encoding="utf-8").splitlines():
    if line.strip():
        r = json.loads(line)
        art[r["c"]] = r["s"]
(root / "src/jp-muni-art.json").write_text(json.dumps(art, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(len(art), "drawings")

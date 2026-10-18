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

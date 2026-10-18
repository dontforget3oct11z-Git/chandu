#!/usr/bin/env python3
"""Builds src/jp-muni.json (Japan's municipalities for the ごとうちカード) from the
smartnews-smri/japan-topography TopoJSON (1% simplified), which is made from
国土数値情報（行政区域データ）, 国土交通省.

usage: python3 tools/make-muni.py N03-21_210101.json src/jp-muni.json
"""
import json, sys

src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src, encoding="utf-8"))
geoms = list(d["objects"].values())[0]["geometries"]
arcs = d["arcs"]

# absolute quantized points of every arc, for the bounding boxes
absarcs = []
for a in arcs:
    x = y = 0; pts = []
    for dx, dy in a:
        x += dx; y += dy; pts.append((x, y))
    absarcs.append(pts)

NORTHERN = {"01695", "01696", "01697", "01698", "01699", "01700"}   # 北方領土: can't be visited
rows = []
for g in geoms:
    p = g["properties"]; code = p["N03_007"]
    if not code or code in NORTHERN: continue
    city, town = p["N03_003"] or "", p["N03_004"] or ""
    name = city + town if city.endswith("市") and town.endswith("区") else (town or city)
    polys = g["arcs"] if g["type"] == "MultiPolygon" else [g["arcs"]]
    xs, ys = [], []
    for poly in polys:
        for ring in poly:
            for i in ring:
                for x, y in absarcs[i if i >= 0 else ~i]:
                    xs.append(x); ys.append(y)
    rows.append([code, p["N03_001"], name, [min(xs), min(ys), max(xs), max(ys)], polys])

rows.sort(key=lambda r: r[0])
json.dump({"credit": "「国土数値情報（行政区域データ）」（国土交通省）を加工（smartnews-smri/japan-topography）",
           "t": d["transform"]["scale"] + d["transform"]["translate"], "arcs": arcs, "m": rows},
          open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(rows), "municipalities")

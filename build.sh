#!/bin/sh
# Wraps src/chandu.html (the game, also published as the claude.ai artifact) into a full page for
# GitHub Pages (docs/index.html) and for the copy bundled inside the iPhone app.
set -e
cd "$(dirname "$0")"
HEAD='<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="チャンドゥ"><meta name="apple-mobile-web-app-status-bar-style" content="default"><meta name="theme-color" content="#f3e9dc"><link rel="apple-touch-icon" href="icon-180.png"><link rel="icon" href="icon-180.png"><link rel="manifest" href="manifest.webmanifest"><style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;-webkit-tap-highlight-color:transparent}img{max-width:100%}[hidden]{display:none!important}</style></head><body>'
{ echo "$HEAD"; cat src/chandu.html; echo '</body></html>'; } > docs/index.html
cp docs/index.html ios/Chandu/Chandu/chandu.html
echo "built docs/index.html and ios/Chandu/Chandu/chandu.html"

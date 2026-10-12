#!/bin/sh
# Wraps src/chandu.html (the game, also published as the claude.ai artifact) into a full page for
# GitHub Pages (docs/index.html) and for the copy bundled inside the iPhone app.
# docs/test.html is the same game in test mode (mini games cost no energy, separate save); it is not in the app.
set -e
cd "$(dirname "$0")"
HEAD='<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="チャンドゥ"><meta name="apple-mobile-web-app-status-bar-style" content="default"><meta name="theme-color" content="#f3e9dc"><link rel="apple-touch-icon" href="icon-180.png"><link rel="icon" href="icon-180.png"><link rel="manifest" href="manifest.webmanifest"><style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;-webkit-tap-highlight-color:transparent}img{max-width:100%}[hidden]{display:none!important}</style></head><body>'
{ echo "$HEAD"; cat src/chandu.html; echo '</body></html>'; } > docs/index.html
cp docs/index.html ios/Chandu/Chandu/chandu.html
TEST_HEAD='<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="robots" content="noindex"><title>チャンドゥ ミニゲーム テスト</title><link rel="icon" href="icon-180.png"><style>body{margin:0;-webkit-tap-highlight-color:transparent}img{max-width:100%}[hidden]{display:none!important}body{padding-top:44px!important}.test-banner{position:fixed;top:0;left:0;right:0;z-index:20;background:#3b4a2a;color:#fff8ef;font:700 13px/1.5 "Zen Maru Gothic","Hiragino Maru Gothic ProN",sans-serif;text-align:center;padding:8px 16px}</style><script>window.CHANDU_TEST=true</script></head><body><div class="test-banner">🧪 テスト画面: ミニゲームで げんきが へりません（本番の データには えいきょう なし）</div>'
{ echo "$TEST_HEAD"; cat src/chandu.html; echo '</body></html>'; } > docs/test.html
echo "built docs/index.html, docs/test.html and ios/Chandu/Chandu/chandu.html"

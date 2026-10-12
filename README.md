# チャンドゥ育成

シンドバッドの相棒、トラの子チャンドゥを育てるゲームです。歩いた歩数でバナナが集まります。

- Web版（GitHub Pages）: https://dontforget3oct11z-git.github.io/chandu/
- iPhoneアプリ版: `ios/Chandu/Chandu.xcodeproj`（歩数がリアルタイムで入ります）

## しくみ

| 場所 | 中身 |
| --- | --- |
| `src/chandu.html` | ゲーム本体。ここを直します |
| `build.sh` | `src/chandu.html` から `docs/index.html`（Web版）とアプリ同梱版を作ります |
| `docs/` | GitHub Pages で公開されるWeb版 |
| `ios/Chandu/` | iPhoneアプリ（SwiftUI）。起動するたびに Web版を読み込むので、ゲームの更新は入れ直さなくても届きます。電波がないときは最後に読み込んだ版で動きます |

ゲーム（`src/chandu.html`）の変更は、`main` に入って GitHub Pages が更新されると、アプリを次に開いたときに反映されます。
Swift のファイルを変えたときだけ、Mac の Xcode からもう一度 ▶︎ で入れ直してください。

## 最初に一度だけ: GitHub Pages を有効にする

1. このリポジトリの「Settings」→ 左の「Pages」
2. 「Build and deployment」の Source を「Deploy from a branch」にする
3. Branch を `main`、フォルダを `/docs` にして「Save」
4. 1〜2分後、上の Web版のアドレスで開けるようになります

## iPhoneアプリを入れる（自分・家族・友だち）

必要なもの: Mac（Xcode）、iPhone、Apple ID（無料）

1. このリポジトリを「Code」→「Download ZIP」で Mac に保存して展開
2. `ios/Chandu/Chandu.xcodeproj` をダブルクリックして Xcode で開く
3. 左の「Chandu」→「Signing & Capabilities」で、Team に**その人の** Apple ID（Personal Team）を選ぶ
4. Bundle Identifier の末尾をその人用に変える（例: `io.github.dontforget3oct11z.chandu.tanaka`）
5. iPhone をケーブルでつなぎ、上部の実行先でその iPhone を選んで ▶︎
6. iPhone の「設定」→「一般」→「VPNとデバイス管理」で開発元を「信頼」
7. 初回は「設定」→「プライバシーとセキュリティ」→「デベロッパモード」をオンにする必要があります

### 7日ごとの入れ直し（ケーブルなし）

無料の Apple ID で入れたアプリは7日で開けなくなります（データは消えません）。

1. 一度ケーブルでつないだ状態で、Xcode の「Window」→「Devices and Simulators」を開く
2. その iPhone の「Connect via network」にチェック
3. 以後は Mac と iPhone が同じ Wi‑Fi にあれば、Xcode で ▶︎ を押すだけで入れ直せます

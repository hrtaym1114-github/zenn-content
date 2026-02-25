---
title: "【2026年最新】Playwright CLIでAIエージェントのブラウザ操作を4倍効率化する完全ガイド"
emoji: "🎭"
type: "tech"
topics: ["Playwright", "CLI", "AI", "ClaudeCode", "BrowserAutomation"]
published: false
---

## この記事で分かること

AIコーディングエージェント（Claude Code、GitHub Copilot、Cursorなど）でブラウザを操作するとき、**トークン消費が爆発する**問題に悩んでいませんか？

2026年初頭、Microsoftが公開した `@playwright/cli` は、従来のPlaywright MCPサーバーと比べて**トークン消費を最大4倍削減**する、AIエージェント特化型のブラウザ自動化ツールです。

この記事では以下を解説します：

- `@playwright/cli` の仕組みと従来CLIとの違い
- MCPサーバーとのトークン消費量の比較（実測データ付き）
- インストールから実践的なワークフローまでの手順
- Claude Codeなどのコーディングエージェントとの統合方法

:::message
**対象読者**: AIコーディングエージェントを日常的に使用している中級以上の開発者。Playwright自体の基礎知識がある方を想定しています。
:::

## Playwright CLIは「2つ」ある

まず混乱しやすいポイントを整理します。2026年現在、「Playwright CLI」と言ったとき、**2つの異なるツール**が存在します。

### 1. `npx playwright` — テスト実行CLI（従来版）

Playwright Test に同梱されているCLIで、E2Eテストの実行・デバッグ・コード生成に使います。

```bash
npx playwright test              # テスト実行
npx playwright test --headed     # ブラウザを表示して実行
npx playwright codegen           # テストコード自動生成
npx playwright show-report       # HTMLレポート表示
```

**用途**: 人間がテストを書き、CIで実行する従来のワークフロー。

### 2. `playwright-cli` — AIエージェント向けCLI（新版）

`@playwright/cli` パッケージとしてnpmに公開されている**AIコーディングエージェント特化型**のブラウザ制御ツール。

```bash
playwright-cli open https://example.com   # ブラウザを開く
playwright-cli snapshot                    # ページ状態をYAMLで保存
playwright-cli click e255                  # 要素をクリック
playwright-cli screenshot                  # スクリーンショット保存
```

**用途**: AIエージェントがBashツール経由でブラウザを操作する。トークン効率を最大化。

:::message alert
この記事では主に **2.の`@playwright/cli`（AI-native版）** を解説します。従来の`npx playwright`テストCLIについても後半で触れます。
:::

## なぜ `@playwright/cli` が必要なのか

### MCPサーバーの「トークン問題」

Playwright MCPサーバー（`@playwright/mcp`）はModel Context Protocolに準拠したブラウザ自動化サーバーです。Claude DesktopやCursorから使えて便利ですが、構造的な問題を抱えています。

**問題1: ツールスキーマが巨大**

MCPは26以上のブラウザ操作ツールを公開し、それぞれにJSON Schemaが定義されています。セッション開始時にこれらすべてがLLMのコンテキストに読み込まれ、**それだけで約3,600トークンを消費**します。

**問題2: レスポンスが冗長**

MCPのレスポンスには、アクセシビリティツリー全体やコンソールログ、スクリーンショットのバイナリデータがインラインで含まれます。1回の操作ごとにコンテキストが膨らみ、長いセッションでは**コンテキスト崩壊**（context collapse）が起きます。

### CLI の解決策：「ディスクに保存、必要なときだけ読む」

`@playwright/cli` は根本的に異なるアプローチを取ります：

```
MCP: ブラウザ状態 → LLMコンテキストに直接注入
CLI: ブラウザ状態 → ディスクに保存 → エージェントが必要な部分だけ読む
```

スナップショットはYAMLファイルとしてディスクに保存され、スクリーンショットはPNGファイルとして保存されます。LLMのコンテキストに直接流れ込むデータは「ファイルパス」だけです。

## トークン消費量の実測比較

### ベンチマーク結果

Playwright公式チームおよび複数の独立ベンチマークで、同一タスクに対するトークン消費量が比較されています。

**Playwrightチーム公式ベンチマーク（同一タスクでの比較）:**

| 指標 | CLI | MCP | 削減率 |
|------|-----|-----|--------|
| ツールスキーマ初期コスト | 約68トークン | 約3,600トークン | **53倍** |
| 典型的なタスク全体 | 約27,000トークン | 約114,000トークン | **4.2倍** |

**Better Stackによる独立ベンチマーク（動画ダウンロードワークフロー）:**

| 指標 | CLI | MCP | 備考 |
|------|-----|-----|------|
| コンテキスト使用率 | 16%（約32k/200k） | 18%（35k/200k） | MCPはスクリーンショット取得に失敗（タスク部分失敗） |

注目すべきは、MCPが18%のコンテキストを消費しながら**タスクが部分的に失敗**している点です。CLIは16%で**タスクを完遂**しており、単純な数値以上の差があります。

### なぜここまで差がつくのか

1. **スキーマコストの差**: CLIはBashツール経由で`--help`を呼ぶだけ（約68トークン）。MCPは26個のツール定義をすべてロード（3,600トークン）
2. **データの扱い**: CLIはファイルパスを返す。MCPはデータ本体を返す
3. **累積効果**: 長いセッションほど差が開く。MCPは操作のたびにコンテキストが膨張する

:::message
MCPの3,600トークンのツールスキーマは、セッション開始時に一度ロードされた後、**コンテキストウィンドウに常駐し続けます**。ステートレスなLLM APIでは毎回のAPIコールにこのコストが含まれるため、セッションが長くなるほど影響が累積します。CLIはこのオーバーヘッドがないため、残りのコンテキストをコード生成やファイル操作に充てられます。
:::

## インストールとセットアップ

### 前提条件

- Node.js 18以上

### グローバルインストール

```bash
npm install -g @playwright/cli@latest
playwright-cli --version
```

### ローカル（npx経由）

```bash
npx @playwright/cli open https://example.com
```

### ブラウザのインストール

```bash
playwright-cli install
```

### スキルのインストール（Claude Code/Copilot連携）

```bash
playwright-cli install --skills
```

これにより、Claude CodeやGitHub Copilotがローカルにインストールされたスキルを自動検出し、`playwright-cli`コマンドを適切に使えるようになります。

## 設定ファイル

`.playwright/cli.config.json` に設定を保存できます：

```json
{
  "browser": {
    "browserName": "chromium",
    "launchOptions": {
      "headless": true
    },
    "contextOptions": {}
  },
  "outputDir": "output",
  "testIdAttribute": "data-testid",
  "timeouts": {
    "action": 5000,
    "navigation": 60000
  }
}
```

`--config` フラグで任意のパスを指定することも可能です：

```bash
playwright-cli --config path/to/config.json open example.com
```

## コマンド全体像

`@playwright/cli` は70以上のコマンドを提供します。主要なものをカテゴリ別に整理します。

### ナビゲーション

```bash
playwright-cli open <URL>        # ブラウザを開く（--headedで表示）
playwright-cli goto <URL>        # URLに遷移
playwright-cli go-back            # 戻る
playwright-cli go-forward         # 進む
playwright-cli reload             # リロード
playwright-cli close              # ページを閉じる
```

### ページ状態の取得

```bash
playwright-cli snapshot           # ページ状態をYAML形式で保存
playwright-cli screenshot [ref]   # スクリーンショットをPNGで保存
playwright-cli pdf [--filename]   # PDFとして保存
```

### 要素操作

```bash
playwright-cli click <ref>       # クリック
playwright-cli fill <ref> <text> # フォーム入力
playwright-cli type <text>       # テキスト入力（フォーカス要素）
playwright-cli select <ref> <val># ドロップダウン選択
playwright-cli check <ref>       # チェックボックスON
playwright-cli uncheck <ref>     # チェックボックスOFF
playwright-cli hover <ref>       # ホバー
playwright-cli drag <from> <to>  # ドラッグ＆ドロップ
playwright-cli upload <file>     # ファイルアップロード
```

### キーボード・マウス

```bash
playwright-cli press <key>       # キー押下（Enter, Tab等）
playwright-cli keydown <key>     # キー押し続け
playwright-cli keyup <key>       # キー離す
playwright-cli mousemove <x> <y> # マウス移動
playwright-cli mousewheel <dx> <dy> # スクロール
```

### タブ管理

```bash
playwright-cli tab-list          # タブ一覧
playwright-cli tab-new [url]     # 新しいタブ
playwright-cli tab-close [index] # タブを閉じる
playwright-cli tab-select <idx>  # タブ切り替え
```

### ストレージ操作

```bash
playwright-cli state-save <file>      # 認証状態を保存
playwright-cli state-load <file>      # 認証状態を復元
playwright-cli cookie-list             # Cookie一覧
playwright-cli cookie-set <name> <val> # Cookie設定
playwright-cli cookie-clear            # Cookie全削除
playwright-cli localstorage-get <key>  # localStorage取得
playwright-cli localstorage-set <k> <v># localStorage設定
```

### ネットワーク・DevTools

```bash
playwright-cli route <pattern>   # リクエストのモック
playwright-cli network           # HTTPリクエスト一覧
playwright-cli console [level]   # コンソールメッセージ表示
playwright-cli tracing-start     # トレース記録開始
playwright-cli tracing-stop      # トレース記録終了
playwright-cli video-start       # 動画記録開始
playwright-cli video-stop        # 動画記録終了
```

### セッション管理

```bash
playwright-cli list              # 全セッション表示
playwright-cli -s=<name> open    # 名前付きセッション
playwright-cli close-all         # 全セッション終了
playwright-cli show              # ビジュアルダッシュボード
```

## 実践ワークフロー：TodoMVCアプリ

実際にTodoMVCアプリを操作する流れを見てみましょう。

### ステップ1: ブラウザを開いてスナップショットを取得

```bash
playwright-cli open https://demo.playwright.dev/todomvc/ --headed
playwright-cli snapshot
# → .playwright-cli/page-2026-02-25T10-30-00-000Z.yml
```

### ステップ2: YAMLスナップショットの中身

スナップショットは以下のような構造のYAMLファイルです：

```yaml
# 要素ごとにコンパクトなリファレンスIDが割り振られる
- ref: e8
  role: textbox
  name: "What needs to be done?"
- ref: e21
  role: checkbox
  name: "Toggle Todo"
```

ポイントは、DOMツリー全体ではなく**操作に必要な要素だけがコンパクトに列挙**されることです。各要素には `e8`、`e21` のような短いリファレンスIDが付与されます。

### ステップ3: 操作の実行

```bash
playwright-cli fill e8 "Playwright CLIの記事を書く"
playwright-cli press Enter
playwright-cli fill e8 "ベンチマークを取る"
playwright-cli press Enter
playwright-cli check e21
playwright-cli screenshot
# → .playwright-cli/page-2026-02-25T10-31-15-000Z.png
```

### ステップ4: 結果の確認

AIエージェントは必要に応じてスクリーンショットファイルを読み取り、操作結果を確認します。**不要なら読まない**ことで、トークンを節約できます。

## セッション管理の活用

### 名前付きセッション

複数のコンテキスト（管理画面とユーザー画面など）を並行して操作できます：

```bash
# 管理者セッション
playwright-cli -s=admin open https://app.example.com/admin

# ユーザーセッション
playwright-cli -s=user open https://app.example.com

# セッション一覧
playwright-cli list
```

### 認証状態の永続化

ログインフローを毎回繰り返す必要はありません：

```bash
# ログイン後に状態を保存
playwright-cli state-save logged-in.json

# 次回セッションで復元
playwright-cli state-load logged-in.json
```

### 環境変数でのセッション指定

Claude Codeなどのエージェントで使う場合、環境変数でセッションを固定できます：

```bash
PLAYWRIGHT_CLI_SESSION=my-app claude .
```

## ビジュアルダッシュボード

```bash
playwright-cli show
```

このコマンドでブラウザ上にダッシュボードが開き、実行中の全セッションをグリッドビューで確認できます。各セッションのライブスクリーンキャストが表示され、リモート操作も可能です。

デバッグ時に「今AIエージェントがどのページを見ているか」を人間が確認するのに非常に便利です。

## Playwright MCP vs CLI — どちらを使うべきか

### CLIを選ぶべきケース

- **コーディングエージェント**（Claude Code、Copilot、Cursor）でブラウザを操作する場合
- **トークン効率**が重要（長いセッション、コンテキストウィンドウが限られている）
- シェルスクリプトとの**組み合わせ**が必要（`sleep && playwright-cli screenshot` など）
- 離散的で明確なブラウザタスクを実行する場合
- ファイルシステムへのアクセスがある環境

### MCPを選ぶべきケース

- **サンドボックス環境**（ファイルシステムアクセスがない）
- Claude Desktopなど**MCP対応クライアント**から直接使いたい場合
- 標準化されたプロトコルによる**クロスプラットフォーム対応**が必要
- ステートフルなブラウザセッションを長時間維持する場合

### 判断フローチャート

```
ファイルシステムにアクセスできる？
├── YES → コーディングエージェントで使う？
│   ├── YES → ✅ playwright-cli
│   └── NO → テスト実行？
│       ├── YES → npx playwright test
│       └── NO → ✅ playwright-cli
└── NO → ✅ Playwright MCP
```

## 従来のPlaywright Test CLI（npx playwright）

ここからは従来の `npx playwright` コマンドについても主要な機能を整理します。

### テスト実行

```bash
# 全テスト実行
npx playwright test

# 特定ファイル
npx playwright test tests/login.spec.ts

# 正規表現フィルタ
npx playwright test --grep "カートに追加"

# 特定ブラウザ
npx playwright test --project=chromium

# 並列数制御
npx playwright test --workers=4
```

### デバッグ

```bash
# Playwright Inspectorを起動
npx playwright test --debug

# UIモード（インタラクティブ）
npx playwright test --ui

# トレースを記録
npx playwright test --trace on

# トレースビューア
npx playwright show-trace trace.zip
```

### コード生成（Codegen）

人間がブラウザを操作し、その操作をテストコードとして自動生成する機能です。

```bash
# 基本
npx playwright codegen https://example.com

# デバイスエミュレーション
npx playwright codegen --device="iPhone 13"

# ビューポート指定
npx playwright codegen --viewport-size="800,600"

# 認証状態の保存
npx playwright codegen --save-storage=auth.json github.com

# 保存した認証状態で実行
npx playwright codegen --load-storage=auth.json github.com

# 出力ファイル指定
npx playwright codegen --output tests/generated.spec.ts

# ロケール・タイムゾーン・位置情報のエミュレーション
npx playwright codegen \
  --timezone="Asia/Tokyo" \
  --geolocation="35.6762,139.6503" \
  --lang="ja-JP" \
  maps.google.com
```

### レポーター

```bash
# HTMLレポート
npx playwright test --reporter=html

# 複数レポーター
npx playwright test --reporter=html,list

# レポート表示
npx playwright show-report
```

:::message
`npx playwright codegen` の `--save-storage` で保存したファイルにはCookieやlocalStorageなど**機密情報**が含まれます。`.gitignore`に追加し、テスト完了後は削除してください。
:::

## アンチパターンと注意点

### 1. スナップショットの取りすぎ

```bash
# ❌ 毎操作後にスナップショット
playwright-cli click e10
playwright-cli snapshot    # 本当に必要？
playwright-cli fill e20 "text"
playwright-cli snapshot    # これも本当に必要？

# ✅ 必要なタイミングだけ
playwright-cli click e10
playwright-cli fill e20 "text"
playwright-cli snapshot    # 状態確認が必要なポイントで1回
```

### 2. スクリーンショットのコンテキスト投入

```bash
# ❌ 毎回スクリーンショットをLLMに読ませる
playwright-cli screenshot
cat .playwright-cli/page-*.png  # → トークン爆発

# ✅ 必要なときだけ、かつテキストベースで確認
playwright-cli snapshot  # YAMLで十分なケースが多い
```

### 3. MCPとCLIの混在

1つのエージェントセッションで両方を使うと、セッション管理が複雑になり、予期しない動作を招きます。**どちらか一方に統一**してください。

## まとめ

- `@playwright/cli` は2026年にMicrosoftが公開した、**AIコーディングエージェント特化型**のブラウザ自動化CLI
- 従来のPlaywright MCPと比べて**トークン消費を約4倍削減**（114kトークン → 27kトークン）
- 「ディスクに保存、必要なときだけ読む」アーキテクチャにより、コンテキストウィンドウを圧迫しない
- `snapshot` コマンドがYAMLベースの要素リファレンスを生成し、`e255` のようなコンパクトなIDで操作可能
- セッション管理、認証永続化、ビジュアルダッシュボードなど実用的な機能も充実
- Claude Code、GitHub Copilot、Cursorなどのコーディングエージェントとシームレスに統合

## 参考リンク

- [microsoft/playwright-cli — GitHub](https://github.com/microsoft/playwright-cli)
- [@playwright/cli — npm](https://www.npmjs.com/package/@playwright/cli)
- [Playwright公式ドキュメント — Command line](https://playwright.dev/docs/test-cli)
- [Playwright CLI: The Token-Efficient Alternative — TestCollab](https://testcollab.com/blog/playwright-cli)
- [Deep Dive into Playwright CLI — TestDino](https://testdino.com/blog/playwright-cli/)
- [Playwright CLI vs. MCP — Better Stack](https://betterstack.com/community/guides/ai/playwright-cli-vs-mcp-browser/)
- [Test generator — Playwright公式](https://playwright.dev/docs/codegen)

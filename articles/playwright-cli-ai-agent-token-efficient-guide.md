---
title: "【実測検証】Playwright CLI vs MCP — AIエージェントのトークン効率が良いのはどちらか"
emoji: "🎭"
type: "tech"
topics: ["Playwright", "CLI", "AI", "ClaudeCode", "MCP"]
published: true
---

## この記事で分かること

AIコーディングエージェント（Claude Code、GitHub Copilot、Cursorなど）でブラウザを操作するとき、**トークン消費が爆発する**問題に悩んでいませんか？

2026年初頭、Microsoftが公開した `@playwright/cli` は、従来のPlaywright MCPサーバーと比べて**トークン消費を最大4倍削減**するとされています。しかし、**この「4倍」は本当でしょうか？**

本記事では、Claude Code環境で **3シナリオ × 3試行 × 2手法 = 計18セッション** の実測ベンチマークを行い、公式の主張を検証しました。結果は予想外のものでした。

この記事では以下を解説します：

- `@playwright/cli` の仕組みと従来MCPとの設計思想の違い
- 外部ベンチマークの主張とその前提条件
- **Claude Code環境での実測検証の方法と結果**
- なぜ外部ベンチマークと異なる結果になるのか
- `@playwright/cli` のセットアップからコマンドリファレンスまで

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

**用途**: AIエージェントがBashツール経由でブラウザを操作する。トークン効率の最大化を目指す設計。

:::message alert
この記事では主に **2.の`@playwright/cli`（AI-native版）** を解説します。従来の`npx playwright`テストCLIについても後半で触れます。
:::

## なぜ `@playwright/cli` が生まれたのか

### MCPサーバーの構造的な課題

Playwright MCPサーバー（`@playwright/mcp`）はModel Context Protocolに準拠したブラウザ自動化サーバーです。Claude DesktopやCursorから使えて便利ですが、設計上の特徴があります。

**特徴1: ツールスキーマの初期コスト**

MCPは26以上のブラウザ操作ツールを公開し（2026年2月時点では37ツールまで増加）、それぞれにJSON Schemaが定義されています。セッション開始時にこれらすべてがLLMのコンテキストに読み込まれます。このスキーマコストは環境によって大きく異なり、**最小構成で約3,600トークン**、Claude Code環境では**約14,400トークン**（[GitHub Issue #1290](https://github.com/microsoft/playwright-mcp/issues/1290) による報告）に達するケースもあります。

**特徴2: レスポンスがコンテキストに流入**

MCPのレスポンスには、アクセシビリティツリーやコンソールログが含まれます。操作のたびにこれらがコンテキストに蓄積されます。

### CLI の設計思想：「ディスクに保存、必要なときだけ読む」

`@playwright/cli` は根本的に異なるアプローチを取ります：

```
MCP: ブラウザ状態 → LLMコンテキストに直接注入
CLI: ブラウザ状態 → ディスクに保存 → エージェントが必要な部分だけ読む
```

スナップショットはYAMLファイルとしてディスクに保存され、スクリーンショットはPNGファイルとして保存されます。LLMのコンテキストに直接流れ込むデータは「ファイルパス」だけ——という設計思想です。

理論的にはこのアプローチが効率的に見えます。しかし、**実際の環境ではどうでしょうか？**

## 外部ベンチマークの主張

Playwright公式チームおよび複数の独立ベンチマークでは、CLI がMCPより大幅に効率的だと報告されています。

**Playwrightチーム公式ベンチマーク（同一タスクでの比較）:**

| 指標 | CLI | MCP | 削減率 |
|------|-----|-----|--------|
| ツールスキーマ初期コスト | 約68トークン | 約3,600トークン※ | **53倍** |
| 典型的なタスク全体 | 約27,000トークン | 約114,000トークン | **4.2倍** |

**Better Stackによる独立ベンチマーク（動画ダウンロードワークフロー）:**

| 指標 | CLI | MCP | 備考 |
|------|-----|-----|------|
| コンテキスト使用率 | 16%（約32k/200k） | 18%（35k/200k） | MCPはスクリーンショット取得に失敗 |

※MCPのスキーマコスト「約3,600トークン」は最小構成での値です。Claude Code環境では約14,400トークンに達するという報告もあり（[GitHub Issue](https://github.com/microsoft/playwright-mcp/issues/1290)）、クライアントやツール構成によって変動します。

これらのベンチマークは主に**ツールスキーマの初期コスト**に注目しています。CLIはBashツール1個の定義だけで済むのに対し、MCPは26個以上のツール定義をすべてロードする——これが「4倍効率的」の主な根拠です。

しかし、この前提は **MCPサーバーが1つだけ接続された理想環境** での話です。実際のAIコーディングエージェント環境では条件が異なります。

## Claude Code環境での実測検証

### なぜ独自検証が必要か

外部ベンチマークには以下の前提が含まれています：

- MCPサーバーが **Playwright 1つだけ** 接続されている
- Bashツールの **オーバーヘッド** が考慮されていない
- **エージェントの判断コスト**（どのコマンドを叩くかの推論）が含まれていない

実際のClaude Code環境では複数のMCPサーバーが同時接続され、Bashツール呼び出しには pre/post hooks のオーバーヘッドがあり、エージェントは毎回コマンドを組み立てる推論を行います。この差がどう影響するかを確かめるため、実測検証を行いました。

### 計測環境

| 項目 | 値 |
|------|-----|
| Claude Code | v2.1.58 |
| プラン | Claude Max |
| モデル | claude-opus-4-6 |
| OS | macOS Darwin 25.3.0 |
| @playwright/cli | v1.59.0-alpha（グローバルインストール + スキル） |
| @playwright/mcp | latest (stdio via npx) |
| 計測方法 | OpenTelemetry console exporter（デバッグログ内 `claude_code.token.usage`） |
| 計測日 | 2026-02-26〜27 |

### 検証設計

**3つのシナリオ** × **3試行** × **2手法** = **計18セッション** で検証しました。

| シナリオ | 内容 | 操作の複雑さ |
|----------|------|------------|
| Simple | TodoMVCページのUI要素をテキストで報告 | 低（読み取りのみ） |
| Medium | 3つのTodoアイテムを追加して内容を報告 | 中（入力操作あり） |
| Complex | 5つのTodo追加→2つ完了→フィルタ操作→カウント確認 | 高（マルチステップ） |

対象サイトはすべて [TodoMVC](https://demo.playwright.dev/todomvc/)（Playwright公式デモ）です。

**公平性の担保：**

- **ツール分離**: CLI試行は `--disallowedTools "mcp__playwright__*"`、MCP試行は `--disallowedTools "Bash"` で手法の混在を防止
- **実行順序**: CLI→MCP→CLI→MCP…と交互に実行し、順序効果を排除
- **独立セッション**: 各試行は新規セッションで実行（`--resume` 禁止）
- **自動実行**: `--dangerously-skip-permissions` で人間の介入を排除

### トークン計測方法

Claude Maxプランでは `/cost` コマンドが利用できないため、OpenTelemetryによる内部テレメトリを利用しました。

```bash
CLAUDE_CODE_ENABLE_TELEMETRY=1 \
OTEL_METRICS_EXPORTER=console \
OTEL_METRIC_EXPORT_INTERVAL=5000 \
claude --no-chrome --dangerously-skip-permissions
```

この設定で、デバッグログ（`~/.claude/debug/`）に `claude_code.token.usage` メトリクスが記録されます。ここから input / output / cache_read / cache_creation の各トークン数を集計しました。

:::message
**Total tokens の定義**: 本記事では `input + output` の合計をTotal tokensとしています。cache_read / cache_creation はAPI課金には影響しますが、モデルの実質的な入出力量を表す input + output を比較指標として採用しました。
:::

### 結果

#### 全試行の生データ

**Simple: ページ読み取り**

| 試行 | 手法 | Input | Output | Total | ツール回数 | 時間(秒) |
|------|------|------:|-------:|------:|----------:|---------:|
| 1 | CLI | 8,946 | 6,545 | 15,491 | 5 | 53 |
| 2 | CLI | 7,839 | 8,024 | 15,863 | 6 | 54 |
| 3 | CLI | 13,004 | 11,960 | 24,964 | 5 | 69 |
| 1 | MCP | 10,711 | 5,097 | 15,808 | 4 | 55 |
| 2 | MCP | 14,130 | 5,698 | 19,828 | 4 | 59 |
| 3 | MCP | 6,188 | 3,547 | 9,735 | 3 | 44 |

**Medium: フォーム入力**

| 試行 | 手法 | Input | Output | Total | ツール回数 | 時間(秒) |
|------|------|------:|-------:|------:|----------:|---------:|
| 1 | CLI | 36,427 | 24,381 | 60,808 | 10 | 96 |
| 2 | CLI | 27,963 | 18,936 | 46,899 | 12 | 77 |
| 3 | CLI | 122,651 | 66,638 | 189,289 | 13 | 191 |
| 1 | MCP | 6,420 | 9,655 | 16,075 | 8 | 68 |
| 2 | MCP | 348,971 | 81,605 | 430,576 | 4 | 406 |
| 3 | MCP | 22,631 | 8,076 | 30,707 | 4 | 64 |

**Complex: マルチステップ**

| 試行 | 手法 | Input | Output | Total | ツール回数 | 時間(秒) |
|------|------|------:|-------:|------:|----------:|---------:|
| 1 | CLI | 1,514,724 | 881,330 | 2,396,054 | 20 | 1,296 |
| 2 | CLI | 125,301 | 76,382 | 201,683 | 20 | 163 |
| 3 | CLI | 125,199 | 75,544 | 200,743 | 20 | 155 |
| 1 | MCP | 8,646 | 18,780 | 27,426 | 12 | 84 |
| 2 | MCP | 119 | 13,631 | 13,750 | 10 | 73 |
| 3 | MCP | 121 | 16,061 | 16,182 | 9 | 81 |

:::message
外れ値について: cli-complex-trial1（2.4M tokens, 1,296秒）と mcp-medium-trial2（430k tokens, 406秒）は他の試行と大きく乖離しています。中央値を代表値として使用することで、これらの影響を吸収しています。全18試行で**タスク成功率は100%**でした。
:::

#### シナリオ別の中央値比較

| シナリオ | CLI (tokens) | MCP (tokens) | MCP/CLI比率 | CLI (秒) | MCP (秒) |
|----------|------------:|------------:|:-----------:|---------:|---------:|
| Simple | 15,863 | 15,808 | **1.00x** | 54 | 55 |
| Medium | 60,808 | 30,707 | **0.50x** | 96 | 68 |
| Complex | 201,683 | 16,182 | **0.08x** | 163 | 81 |

**全シナリオ中央値：**

| 指標 | CLI | MCP | 比率 |
|------|----:|----:|:----:|
| Total tokens | 60,808 | 16,182 | **0.27x** |
| ツール呼び出し回数 | 12 | 4 | 0.33x |
| 処理時間(秒) | 96 | 73 | 0.76x |

> MCP/CLI比率が1.0未満 = MCPが効率的

:::message alert
**この結果は、外部ベンチマークの「CLIが4倍効率的」という主張と真逆です。** Claude Code環境では、全体中央値で MCPがCLIの約4倍トークン効率が良い（0.27x）という結果になりました。特にComplexシナリオでは **MCPがCLIの約12倍効率的** でした。
:::

### なぜ外部ベンチマークと逆の結果になるのか

#### 1. ツールスキーマのコストが相対的に小さい

外部ベンチマークでは「MCPの26ツール定義 vs CLIの1コマンド」のスキーマコスト差を強調します。しかし、Claude Code環境では他のMCPサーバーも同時に接続されており、ツール定義全体で27,000トークン以上を消費しているケースもあります（[Reddit報告](https://www.reddit.com/r/ClaudeCode/comments/1q35kuo/)）。この中でPlaywright MCPの占める割合は一部に過ぎず、CLIに切り替えても全体への影響は限定的です。

#### 2. CLIはBashツール呼び出しのオーバーヘッドが大きい

CLIは操作ごとにBashツール呼び出しが必要です。各コマンドのstdout出力（ページ状態、スナップショットパス等）が **毎回コンテキストに蓄積** されます。

Complexシナリオでは、CLIは中央値20回のBash呼び出しが発生。一方MCPは10回のツール呼び出しで同じタスクを完了しました。1回のMCPツール呼び出しで複数の操作を効率的にまとめられるのに対し、CLIは `open` → `fill` → `press Enter` → `snapshot` → … と逐次的にコマンドを実行する必要があります。

#### 3. CLIの「必要なときだけ読む」が機能しにくい

CLIの設計思想は「スナップショットをディスクに保存し、必要なときだけ読む」ですが、実際にはエージェントは操作結果を確認するために **ほぼ毎回スナップショットを読みます**。ディスク経由の間接アクセスが、MCPの直接レスポンスと比べてトークン節約につながっていませんでした。

#### 4. セットアップ品質が大きく影響する

初回検証では `npx @playwright/cli` 経由で実行し、CLI試行の **67%でエラー**が発生しました。グローバルインストール + スキル導入後はエラー率0%に改善。**Simpleシナリオで7倍の改善**が得られました。

| セットアップ | Simple中央値 | エラー率 |
|------------|----------:|:------:|
| npx経由（スキルなし） | 111,005 | 67% |
| グローバル+スキル | 15,863 | 0% |
| MCP | 15,808 | 0% |

:::message
**重要**: `@playwright/cli` を使う場合、**npx経由ではなくグローバルインストール + `playwright-cli install --skills` が必須**です。この差だけでSimpleシナリオで7倍の改善が得られます。
:::

### 結局、何がトークン効率を決めるのか

| 要因 | CLI有利 | MCP有利 |
|------|:-------:|:-------:|
| ツールスキーマの初期コスト | ✅ | |
| 操作あたりのコンテキスト蓄積 | | ✅ |
| 長いセッションでの累積コスト | | ✅ |
| 他のMCPサーバーが多い環境 | ✅ | |
| セットアップ不備の影響 | | ✅ |
| 単純な操作（1〜2ステップ） | — | — |
| 複雑な操作（5ステップ以上） | | ✅ |

**操作が複雑になるほどMCPが有利、単純な操作ならほぼ同等** — これが18試行の実測から得られた結論です。

## インストールとセットアップ

ここからは `@playwright/cli` を使うためのセットアップ手順を解説します。前述のとおり、**正しいセットアップがトークン効率を大きく左右**します。

### 前提条件

- Node.js 18以上

### グローバルインストール（推奨）

```bash
npm install -g @playwright/cli@latest
playwright-cli --version
```

:::message alert
**npx経由での実行は非推奨です。** 実測検証で、npx経由はグローバルインストールと比べてSimpleシナリオで7倍のトークンを消費し、67%の試行でエラーが発生しました。必ずグローバルインストールしてください。
:::

### ブラウザのインストール

```bash
playwright-cli install
```

### スキルのインストール（Claude Code/Copilot連携）

```bash
playwright-cli install --skills
```

これにより、Claude CodeやGitHub Copilotがローカルにインストールされたスキルを自動検出し、`playwright-cli`コマンドを適切に使えるようになります。筆者の環境ではプロジェクトの `.claude/skills/playwright-cli/` にスキル定義ファイルが配置されましたが、配置先はバージョンや環境によって異なる可能性があります。`playwright-cli install --skills` 実行時の出力を確認してください。

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

`@playwright/cli` は約66のコマンドを提供します。主要なものをカテゴリ別に整理します。

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

実際にTodoMVCアプリを操作する流れを見てみましょう（今回のベンチマークでも使用したサイトです）。

### ステップ1: ブラウザを開いてスナップショットを取得

```bash
playwright-cli open https://demo.playwright.dev/todomvc/ --headed
playwright-cli snapshot
# → .playwright-cli/page-2026-02-25T10-30-00-000Z.yml
```

### ステップ2: YAMLスナップショットの中身

スナップショットは以下のような構造のYAMLファイルです：

```yaml
- generic [ref=e1]:
  - generic [ref=e2]:
    - text: This is just a demo of TodoMVC for testing, not the
    - link "real TodoMVC app." [ref=e3] [cursor=pointer]
  - generic [ref=e6]:
    - heading "todos" [level=1] [ref=e7]
    - textbox "What needs to be done?" [active] [ref=e8]
  - contentinfo [ref=e9]:
    - paragraph [ref=e10]: Double-click to edit a todo
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

### 実測データに基づく推奨

| ユースケース | 推奨 | 理由 |
|------------|------|------|
| 単純なページ確認（1〜2操作） | **どちらでもOK** | Simple シナリオで差なし（1.00x） |
| フォーム入力・複数操作 | **MCP推奨** | Medium で MCP が2倍効率的 |
| マルチステップの複雑なタスク | **MCP推奨** | Complex で MCP が12倍効率的 |
| ファイルシステムがない環境 | **MCP一択** | CLIはディスク書き込みが前提 |
| MCP非対応のクライアント | **CLI一択** | Bashがあれば使える |

### CLIを選ぶべきケース

- **MCP対応していないクライアント**でブラウザを操作する場合
- ファイルシステムにアクセスでき、Bashが使える環境
- シェルスクリプトとの**組み合わせ**が必要（`sleep && playwright-cli screenshot` など）
- スナップショットYAMLを**他のツールで後処理**したい場合

### MCPを選ぶべきケース

- **Claude Code、Cursor**など MCP対応コーディングエージェントを使う場合
- 複数ステップの複雑なブラウザ操作がメイン
- **トークン効率**を最優先したい場合
- **サンドボックス環境**（ファイルシステムアクセスがない）

### 判断フローチャート

```
MCP対応クライアントで使う？
├── YES → 複雑な操作が多い？
│   ├── YES → ✅ Playwright MCP
│   └── NO → どちらでもOK（好みで選択）
└── NO → ファイルシステムにアクセスできる？
    ├── YES → ✅ playwright-cli
    └── NO → ✅ Playwright MCP（サーバー経由）
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

### 1. npx経由で毎回インストール

```bash
# ❌ 毎回npxでインストールが走る → エラー率67%、トークン7倍消費
npx @playwright/cli open https://example.com

# ✅ グローバルインストール + スキル
npm install -g @playwright/cli@latest
playwright-cli install --skills
playwright-cli open https://example.com
```

### 2. スナップショットの取りすぎ

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

### 3. スクリーンショットのコンテキスト投入

```bash
# ❌ 毎回スクリーンショットをLLMに読ませる
playwright-cli screenshot
cat .playwright-cli/page-*.png  # → トークン爆発

# ✅ 必要なときだけ、かつテキストベースで確認
playwright-cli snapshot  # YAMLで十分なケースが多い
```

### 4. MCPとCLIの混在

1つのエージェントセッションで両方を使うと、セッション管理が複雑になり、予期しない動作を招きます。**どちらか一方に統一**してください。

## まとめ

### 実測から得られた知見

- **外部ベンチマーク「CLI4倍効率」はClaude Code環境では再現しなかった**
- Simple（単純操作）: CLI ≈ MCP（ほぼ同等、差なし）
- Medium（中程度）: MCPがCLIの **2倍** 効率的
- Complex（複雑操作）: MCPがCLIの **12倍** 効率的
- **セットアップが不適切だとCLIのトークン消費が7倍に悪化**する

### Playwright CLI の価値

実測ではMCPが優位でしたが、`@playwright/cli` 自体は優れたツールです：

- 「ディスクに保存、必要なときだけ読む」アーキテクチャは理論的には合理的
- `snapshot` コマンドのYAMLベースの要素リファレンスはコンパクトで使いやすい
- セッション管理、認証永続化、ビジュアルダッシュボードなど実用的な機能が充実
- **MCP非対応環境では唯一の選択肢**

### 推奨

| 状況 | 推奨 |
|------|------|
| Claude Code / Cursor で使う | Playwright MCP |
| MCP非対応クライアントで使う | playwright-cli |
| セットアップする場合 | **必ずグローバルインストール + スキル** |

ベンチマーク結果は環境やタスクによって変わり得ます。本記事の検証が、あなたの環境での最適な選択の一助になれば幸いです。

## 参考リンク

- [microsoft/playwright-cli — GitHub](https://github.com/microsoft/playwright-cli)
- [@playwright/cli — npm](https://www.npmjs.com/package/@playwright/cli)
- [Playwright公式ドキュメント — Command line](https://playwright.dev/docs/test-cli)
- [Playwright CLI: The Token-Efficient Alternative — TestCollab](https://testcollab.com/blog/playwright-cli)
- [Deep Dive into Playwright CLI — TestDino](https://testdino.com/blog/playwright-cli/)
- [Playwright CLI vs. MCP — Better Stack](https://betterstack.com/community/guides/ai/playwright-cli-vs-mcp-browser/)
- [Test generator — Playwright公式](https://playwright.dev/docs/codegen)

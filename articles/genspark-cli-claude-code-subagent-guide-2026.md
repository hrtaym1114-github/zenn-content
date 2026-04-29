---
title: "【2026年最新】Genspark CLI（gsk）完全ガイド — Claw・Web版との違いからClaude Code連携まで"
emoji: "🎼"
type: "tech"
topics: ["genspark", "claudecode", "cli", "ai", "automation"]
published: false
---



![Genspark CLI（gsk）— ターミナル中心に検索・画像・動画・音声・ファクトチェックの5機能が接続される等角投影図](/images/genspark-cli-claude-code-subagent-guide-2026/eyecatch.png)
*アイキャッチ画像も `gsk img -m nano-banana-2` で生成（33.9秒・387KB・16:9）。本記事の主張を自分自身で実証。*

## H2-1. この記事で分かること

Claude Code を使っていて、こんな瞬間ありませんか?

- 「ちょっとWeb検索したい」→ ブラウザを開く
- 「ファクトチェックしたい」→ Perplexityタブに切り替え
- 「アイキャッチ画像が欲しい」→ Midjourney開く
- 「議事録の文字起こし」→ Whisper起動

**これ、全部 `gsk` 1コマンドで片付きます**。

`@genspark/cli`（コマンド名 `gsk`）は、Genspark公式の **「90+ AIツール統合バイナリ」**。日本語圏ではほぼ未認知ですが、`npm i -g @genspark/cli` で入る npm パッケージとして普通に公開されています。

この記事で扱うこと:

- ✅ `gsk`・**Genspark Claw**・**Genspark Web版**の3層の違い（最初に詰まるポイント）
- ✅ インストールから初回認証までの最短ルート
- ✅ 主要コマンド14個（実際は38種類以上）の使い分けマップ
- ✅ Claude Code subagent への組み込み（`.claude/agents/genspark.md` の動くサンプル）
- ✅ `cross_check`（ファクトチェック）の実測データ — **91秒で誤情報を検出**
- ✅ アンチパターン5選

扱わないこと: Web版Gensparkの基本機能（既に解説記事多数）。本記事は **CLIに振り切ります**。

---

## H2-2. ★ 最初の混乱整理 — gsk・Claw・Web版は何が違う?

このツールを触る人がほぼ全員つまずくのがここです。

### 3層の関係図

```
┌─────────────────────────────────────────────────┐
│ Genspark Web版（genspark.ai）                   │
│  └ ブラウザで対話・スライド/Docs作成             │ ← UIが厚い
├─────────────────────────────────────────────────┤
│ Genspark Claw（デスクトップ版）                 │
│  └ ローカルファイル・画面操作・常駐             │ ← AI Secretary
├─────────────────────────────────────────────────┤
│ Genspark CLI（gsk）                              │
│  └ ターミナル・スクリプト統合・JSON-first        │ ← この記事
└─────────────────────────────────────────────────┘
```

### 使い分け表

| 用途 | おすすめ |
|------|---------|
| スライド作成・対話的探索 | **Web版** |
| ローカルファイル + 画面操作 + 常駐AI | **Claw** |
| スクリプト統合・cron・他AIから呼出し | **CLI（gsk）** |

### よくある勘違い

| 勘違い | 正解 |
|--------|------|
| 「`gsk` は Claude Code みたいなコーディングエージェント」 | ❌ 違う。コーディング特化ではなく「90+ツール統合の入口」 |
| 「Web版の機能を全部CLIで再現したもの」 | ❌ 違う。CLIは"ツール叩く側"、Web版は"対話UI" |
| 「Claw = CLI」 | ❌ 違う。Claw はネイティブGUIアプリ、CLIはターミナル |
| 「`gsk` は別のCLIツール（GitHub CLI gsk等）と同じ?」 | ❌ 違う。Genspark専用パッケージ `@genspark/cli` |

ここを誤解したまま検索すると永遠に正しい記事に辿り着きません。**この記事のスコープは一番下の `gsk` だけ** です。

---

## H2-3. 前提知識 / なぜ Claude Code活用者に刺さるのか

Claude Code は強力ですが、標準では次の機能が**ありません**:

- リアルタイムWeb検索（学習カットオフ以降の情報）
- 任意URLからの本文抽出（Web Searchツールはあるが、複数URLバッチ処理は弱い）
- 画像生成
- 動画生成・音声生成・TTS・文字起こし
- ファクトチェック（外部ソース横断検証）
- Gmail / Calendar / Slack / Notion 直接操作

Claude Code の MCP や WebFetch でカバーする方法もありますが、**多くは別契約・別インストール・別認証が必要**。

`gsk` を1本入れるだけで、これらが**1認証・1JSON仕様・1更新サイクル**に統合されます。Claude Code の subagent として呼び出せば、メインエージェントは「ツールが増えた」だけで運用できます。

---

## H2-4. インストールと初回認証

### インストール

```bash
npm install -g @genspark/cli
gsk --version  # 例: 1.0.13
```

Node.js 18+ 推奨。

### 認証

2系統あります。

```bash
# 方式1: ブラウザログイン（個人開発向け）
gsk login

# 方式2: 環境変数（CI・スクリプト向け）
export GSK_API_KEY="gsk_..."
```

ログイン後の確認:

```bash
gsk login-info
# {"data":{"email":"...","plan":"plus"}}
```

設定ファイルは `~/.genspark-tool-cli/config.json` に保存されます。マルチユーザー環境では `chmod 600` を推奨。

### 自動更新を切りたい時

CLIは4時間おきに自動更新します（バージョン固定したいCI環境では困る）。無効化:

```bash
export GSK_NO_AUTO_UPDATE=1
```

または `~/.genspark-tool-cli/config.json` に `"auto_update": false`。

---

## H2-5. 主要サブコマンドの全体像

`gsk --help` から抜粋した主要コマンド:

```
gsk search <q>            Web検索
gsk crawl <url>           ページ本文抽出
gsk summarize <url|file>  大規模文書を解析・要約
gsk img <prompt>          画像生成（16モデル）
gsk video <prompt>        動画生成（14モデル）
gsk audio <prompt>        音声/音楽/SE生成（14モデル）
gsk transcribe <file>     文字起こし（Whisper等）
gsk task <task_type>      AIタスク（cross_check / deep_research / docs / slides 等）
gsk gmail <action>             Gmail操作
gsk google_calendar <action>   Google Calendar操作
gsk outlook_calendar <action>  Outlook Calendar操作
gsk github <action>            GitHub操作
gsk notion <action>       Notion操作
gsk slack <action>        Slack送信
gsk drive <action>        AI Drive
```

JSON出力（デフォルト）なので、すべて `jq` で後段処理できます。なお `gsk --help` で表示される実コマンド数は **38以上**。上記は代表的な14コマンドの抜粋です。

---

## H2-6. ★ Claude Code subagent化する3つのワークフロー

ここからが本題。Claude Code に `gsk` を組み込む実例3パターン。

### パターン1. 最小サブエージェント — 「画像生成だけ」担当

`.claude/agents/genspark-img.md`:

```markdown
---
name: genspark-img
description: 画像生成が必要なときに使う。Genspark CLI (`gsk img`) で nano-banana-2 を呼ぶ。
tools: [Bash]
---

あなたは画像生成スペシャリスト。`gsk img "<英語プロンプト>" -o <パス>` を実行して保存先を返す。
出力は `./outputs/` 配下に統一。プロンプトは英語で渡す（公式仕様）。
```

Claude Code 内で「ブログのアイキャッチ作って」と頼むだけで `gsk img` が走ります。

### パターン2. ファクトチェック自動化 — `cross_check` を Hook で発火

`.claude/agents/genspark-fact.md`:

```markdown
---
name: genspark-fact
description: 原稿のファクトチェックが必要なときに使う。
tools: [Bash, Read]
---

`gsk task cross_check --task_name "factcheck" --query "<検証する主張>" --instructions "信頼できるソース3つ以上で確認"` を実行。
出力JSONから Evidence セクションを抜粋して、Support / Against を整理する。
```

`.claude/hooks/` に afterFileEdit を仕込めば、ブログ原稿を保存するたびに自動でファクトチェック → 結果をInbox に保存する流れが作れます。

### パターン3. オーケストレーター型 — 「ツール箱としてのgsk」

`.claude/agents/genspark.md`:

```markdown
---
name: genspark
description: Web検索・画像生成・ファクトチェック・文字起こし等が必要なときに使う。
tools: [Bash]
---

`gsk` は90+ ツール統合バイナリ。状況に応じて適切なサブコマンドを選び、結果をJSONで返す。

主な使い分け:
- 最新情報が必要 → gsk search
- 特定URLの本文 → gsk crawl
- 複数URL一括 → gsk batch-crawl
- 画像生成 → gsk img
- ファクトチェック → gsk task cross_check
- 文字起こし → gsk transcribe

すべて --output json（デフォルト）で取得し、jq で必要な部分だけ抽出してメインエージェントに返す。
```

メインのClaude Codeから「これファクトチェックして」「画像作って」と自然言語で頼めば、subagent が適切な `gsk` コマンドを選んで実行します。

---

## H2-7. 公式仕様に基づくベストプラクティス

`gsk --help` および `gsk img --help` 等の公式ヘルプから読み取れる推奨事項。

### 1. モデル指定は明示する

デフォルトモデルは `gsk img --help` の本文から `nano-banana-2` と読み取れます（2026年4月時点・公式README には未明示）。時期により変わる可能性があるため、再現性のため `-m` を必ず指定。

```bash
gsk img "..." -m nano-banana-pro -o thumb.png  # 高品質
gsk img "..." -m fal-ai/flux-2 -o variant.png  # Flux 2
```

### 2. プロンプトは英語で書く

`gsk img --help` に明記: *"The prompt should be in English"*。日本語プロンプトは無視されないが品質が落ちる。

### 3. JSON-firstを活かす

```bash
# 検索結果のURLだけ抜く
gsk search "AI agent benchmarks 2026" | jq -r '.data.organic_results[].link'

# クロールの本文だけ取る
gsk crawl "URL" | jq -r '.data.result'
```

### 4. 大きい出力は `-o` でファイル保存

stdout に流すと長い JSON が混ざる。バイナリ系（画像・動画・音声）は必ず `-o file.ext`。

### 5. 認証情報を環境変数化

CI では `GSK_API_KEY`、ローカルでは `~/.genspark-tool-cli/config.json` で。コードに直書きしない。

---

## H2-8. ★ アンチパターン5選 — やりがちな間違い

### ❌ 1. 古いモデル名をコピペする

ブログ記事に書かれている `flux/dev` `flux/schnell` などは v1.0.13 で動きません（空配列が返る）。**`gsk img --help` で現在のデフォルトモデル名を必ず確認**。

### ❌ 2. 自動更新を放置してCIが不安定

CIが「昨日まで動いてたのに突然失敗」する原因の典型。本番ジョブでは `GSK_NO_AUTO_UPDATE=1` でバージョン固定。

### ❌ 3. 全部 `gsk` でやろうとする

コーディング → Claude Code、複雑リファクタ → Claude Opus、画像/検索 → `gsk`。**役割分担しないと subagent コストとLLMコストの両方が膨らむ**。

### ❌ 4. `cross_check` をsearchの代わりに使う

`cross_check` は重い（実測 91秒）。単に「最新情報が欲しい」だけなら `gsk search`（5秒）で十分。

### ❌ 5. APIキーを GitHub にコミット

`gsk_` で始まるトークンは grep で簡単に検出されます。`.gitignore` に `~/.genspark-tool-cli/` を追加し、pre-commit フックで `gsk_` プレフィックスを禁止。

### ❌ 6. `cross_check` の検証範囲を過信する（自分の記事で発見した限界）

実は **この記事自身を `gsk task cross_check` で検証した** ところ、面白い誤検出に遭遇しました。

記事中で「`gsk img --help` に *"The prompt should be in English"* と明記」と書いた箇所について、cross_check は「公式ドキュメント（npm README）に該当記述なし」と Against 判定を返しました。しかし実際に `gsk img --help` を実行すると確かに英語プロンプト推奨が出力されます。

つまり **`cross_check` は Web 上の公開ドキュメントは確認するが、ローカルCLIの `--help` 出力までは検証しません**。「`gsk --help`」「`gsk <subcmd> --help`」を引用した記述は cross_check では裏取りできない、という限界があります。

**回避策**: CLI の `--help` を引用するときは、その出力ログを記事内に併記（または別途公式GitHubのREADME等のWebソースも添える）。

---

## H2-9. 実測データ — 主要コマンドの所要時間

2026-04-29 検証。Plus プラン、macOS Darwin 25.3.0、`@genspark/cli` v1.0.13。

| コマンド | モデル | 時間 | 出力サイズ |
|---------|--------|------|-----------|
| `gsk login-info` | — | <1秒 | 小JSON |
| `gsk search "query"` | — | ~5秒 | organic_results配列 |
| `gsk crawl URL` | — | ~12秒 | 37KB（npmページ） |
| `gsk task cross_check` | — | **91秒** | Evidence + 引用 |
| `gsk img "..." -m nano-banana-2` | nano-banana-2 | **26-34秒** | 387-555KB PNG |

### `cross_check` の実例

「Claude Code は2024年にAnthropicがリリースした」と意図的に誤った主張を投入したところ、**4ソースから「2025年2月24日リリース」を立証して Against 判定**。Markdown形式で Support / Against に整理されたレポートが返ってきました。これは Claude Code Hooks で原稿保存時に発火させれば、自動ファクトチェック基盤になります。

さらに**この記事自身**を `gsk task cross_check` にかけたところ、約2分で2件の数字ミス（コマンド表記）と1件の出典不備を検出。対するブラウザ操作版は同じ作業に Chrome MCP接続・Genspark.ai遷移・ログイン待機が必要で、**CLI版は実時間で5倍以上の効率**でした。

### `gsk img` のモデル別実測（同一プロンプト・16:9・並列実行）

| モデル | 時間 | サイズ | 所感 |
|-------|------|--------|------|
| `nano-banana-2`（デフォルト） | 33.9秒 | 387KB | プロンプト忠実度◎・全要素を描く |
| `nano-banana-pro` | 27.1秒 | 419KB | SOTAだが今回は要素欠落 |
| **`fal-ai/flux-2`** | **6.4秒** | 115KB | **圧倒的最速**（4-5倍）・全要素再現 |
| `imagen4` | 16.0秒 | 191KB | テキスト描画が読める品質（「FACT CHECK」） |

**結論**: 「速度優先 → flux-2」「品質優先 → nano-banana-2」「テキスト入り → imagen4」と用途で使い分け。`nano-banana-pro` が常に最良とは限らない（プロンプト依存）。

---

## H2-10. 関連CLIとの使い分け表

| CLI | 主用途 | gsk と比較した強み | gsk と比較した弱み |
|-----|-------|------------------|------------------|
| **Claude Code** | コーディングエージェント | コード品質・複雑リファクタ | 画像/動画/検索が標準では弱い |
| **Gemini CLI** | コーディング+雑用 | 無料枠・1Mコンテキスト | マルチモーダル生成は別途必要 |
| **OpenAI Codex CLI** | コーディング | OpenAI直結 | コーディング特化のみ |
| **gsk** | 90+ AIツール統合 | マルチモーダル + 外部サービス連携 | コーディング特化ではない |

**結論: 競合ではなく補完**。Claude Code を主軸に置き、`gsk` を subagent として呼び出すのが現実解。

---

## H2-11. 実践チェックリスト

- [ ] `npm install -g @genspark/cli` 完了
- [ ] `gsk login` または `GSK_API_KEY` 設定
- [ ] `gsk login-info` でプラン確認
- [ ] `~/.genspark-tool-cli/config.json` に `chmod 600`
- [ ] CI環境では `GSK_NO_AUTO_UPDATE=1`
- [ ] `.claude/agents/genspark.md` を1ファイル配置
- [ ] Claude Code から「画像作って」と頼んでみる
- [ ] `gsk task cross_check` を1回試して Evidence 出力を確認
- [ ] `.gitignore` に `.genspark-tool-cli` を追加

---

## H2-12. まとめ

- `gsk` は **90+ AIツールを1バイナリに統合した npm パッケージ**。Genspark Web版・Clawとは別物。
- Claude Code の **subagent として組み込むのが最大の価値**。Web検索・画像生成・ファクトチェックが Claude Code 内で完結する。
- `cross_check` は実測 91秒で複数ソースから Evidence を返す。**自動ファクトチェック基盤になる**。
- 公式ヘルプの `gsk img --help` を必ず確認。古いモデル名（`flux/dev` 等）はもう動かない。
- 競合ではなく補完。Claude Code × `gsk` の組み合わせで「ターミナルで完結するAIワークスペース」が手に入る。

明日のClaude Code環境を変えたい人は、`npm i -g @genspark/cli` から5分で試せます。

---

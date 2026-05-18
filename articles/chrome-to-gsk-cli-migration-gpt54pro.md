---
title: "Claude in Chromeに疲れてGenspark gsk CLIに移行した話 — GPT-5.4 Proを最速で呼ぶ実測比較"
emoji: "🛞"
type: "tech"
topics: ["genspark", "claudecode", "cli", "ai", "gpt"]
published: true
---

<!--
ファクトチェック: 済（2026-05-18 Genspark gsk cross_check / 概ね正確 — 9 Verified / 2 Disputed → いずれも修正反映済み）
インフォグラフィック: gsk img gpt-image-2 / professional style / 2026-05-18 生成
-->

## この記事で分かること

Claude Code から **Genspark の GPT-5.4 Pro** を使いたい — そう思った瞬間、私たちには **3つの選択肢** が現れます。Web版・Claude in Chrome 経由のブラウザ操作・そして **gsk CLI**。

私はこれまで「Claude in Chrome で Genspark のタブを開いて GPT-5.4 Pro を選択してプロンプトを投げる」というブラウザ操作ルートで戦ってきました。動作はしますが、毎回ログイン状態を確認し、タブ ID を追い、レスポンスをスクレイピングする日々。**5分待っても結果が返ってこないことがざらにあります**。

そこに登場したのが **`gsk` CLI** — Genspark が公式に提供する CLI ツールです。これに移行して、私の Claude Code 体験は劇的に変わりました。

この記事では以下を整理します。

- **GPT-5.4 Pro を使う3つの方法** の関係を整理（混同しがちなポイントの完全整理）
- なぜ私が **Chrome 経由で消耗していたか** の具体的な失敗談
- **gsk CLI のセットアップ手順**（インストール・認証・初期設定）
- 推論・調査・コード生成の **3カテゴリ実測ベンチマーク**
- やりがちな **アンチパターン5選**（502エラー・出力混入・モデル誤解）
- **5ステップの移行チェックリスト**

:::message
**対象読者**: Claude Code と Genspark を併用しており、ブラウザ操作系の MCP（Claude in Chrome 等）で運用していて「もっと早く・確実に呼びたい」と感じている人。
:::

![Calling GPT-5.4 Pro: 3 Routes Compared — Web UI / Claude in Chrome MCP / gsk CLI のベンチマーク比較](/images/chrome-to-gsk-cli-migration/eyecatch.png)
*記事のサマリー：3つの経路を実測比較。gsk CLI が推論19.5秒・調査109秒・コード74秒で最速。*

---

## 【整理】GPT-5.4 Proを使う3つの方法 — Web版/Chrome経由/gsk CLI

まず私が混乱していた点を整理します。Genspark の GPT-5.4 Pro は **3つの経路で利用可能** であり、それぞれ得意分野と弱点が違います。

| 観点 | ① Web版 | ② Claude in Chrome 経由 | ③ gsk CLI |
|------|--------|----------------------|----------|
| **入口** | ブラウザで genspark.ai | Claude Code が Chrome 拡張を操作 | ターミナルで `gsk` コマンド |
| **モデル指定** | UIから選択可（GPT-5.4 Pro等） | UIから選択可 | **タスク別に自動選択（指定不可）** |
| **典型応答時間** | 数十秒〜数分 | 3〜10分（Chrome操作含む） | **10秒〜2分** |
| **対話継続** | ◎（チャット履歴） | △（タブ状態に依存） | △（基本は1回完結） |
| **自動化** | ✕ | △（ブラウザMCP必要） | **◎（純CLI）** |
| **目視確認** | ◎ | ◎ | ✕（CLI出力のみ） |
| **得意領域** | 単発・対話・目視 | モデル固定で深い推論 | バッチ・調査・コード生成 |

:::message alert
**重要**: gsk CLI は内部的に **Genspark 側がモデルを自動選択** します。「`gsk` で GPT-5.4 Pro を直接指定する」というオプションは現時点では存在しません。GPT-5.4 Pro 固定が必要な場面では Web 版か Claude in Chrome 経由に戻る必要があります。
:::

gsk CLI そのものの全体像や Claude Code 連携については、姉妹編の [Genspark CLI（gsk）完全ガイド](https://zenn.dev/amu_lab/articles/genspark-cli-claude-code-subagent-guide-2026) でより詳しく解説しています。本記事ではこの **3経路の使い分け** に焦点を当てます。

---

## なぜ私はChrome経由で消耗していたのか

Chrome 経由（Claude in Chrome MCP で Genspark を操作）は、一見「最強の組み合わせ」に見えます。実際にやれることは多い。しかし、**毎日の作業フローに組み込むと小さなコストが積み重なっていきます**。

私が実際にぶつかった消耗ポイントを正直に書きます。

### 消耗ポイント1: タブ管理が地獄

Claude in Chrome MCP は、同時に **1つの Claude Code セッションにしか接続できません**。複数のターミナルで Claude Code を起動していると、どのセッションに繋がるか不定です。

> However, only ONE session can actively use the Chrome extension at a time. All other sessions get an error: "Chrome extension disconnected."
> （[anthropics/claude-code Issue #26120](https://github.com/anthropics/claude-code/issues/26120) より）

私は朝から複数の作業を並行することが多く、「あれ？さっき開いた Genspark タブが他のセッションに食われた…」が日常茶飯事でした。

### 消耗ポイント2: ログインセッションが切れる

Genspark の Web UI は、しばらく使わないとログイン状態が切れます。Claude Code が「ログインしろ」と言ってきた時点で、私は Chrome のパスワードマネージャを開き、2段階認証を通し、また戻って…という流れを毎週繰り返していました。

### 消耗ポイント3: 応答が遅すぎる

最も致命的だったのはこれです。Chrome 経由は **DOM 操作と非同期レンダリングの待ち時間** がすべて積み上がります。

| ステップ | 所要時間 |
|---------|---------|
| Chrome 起動・タブ生成 | 5〜10秒 |
| Genspark にナビゲート | 3〜5秒 |
| プロンプト入力フィールド検出 | 1〜3秒 |
| GPT-5.4 Pro モデル選択 | 5〜10秒 |
| プロンプト送信 | 1秒 |
| **回答生成（GPT-5.4 Pro）** | **数十秒〜数分** |
| DOM から回答抽出 | 5〜10秒 |
| **合計** | **1〜5分（軽いタスク）〜数十分（重いタスク）** |

これが **「ちょっと聞きたい」レベルの質問でも毎回発生** するので、心理的負荷が大きい。

---

## gsk CLI セットアップ — インストール・認証・初期設定

ここからが本題。gsk CLI のセットアップは驚くほどシンプルです。

### Step 1: インストール

```bash
# npm 経由（公式）
npm install -g @genspark/cli
```

:::message
**前提**: Node.js >= 18 が必要です。`node --version` で確認してください。
:::

`gsk --version` で確認します。

```bash
$ gsk --version
1.0.x
```

### Step 2: 認証

```bash
gsk login
```

ブラウザが自動で開き、Genspark にログインすると、CLI に API キーが保存されます。

または、既に API キーを持っている場合は環境変数で:

```bash
export GSK_API_KEY="your-key-here"
```

### Step 3: 動作確認

```bash
gsk login-info
```

現在のユーザー情報（メール・プラン）が表示されればOK。

```bash
gsk list-tools
```

利用可能なツール（タスクタイプ）一覧が表示されます。後述の `task super_agent` や `task cross_check` などが見えるはずです。

---

## 移行後の使い方 — gsk task super_agent の基本

gsk CLI で「チャット的に質問を投げる」には、`task super_agent` が基本になります。

### 最小コマンド

```bash
gsk task super_agent \
  --task_name "my-question" \
  --query "Claude Code の Plan Mode と Permission Mode の違いは？" \
  --instructions "あなたは技術ライターです。日本語で簡潔に回答してください。" \
  --output text
```

### よく使うオプション

| オプション | 役割 |
|----------|------|
| `--task_name` | タスク識別名（履歴管理用） |
| `--query` | 質問・指示の本文 |
| `--instructions` | システムプロンプト相当（必須） |
| `--output text` | テキスト出力（jsonがデフォルト） |
| `--file path` | ローカルCSV/Excelを添付 |

:::message
**ハマりどころ**: `--instructions` を省略すると `Missing required option: --instructions` でエラーになります。空でも良いので必ず指定してください。
:::

### 他の便利なタスクタイプ

```bash
# ファクトチェック
gsk task cross_check --query "..." --instructions "..."

# ディープリサーチ
gsk task deep_research --query "..." --instructions "..."

# ドキュメント生成（HTML/Markdown）
gsk task docs --query "..." --instructions "..." --output-file report.docx

# スライド生成
gsk task slides --query "..." --instructions "..." --output-file deck.pptx
```

---

## 3カテゴリ実測ベンチマーク — 推論・調査・コード

「実際どれくらい速いの？品質は？」と気になるはず。私は3カテゴリで実測しました。

### 測定条件

- 同一プロンプトを `gsk task super_agent` に投げる
- 3カテゴリ: 推論 / Web調査 / コード生成
- 比較対象として **Chrome 経由（GPT-5.4 Pro固定）** の同等タスク所要時間を主観で記録

### 結果サマリー

| カテゴリ | プロンプト要約 | gsk CLI 応答時間 | gsk CLI 品質 | Chrome 経由（参考） |
|---------|--------------|----------------|-------------|------------------|
| **推論** | Claude Code の Plan Mode と Permission Mode の違いを3観点で表化 | **19.5秒** | ⭐⭐⭐（表は正確、出力は散らかる） | 5〜10分 |
| **調査** | 2026年4月以降の新興AIコーディングツール3つを差別化点付きで | **109秒**（1回502リトライ後） | ⭐⭐⭐⭐⭐（Cosyra/Intent/Grok Build を発掘、URL付き） | 10〜20分 |
| **コード** | Pythonで Markdown ファイルを再帰スキャンしてCSV出力するスクリプト | **74秒** | ⭐⭐⭐⭐⭐（型ヒント・docstring・エラーハンドリング完備の130行） | 5〜15分 |

### コード生成の質が想像以上

特にコード生成は驚きでした。74秒で返ってきたコードは、エラークラス定義・型ヒント・docstring・ロガー・エンコーディングフォールバック・終了コード設計まで揃った **プロダクション品質** でした。Chrome 経由で GPT-5.4 Pro に同じ指示を出した時と遜色ありません。

### 調査タスクは「多ラウンドWeb検索」が強い

調査タスクは内部で **5ラウンドのWeb検索** を実行し、2026-05-16 時点の最新情報（xAI の Grok Build CLI 発表など）まで補足してきました。Chrome 経由の GPT-5.4 Pro は単発検索が中心ですが、gsk CLI の super_agent は反復探索を内部で回します。

### 推論タスクは出力フォーマットに難あり

唯一の弱点が推論タスクでした。表形式の最終回答は正確ですが、**Web検索の探索ログ（URL一覧・スニペット）が本文に大量に混入** します。最終回答だけを抽出するために、私は出力の末尾ブロックだけを `tail` で取る運用にしています。

---

## 公式ドキュメントから読み解くベストプラクティス

gsk CLI の `--help` と Genspark の公式ドキュメントから、押さえるべきポイントを整理します。

### BP1: タスクタイプを正しく選ぶ

`super_agent` は万能ですが、**特定用途には専用タスクが速くて高品質** です。

| 用途 | 推奨コマンド |
|------|----------|
| 一般質問・チャット | `gsk task super_agent` |
| ファクトチェック | `gsk task cross_check` |
| 深い調査 | `gsk task deep_research` |
| HTML/Markdown文書 | `gsk task docs` |
| プレゼン資料 | `gsk task slides` |
| 画像生成 | `gsk img -m <model> -q "..."`（task ではなく専用コマンド） |
| 動画生成 | `gsk task video_generation`（または `gsk video`） |

### BP2: instructions を毎回書く

`--instructions` はシステムプロンプトです。「あなたは○○の専門家です」「日本語で簡潔に」など、**役割と出力形式を毎回指定** するだけで品質が大きく変わります。

### BP3: 出力先を `--output text` にする

デフォルトは `json` ですが、CLI で見るなら `text` の方が圧倒的に読みやすいです。スクリプトに組み込むなら `json` のままで OK。

### BP4: タスク履歴は Genspark UI で確認

CLI で実行した結果は、Genspark の Web UI からも参照できます。完了時に表示される `https://www.genspark.ai/agents?id=...` を開くと、フル結果と再実行ボタンが見えます。

### BP5: ACPモードで連続対話

1回完結が基本ですが、`--acp` フラグで Agent Client Protocol を使えば session_id ベースで会話を継続できます。

---

## やりがちなアンチパターン5選 — 502・出力混入・モデル誤解

私が実際にハマった失敗を共有します。

### AP1: `--instructions` を省略する

```bash
$ gsk task super_agent --task_name "x" --query "..." --output text
[ERROR] Missing required option: --instructions
```

**対策**: 必ず `--instructions` を指定。空文字列でも通る場合があるが、品質のために役割文を入れる。

### AP2: 502 Bad Gateway をスルーする

```
[INFO] Calling /create_task...
Error: HTTP 502: Bad Gateway
```

私の実測では **4回中1回** 発生。サーバー側の不安定性です。

**対策**: スクリプトに組み込む場合は **リトライロジックを必ず実装**。手動実行なら30秒待って再投入。

### AP3: 推論タスクの出力をそのまま使う

`super_agent` の出力には Web 検索ログが大量に混入します。

**対策**: 「最終回答だけ抜き出す」スクリプトを別途用意するか、出力の末尾セクションだけを利用する。`docs` タスクタイプを使えば整形済み文書が返ってくる。

### AP4: モデル指定できると勘違いする

`gsk` には `--model gpt-5.4-pro` のようなオプションは存在しません。タスクタイプに応じて Genspark 側が自動選択します。

**対策**: モデル固定が必須なら Chrome 経由 or Web 版を使う。gsk CLI は「タスクに最適なモデルを Genspark に任せる」割り切りで使う。

### AP5: super_agent を「対話」のつもりで連投する

`super_agent` は **1回完結のタスク発火** です。前のクエリの文脈は引き継がれません。

**対策**: 連続対話したいなら `--acp` モードで session_id を維持するか、複数ターンの文脈を `--query` に全部含める。

---

## 速度・コスト・品質の最適バランス指針

3経路を **目的別に使い分ける** のが正解です。

| 目的 | 推奨経路 | 理由 |
|------|---------|------|
| 速報チャット・ちょい質問 | **gsk CLI**（super_agent） | 10〜30秒、ターミナル完結 |
| コード生成・スクリプト一発書き | **gsk CLI**（super_agent） | 74秒でプロ品質、自動化に組込可 |
| Web調査・最新情報収集 | **gsk CLI**（super_agent or deep_research） | 多ラウンド検索が強い |
| ファクトチェック | **gsk CLI**（cross_check） | 専用タスクで高精度 |
| GPT-5.4 Pro固定の重い推論 | **Chrome 経由** | モデルが指定可能 |
| 長文・連続対話 | **Web版** | チャット履歴が便利 |
| 自動化・CIで定期実行 | **gsk CLI**（API） | CLI完結 |

---

## 既存ツールとの比較表（Web版/Chrome経由/gsk CLI）

| 観点 | Web版 | Chrome 経由 | gsk CLI |
|------|------|------------|--------|
| 学習コスト | 低 | 高（MCP設定） | 低（npm install） |
| 自動化 | 不可 | 可（ただし不安定） | **得意** |
| モデル指定 | 可 | 可 | **不可（自動選択）** |
| 応答速度 | 中 | **遅い** | **速い** |
| 安定性 | 高 | 中（タブ依存） | **中（502あり）** |
| 連続対話 | 得意 | 可 | 不向き（ACPで可） |
| 目視確認 | 得意 | 得意 | **不可** |
| コスト | クレジット消費 | クレジット消費 + Chrome時間 | クレジット消費 |

---

## 移行チェックリスト — 5ステップで切り替える

私が実際にやった移行手順を、再現可能なチェックリストにします。

- [ ] **Step 1**: `npm install -g @genspark/cli` でインストール（Node.js >= 18 必須）
- [ ] **Step 2**: `gsk login` で認証、`gsk login-info` で確認
- [ ] **Step 3**: `gsk list-tools` でタスク一覧を眺めて、自分のユースケースに合うものを特定
- [ ] **Step 4**: 普段やっている Chrome 経由タスクを `gsk task super_agent` で同じプロンプトを投げて比較
- [ ] **Step 5**: 「GPT-5.4 Pro 固定が必須」のタスクだけ Chrome 経由を残し、それ以外は gsk CLI に移行

---

## まとめ — Chrome経由はいつ残すべきか

私の結論はシンプルです。

> **普段使いは gsk CLI、モデル固定が必要なときだけ Chrome 経由を残す**

3つの経路を **「目的別に切り替える」** という発想に変えると、Chrome 経由のストレスがほとんど消えました。

### 残すべき Chrome 経由のユースケース

- **GPT-5.4 Pro 固定で再現性検証したい**
- **複数ターンのブレストを目視で進めたい**
- **生成プロセスを画面で見ながら判断したい**

### gsk CLI に移行すべきユースケース

- **コード生成・スクリプト書き**
- **Web調査・最新情報収集**
- **ファクトチェック**
- **CIや cron での定期実行**
- **「ちょっと聞きたい」レベルのチャット**

### 関連記事

- [Genspark CLI（gsk）完全ガイド — Claw・Web版との違いからClaude Code連携まで](https://zenn.dev/amu_lab/articles/genspark-cli-claude-code-subagent-guide-2026) — gsk の全体像と Claude Code 連携・内部モデル（Claude Sonnet 4.5）の発見も含む姉妹編

---

**この記事のベンチマークデータは私の環境（macOS / 2026年5月18日時点）での実測です。Genspark の仕様は頻繁にアップデートされるため、最新の挙動は公式ドキュメントもご確認ください。**

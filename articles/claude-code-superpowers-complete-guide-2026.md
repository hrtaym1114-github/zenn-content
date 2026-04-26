---
title: "【2026年最新】obra/superpowersでClaude Codeを規律化する完全ガイド — 6リポジトリと14スキル活用"
emoji: "🦸"
type: "tech"
topics: ["ClaudeCode", "AIエージェント", "TDD", "Plugin", "OSS"]
published: false
---

## この記事で分かること

Claude Codeに `obra/superpowers` を入れたはいいものの、

- 「`superpowers` と名のつくリポジトリが **6つ** もあって、どれを入れればいいのかわからない」
- 「`/brainstorm` `/write-plan` `/execute-plan` のコマンドと、14+ のskillがどう繋がっているのか不明」
- 「Anthropic公式marketplaceと `obra/superpowers-marketplace`、どっちから入れるべき？」

という混乱に当たった方向けの記事です。

この記事を読めば、

1. **6つの関連リポジトリの役割が1枚の表で理解できる**
2. **14+ skill と 3コマンドの関係マップ** が頭に入る
3. **TDD強制・Socratic brainstorming・subagent code review** を現場で回せるようになる

:::message
**対象読者**: Claude Codeを使い始めたが「プロンプトだけでは規律が保てない」と感じている中級エンジニア。TDDや設計ドキュメントを重視したい人。
:::

---

## 「superpowers」と名のつくリポジトリが6つある — まず整理しよう

作者 [@obra](https://github.com/obra)（Jesse Vincent氏）のGitHubには `superpowers-*` という名前のリポジトリが **6つ** 並んでいます。これが最初のつまずきポイント。

### 6リポジトリの役割マップ

| # | リポジトリ | 役割 | 入れるべきか |
|---|-----------|------|-------------|
| 1 | **`obra/superpowers`** | 本体。14+ skill と 3コマンドを含むコアプラグイン | ✅ 必須 |
| 2 | **`obra/superpowers-marketplace`** | プラグインカタログ。superpowers 本体 + 周辺プラグインをまとめて配信 | ✅ 経由して入れるのが推奨 |
| 3 | **`obra/superpowers-skills`** | 旧・コミュニティ編集可能なskill置き場 | ⚠️ 2025-10-27 **アーカイブ済**（read-only） |
| 4 | **`obra/superpowers-lab`** | 実験的skill群（tmux・Windows VM・重複検出など） | 🧪 必要なら個別導入 |
| 5 | **`obra/superpowers-chrome`** | Chrome DevTools Protocol直叩きのブラウザ操作プラグイン | 🌐 Playwright MCP代替を検討中なら |
| 6 | **`obra/superpowers-developing-for-claude-code`** | Claude Code自身のプラグイン/skill/MCP開発者向け | 🛠️ 自作プラグイン開発者のみ |

### インストール方法が2系統あることに注意

:::message alert
**Anthropic公式marketplace** と **obra自身のmarketplace** の2つから入手可能で、同じ `superpowers` でもコマンド名や更新頻度が微妙に違います。
:::

推奨は後者の obra marketplace 経由：

```bash
# Claude Code 内で実行
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

公式 marketplace 経由なら：

```bash
/plugin install superpowers@claude-plugins-official
```

公式は Anthropic の承認プロセスを通過している分安定ですが、最新機能の反映が数週間遅れることがあります。作者本人の更新を即座に追いたければ obra marketplace 一択です。

### なぜ `superpowers-skills` はアーカイブされたのか

当初は「コミュニティが skill を追加する場所」として用意されましたが、2025年10月に **skill本体が `obra/superpowers` の内部に統合** される方針転換があり、役目を終えてアーカイブされました。検索で古い記事にヒットするので「入れるべきか？」と悩む人が多いのですが、**答えは No** です。本体 `obra/superpowers` に取り込まれています。

---

## なぜsuperpowersが必要か — 「プロンプトだけでは規律が保てない」問題

作者 Jesse Vincent 氏はブログで、AIエージェントが抱える構造的な弱点をこう指摘しています。

> Without a skill system, agents either reinvent solutions repeatedly, rely on developer guidance for routine tasks, lack reliable methods to pressure-test their own behaviors, or cannot easily share learned patterns with other agents.
>
> — [Superpowers: How I'm using coding agents in October 2025](https://blog.fsck.com/2025/10/09/superpowers/)

つまり「毎回同じプロンプトを書き直し続ける」「テストを書かずに実装を始めてしまう」「バグ修正で根本原因を特定せずに症状だけ消す」といった **規律の欠如** は、プロンプトエンジニアリングでは解決できない。これをskillファイルとして永続化し、**エージェントが毎回必ず参照する状態を作る** のがsuperpowersの本質です。

特徴的なのは、作者がチャルディーニの **説得の6原則**（権威・希少性・社会的証明など）を使ってエージェントを "圧力テスト" している点。「本番環境が落ちている」「すでに動くコードがある」という状況で、エージェントがskillを無視せずに参照するか検証しているのです。

---

## セットアップと核心の使い方

### インストール

前述のコマンドに加え、初回起動時は以下を実行してskillライブラリをロードします。

```bash
# Claude Code セッション内で
/sp:brainstorm  # または /brainstorm — ここでskillが自動的に呼び出される
```

インストール直後、`~/.config/superpowers/skills/` 配下にskillファイル群がcloneされます。

### 3つの主要コマンド

| コマンド | 役割 | 呼び出されるskill |
|---------|-----|-----------------|
| `/brainstorm` | 要件を深掘りしてspecを作る | brainstorming |
| `/write-plan` | 設計ドキュメントを作る | writing-plans |
| `/execute-plan` | 計画に沿って実装する | executing-plans, using-git-worktrees, test-driven-development, requesting-code-review |

重要なのは **「コマンドとskillは1対1ではない」** こと。`/execute-plan` は内部で worktree 作成・TDD強制・subagentへの並列ディスパッチ・code reviewまで一気通貫で呼び出します。

---

## 14+スキルの全体マップ — 5カテゴリで整理する

v5.0.7 時点で収録されているskillを、役割で **5カテゴリ** に整理するとこうなります。

### カテゴリ1: 設計フェーズ

- **brainstorming** — Socratic法で要件を深掘り
- **writing-plans** — bite-sized taskに分割した実装計画作成

### カテゴリ2: 実行フェーズ

- **executing-plans** — plan通りに実装を進める
- **using-git-worktrees** — 設計承認後に隔離環境を自動構築
- **test-driven-development** — RED/GREEN/REFACTORを強制（anti-patterns辞書付き）

### カテゴリ3: レビューフェーズ

- **dispatching-parallel-agents** — 複数subagentへの並列ディスパッチ
- **subagent-driven-development** — subagent主導の開発
- **requesting-code-review** — レビュー依頼
- **receiving-code-review** — レビュー受領の作法

### カテゴリ4: 完了フェーズ

- **finishing-a-development-branch** — branchのマージ判定・クリーンアップ
- **verification-before-completion** — 完了前の実機検証

### カテゴリ5: デバッグ・メタ

- **systematic-debugging** — 4フェーズの根本原因追求プロセス
- **writing-skills** — skillを書くためのskill（メタスキル）
- **using-superpowers** — superpowers全体の使い方を説明するメタskill

「エージェントはタスク前に必ずskillをチェックする」という設計なので、あなたが明示的に呼ばなくても、該当skillが自動参照されます。

---

## 5つの典型的ワークフロー

### パターン1: ゼロから機能を作る（王道）

```
/brainstorm
  ↓ 要件が固まったら
/write-plan
  ↓ planを確認したら
/execute-plan
  ↓ 自動でworktree作成・TDD・レビューまで走る
```

「書きながら考える」を禁じ、**設計→計画→実装** の3段階を強制します。

### パターン2: 既存コードのバグ修正

```
# いきなり修正しない
「systematic-debuggingに従って root cause を特定してください」
  ↓
4フェーズ（再現 → 仮説 → 検証 → 修正）を順に進める
```

「とりあえず動くようにする」を止めるのが狙い。

### パターン3: 並列サブタスクを subagent に分散

```
/execute-plan
  ↓ タスクが5個以上あると自動で並列ディスパッチ
dispatching-parallel-agents が起動
```

単一セッションでの直列実装から、 **サブエージェントによる並列実行** へ切り替わります。

### パターン4: コードレビューを受ける

```
実装完了
  ↓
requesting-code-review で subagent にレビュー依頼
  ↓
指摘を受けて receiving-code-review skill が対応をガイド
```

2段階レビュー（**内部レビュー → 人間レビュー**）を挟むことで、人間のレビュー負荷を下げます。

### パターン5: 自作skillを追加する

```
writing-skills メタskillを参照
  ↓
SKILL.md を作成
  ↓
圧力テスト（時間制約・sunk-cost状況）で検証
```

skill作成自体をTDDと同じ哲学で扱う、というメタな設計です。

---

## 作者 Jesse Vincent のベストプラクティス

### 推奨1: brainstormなしに実装を始めない

> When you start building something, rather than jumping into writing code, the agent steps back and asks what you're really trying to do.
>
> — [obra/superpowers README](https://github.com/obra/superpowers)

コードを書き始める前に、**読者（あなた）とエージェントの間で仕様に合意する** 時間を必ず作る。これが最大の投資対効果を生みます。

### 推奨2: Evidence-based verification

実装完了を **claim（主張）** ではなく **evidence（証拠）** で判断すること。`verification-before-completion` skillが、実機でのコマンド実行結果を要求します。「たぶん動くはず」は禁止。

### 推奨3: Skill は公開し、共有する

「Superpowers are for everybody」というのが作者の思想。自作したskillは `obra/superpowers-marketplace` へのPRで共有できます。**エージェントの知識をコミュニティで民主化する** 発想です。

---

## やりがちなアンチパターン 7選

### 1. アーカイブ済の `superpowers-skills` をインストールしようとする

:::message alert
2025-10-27にアーカイブされ、内容は `obra/superpowers` 本体に統合されました。古い日本語記事ほどこちらを案内しがちですが、**本体だけ入れればOK** です。
:::

### 2. `/brainstorm` を飛ばしていきなり `/execute-plan` を呼ぶ

planが曖昧なまま実装に入ると、subagentが迷走して逆に時間がかかります。**brainstorm → write-plan → execute-plan** の順を守る。

### 3. TDDのRED段階をスキップ

`test-driven-development` skillは「失敗するテストの確認」を要求します。これを飛ばすと **「実装が正しいかの判定材料がない」** 状態になり、後で検証地獄に陥ります。

### 4. systematic-debugging を無視して「とりあえず修正」する

バグの症状だけ消すと、根本原因が残り再発します。4フェーズ（再現 → 仮説 → 検証 → 修正）を必ず踏む。

### 5. `superpowers-chrome` と Playwright MCP を併用する

用途が重なるので片方に絞ること。軽量・依存ゼロ重視なら superpowers-chrome、スクリーンショット・PDF・複雑な自動化なら Playwright MCP。

### 6. skillを自作せず毎回プロンプトで指示し直す

「同じ指示を2回以上書いたら skill 化」が鉄則。`writing-skills` メタskillがテンプレートを提供してくれます。

### 7. Anthropic公式とobra marketplaceの両方からインストールする

skillの重複ロードで挙動が不安定になります。**どちらか一方に統一** する。最新追従なら obra、安定重視なら公式。

---

## どのタスクにsuperpowersを使うべきか — 判断基準

| タスクの特徴 | superpowers活用度 | 理由 |
|------------|-----------------|------|
| 要件が曖昧・発散している | ★★★ | brainstormが効く |
| 既存の堅牢なコードベースに機能追加 | ★★★ | TDD + code reviewが効く |
| 本番環境のバグ修正 | ★★★ | systematic-debuggingが効く |
| 5分で終わるワンライナー | ★ | オーバーヘッドの方が大きい |
| 使い捨てのスクリプト | ★ | 規律コストが見合わない |
| ドキュメント執筆のみ | ★★ | brainstormだけ使うと良い |

「大きい・長期運用・チームで共有される」ほどROIが高い、と覚えておくと迷いません。

---

## 関連ツール比較

| ツール | 強み | 弱み | 向いている人 |
|-------|------|------|-------------|
| **obra/superpowers** | TDD強制・14+skill・Socratic brainstorm | 小タスクではオーバーヘッド | プロダクション開発者 |
| **oh-my-claudecode** | 軽量・設定主義・柔軟 | 規律を強制する機能が弱い | カスタマイズ好きな人 |
| **cc-plugins系** | 特化型（1機能1プラグイン） | 全体哲学がない | ピンポイント強化したい人 |
| **素のClaude Code** | 最速・設定不要 | 規律なし | スクリプト書き捨て用途 |

「superpowers vs oh-my-claudecode」は **哲学の選択** です。前者は「agentに規律を教える」方針、後者は「人間が毎回指示する」方針。

---

## 実践チェックリスト

### セットアップ時

- [ ] `obra/superpowers-marketplace` からインストールしたか（公式との二重導入は避ける）
- [ ] `superpowers-skills`（アーカイブ済）を誤って入れていないか
- [ ] `superpowers-chrome` と Playwright MCP の使い分けを決めたか
- [ ] `~/.config/superpowers/skills/` 配下にskillがcloneされているか確認

### 日常運用時

- [ ] 新機能追加時は `/brainstorm` から始めたか
- [ ] plan承認後に `/execute-plan` を呼んでいるか
- [ ] TDDのRED段階を飛ばしていないか
- [ ] バグ修正時に systematic-debugging の4フェーズを踏んだか

### トラブル時

- [ ] skillの重複読み込みがないか（marketplace重複チェック）
- [ ] 最新版への更新を `/plugin update superpowers` で実施したか
- [ ] `writing-skills` を使って繰り返しプロンプトをskill化したか

---

## まとめ

- **要点1**: 関連リポジトリは6つあるが、**必須は `obra/superpowers` だけ**。skill置き場はアーカイブ済
- **要点2**: インストールは **obra/superpowers-marketplace 経由** が推奨。公式との二重導入は避ける
- **要点3**: コマンドは `/brainstorm → /write-plan → /execute-plan` の3段階。skillは14+が自動呼び出しされる
- **要点4**: TDD強制と systematic-debugging が効くのは **中規模以上のプロダクション開発**。ワンライナーには不要
- **要点5**: skill自作と共有（`superpowers-marketplace`へのPR）が、**エージェント知識の民主化** という作者の思想の実装

superpowersは「プロンプトエンジニアリングでは解けない、AI開発の規律問題」に対する **構造的な解答** です。混乱しがちな6リポジトリの整理からskill活用までを押さえておけば、Claude Codeをチーム開発レベルの規律で動かせます。

---

## 参考リンク

- [obra/superpowers — GitHub](https://github.com/obra/superpowers)
- [obra/superpowers-marketplace — GitHub](https://github.com/obra/superpowers-marketplace)
- [obra/superpowers-chrome — GitHub](https://github.com/obra/superpowers-chrome)
- [obra/superpowers-lab — GitHub](https://github.com/obra/superpowers-lab)
- [Jesse Vincent's Blog — Superpowers: How I'm using coding agents in October 2025](https://blog.fsck.com/2025/10/09/superpowers/)
- [Superpowers – Claude Plugin | Anthropic](https://claude.com/plugins/superpowers)
- [superpowersから学ぶClaude Codeのスキル設計のコツ（Zenn）](https://zenn.dev/ryugen04/articles/20260222-superpowers-skill-design)
- [Superpowers完全ガイド：AIコーディングに「開発規律」を取り戻すスキルフレームワーク（Qiita）](https://qiita.com/nogataka/items/c2e73515e65533986421)

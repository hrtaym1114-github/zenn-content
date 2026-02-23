---
title: "【2026年最新】cmuxでClaude Codeを並列運用する完全ガイド — 2つのcmuxの違いからベストプラクティスまで"
emoji: "🔀"
type: "tech"
topics: ["ClaudeCode", "cmux", "Git", "AI", "開発効率化"]
published: false
---

## この記事で分かること

Claude Codeは強力なAIコーディングアシスタントですが、デフォルトでは **1セッション = 1タスク** の逐次実行です。1つのエージェントがリファクタリングしている間、テストを書いたりドキュメントを更新することはできません。

この制約を突破するのが **cmux** です。本記事では以下を解説します。

- 「cmux」という名前の **2つの別ツール** の違いと使い分け
- Git Worktreeを使った並列開発の基本
- Claude Code作者 Boris Cherny が公開した **公式チームのベストプラクティス**
- 5つの並列ワークフローパターン
- やりがちなアンチパターンと回避策
- 関連ツール（Claude Squad、GitButler等）との比較

:::message
**対象読者**: Claude Codeを日常的に使い、複数タスクを同時並行で進めたい開発者
:::

## 「cmux」は2つある — まず整理しよう

2026年2月時点で、「cmux」と名のつくツールが **2つ** 存在します。混同しやすいので最初に整理します。

### cmux CLI（craigsc/cmux）— "tmux for Claude Code"

| 項目 | 詳細 |
|------|------|
| リポジトリ | [github.com/craigsc/cmux](https://github.com/craigsc/cmux) |
| 種別 | CLIツール（Bashスクリプト） |
| ライセンス | MIT |
| OS | macOS / Linux |

Git Worktreeのライフサイクル（作成→起動→マージ→削除）を **ワンコマンド** で管理するCLI。Claude Codeのセッションを自動で立ち上げてくれます。

### cmux Terminal App（manaflow-ai/cmux）— GUIターミナル

| 項目 | 詳細 |
|------|------|
| 公式サイト | [cmux.dev](https://www.cmux.dev/) |
| リポジトリ | [github.com/manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) |
| 種別 | ネイティブmacOSアプリ（Swift/AppKit） |
| OS | macOSのみ |

Ghosttyのレンダリングエンジンをベースにした **AIエージェント向けGUIターミナル**。通知リング、内蔵ブラウザ、ソケットAPIが統合されています。

### 使い分けの結論

| ユースケース | cmux CLI | cmux App |
|-------------|----------|----------|
| Worktree管理の自動化 | **最適** | — |
| 並列セッションの視覚的管理 | — | **最適** |
| macOS以外 | 可能 | 不可 |
| エージェント通知の監視 | — | リング+バッジ |

:::message
**ベスト**: 両方を組み合わせる。cmux CLIでWorktreeを管理し、cmux App内でセッションを監視・操作。
:::

## 前提知識: なぜGit Worktreeが必要か

Claude Codeの各セッションは作業ディレクトリ内のファイルを自由に読み書きします。2つのセッションが同じディレクトリで動くと:

- 同じファイルへの同時編集で競合
- 一方のビルドが他方の変更で壊れる
- `git status`が混乱する

**Git Worktree** は1つのリポジトリから複数の作業ディレクトリを作成する機能です。`.git`データベースを共有するため、クローンより軽量です。

```
myproject/
├── .git/                    ← 共有Gitデータベース
├── src/                     ← メインの作業ディレクトリ
└── .worktrees/              ← cmuxが管理
    ├── feature-auth/        ← エージェント1の独立環境
    ├── fix-payments/        ← エージェント2の独立環境
    └── refactor-api/        ← エージェント3の独立環境
```

## cmux CLIのセットアップと使い方

### インストール

```bash
curl -fsSL https://github.com/craigsc/cmux/releases/latest/download/install.sh | sh
echo '.worktrees/' >> .gitignore
```

### コアコマンド

| コマンド | 機能 |
|---------|------|
| `cmux new <branch>` | Worktree作成 + setupフック + Claude起動 |
| `cmux start <branch>` | 既存Worktreeで作業再開 |
| `cmux ls` | アクティブなWorktree一覧 |
| `cmux merge [branch] [--squash]` | メインブランチにマージ |
| `cmux rm [branch\|--all]` | Worktree＋ブランチ削除 |
| `cmux init` | setupフックをClaude経由で自動生成 |

### 典型的なワークフロー

```bash
# 1. 機能開発を開始
cmux new feature-auth
# → Worktree作成 → setupフック実行 → Claudeセッション起動

# 2. 緊急バグ修正 — 別のエージェントを立ち上げ
cmux new fix-payments

# 3. バグ修正完了 → マージ＆クリーンアップ
cmux merge fix-payments --squash
cmux rm fix-payments

# 4. 元の機能開発に復帰
cmux start feature-auth
```

### setupフック（`.cmux/setup`）

Worktree作成時に自動実行されるスクリプト。プロジェクト固有の初期化処理を書いておきます。

```bash
#!/bin/bash
REPO_ROOT="$(git rev-parse --git-common-dir | xargs dirname)"
ln -sf "$REPO_ROOT/.env" .env  # 環境変数をシンボリックリンク
npm ci                          # 依存パッケージインストール
```

`cmux init`を実行すると、Claudeがプロジェクト構造を分析して適切なsetupスクリプトを自動生成してくれます。

## cmux Terminal Appの主要機能

cmux Appは通常のターミナルとしても使えますが、AIエージェント向けの機能が充実しています。

### 通知システム

エージェントが入力待ちになると自動で通知されます:

- **通知リング**: ペインの周囲に青いリング
- **サイドバーバッジ**: 未読通知がバッジ表示
- **macOS通知**: デスクトップ通知に転送

### 内蔵ブラウザ

ターミナル横にブラウザペインを開いて、開発サーバーを直接確認できます。スクリプタブルAPIでエージェントがブラウザを操作することも可能。

### インストール

```bash
brew tap manaflow-ai/cmux
brew install --cask cmux
```

## 5つの並列ワークフローパターン

### パターン1: スカウト → 本実装

最初のエージェントを「偵察」として送り、問題の所在を把握してから本実装。

```bash
cmux new scout-auth      # "認証周りのバグを調査して。コードは書かないで。"
# 結果を確認後...
cmux new impl-auth       # "スカウトの分析に基づいて実装して。"
```

### パターン2: 機能 + テスト並列

```bash
cmux new feature-search  # "検索機能を実装して"
cmux new test-search     # "検索機能のテストを先に書いて（TDD）"
```

### パターン3: プランレビュー方式

Claude Code公式チームが実践するパターン。1つ目がプランを書き、2つ目がスタッフエンジニアとしてレビュー。

```bash
cmux new plan-refactor     # Plan Modeでリファクタリング計画を作成
cmux new review-refactor   # "このプランをスタッフエンジニア視点でレビューして"
```

### パターン4: 分析 + 開発分離

Boris Chernyのチームでは **専用のanalysis Worktree** を常時用意し、ログ確認やデータ分析と開発作業を完全に分離しています。

```bash
cmux new analysis          # ログ確認、パフォーマンス分析（常駐）
cmux new feature-optimize  # 分析結果に基づいた実装
```

### パターン5: フェーズ分割

大規模実装を複数フェーズに分け、各フェーズに別エージェントを割り当て。

```bash
cmux new phase1-schema     # DBスキーマ
cmux new phase2-api        # APIエンドポイント（Phase 1完了後）
cmux new phase3-frontend   # フロントエンド（並列可能なら）
```

## Claude Code公式チームのベストプラクティス

Claude Code作者 Boris Cherny が2026年2月に公開した、チーム内での実践的Tipsです。

### 1. Worktree並列が最大の生産性向上策

Boris自身は最大5つの並列ターミナル + Webセッションを使用。

- **3〜5つのWorktree**を同時運用
- シェルエイリアスで高速切り替え（`za`, `zb`, `zc`）
- 分析専用のWorktreeを1つ確保

### 2. Plan Modeに全力を注ぐ

> "プランにエネルギーを注げば、Claudeは1発で実装できる"

`Shift+Tab`でPlan Modeに切り替え、読み取り専用でコードベースを分析させてから実装。**80%を計画・レビュー、20%を実装**に使うのがチームの目安。

### 3. CLAUDE.mdを育てる

CLAUDE.mdは「AIの永続的な記憶」。修正を教えたら必ず「CLAUDE.mdを更新して」と指示し、**2,500トークン以下**に保ちます。

### 4. カスタムスキルをGitにコミット

> "1日に2回以上やることは、スキルやコマンドにする"

### 5. Claudeをコードレビュアーとして使う

PRを出す前に「これが動くことを証明して」「ブランチ間の挙動差分を見せて」と批評させる。

## やりがちなアンチパターン 7選

### 1. コンテキスト汚染

セッションが長時間稼働してコンテキストウィンドウが溢れる。**`/clear`を頻繁に実行**し、長時間調査は専用Worktreeで。

### 2. Worktreeの乱立

10個のWorktreeが散乱 → 管理崩壊。**3-4個をアクティブ上限**とし、完了したら即`cmux rm`。

### 3. マージコンフリクトの放置

Worktreeはファイル競合を防ぐが、マージ時のコンフリクトは防げない。関連性の高い変更は同じWorktreeで行い、頻繁にリベース。

### 4. レビューなしの自動マージ

> "我々は出荷するコードに対して責任がある。大きなアーキテクチャ決定はClaudeに任せられない" — incident.ioチーム

### 5. コンテキストスイッチの過多

アクティブに対話するのは**2つまで**。3つ目以降は「fire-and-forget」（放置して後で確認）。

### 6. API使用量の暴走

調査には`/model sonnet`、実装には`/model opus`で動的に切り替えてコスト最適化。

### 7. setupフックの未整備

`cmux init`でClaude に自動生成させ、チーム全員で共有しましょう。

## 並列数の最適値

| 並列数 | 評価 | 備考 |
|-------|------|------|
| 1 | 標準 | 通常利用 |
| **2** | **推奨** | アクティブ作業の最適値 |
| 3 | 良好 | 3つ目は長時間タスク向け |
| 4-5 | 上級者向け | コーディネーションコストが増大 |
| 6+ | 非推奨 | 調整コストがメリットを上回る |

:::message alert
incident.ioは4〜7の同時エージェント運用に到達しましたが、これは組織的なサポート体制がある場合の話です。個人開発では2-3が現実的です。
:::

## 関連ツール比較

| ツール | 種別 | Worktree | 特徴 |
|--------|------|----------|------|
| **cmux CLI** | CLI | ✅ | シンプル、ワンコマンド |
| **cmux App** | GUIアプリ | — | 通知+内蔵ブラウザ |
| **[Claude Squad](https://github.com/smtg-ai/claude-squad)** | TUI | ✅ | バックグラウンド実行、YOLO（自動承認）モード |
| **[GitButler](https://blog.gitbutler.com/parallel-claude-code)** | GUIアプリ | 不要 | Worktreeなしでセッション分離 |
| **Agent Teams** | 公式機能 | ✅ | Claude Code組込み（2026年2月リサーチプレビュー） |

**使い分け**:
- **放置してバックグラウンド実行** → Claude Squad
- **Worktreeを最小コマンドで管理** → cmux CLI
- **視覚的な並列セッション監視** → cmux App
- **外部ツール不要で公式統合** → Agent Teams

## 実践チェックリスト

セットアップ時に確認:

- [ ] cmux CLIインストール
- [ ] `.gitignore`に`.worktrees/`を追加
- [ ] `.cmux/setup`フック作成（`cmux init`で自動生成可）
- [ ] CLAUDE.md整備（2,500トークン以下）
- [ ] シェルエイリアス設定（`cn`=new, `cs`=start, `cl`=ls）

日常ワークフロー:

1. 朝: `cmux ls`でアクティブWorktree確認
2. タスク開始: `cmux new <task>`
3. 複雑なタスクは `Shift+Tab` でPlan Modeから
4. アクティブ対話は2つまで、3つ目はfire-and-forget
5. 完了: `cmux merge --squash && cmux rm`
6. 夕方: 不要なWorktreeを整理

## まとめ

Claude Codeの並列運用で重要なのは、セッションを増やすことではありません。

1. **適切な分離** — Worktreeで環境を独立
2. **計画への投資** — Plan Modeで80%の時間を使う
3. **並列数の制限** — 2-3が最適
4. **人間のレビュー** — エージェント出力は必ず検証

cmuxはこの並列運用を**最小限のオーバーヘッド**で実現するツールです。まずは`cmux new`で1つのWorktreeを作るところから始めてみてください。

## 参考リンク

- [cmux CLI (craigsc/cmux)](https://github.com/craigsc/cmux)
- [cmux Terminal App](https://www.cmux.dev/)
- [Claude Code公式ドキュメント](https://code.claude.com/docs/en/common-workflows)
- [Boris Cherny's 10 Tips](https://www.threads.com/@boris_cherny/post/DUMZr4VElyb/)
- [incident.io — Shipping Faster with Claude Code](https://incident.io/blog/shipping-faster-with-claude-code-and-git-worktrees)
- [Claude Squad](https://github.com/smtg-ai/claude-squad)
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)

---
title: "★9,600超のclaude-howtoに学ぶClaude Code実践設計 — 10モジュール完全解剖と即使えるテンプレート集"
emoji: "🏗"
type: "tech"
topics: ["ClaudeCode", "AI", "Claude", "開発環境", "生産性向上"]
published: true
---

## この記事で分かること

Claude Codeの非公式ガイドとしてGitHubで**★9,600超・Fork 960超**を記録している[claude-howto](https://github.com/luongnv89/claude-howto)。公式ドキュメントが「何ができるか」を説明するのに対し、このリポジトリは**「どう組み立てるか」**を徹底的に教えてくれます。

この記事では、claude-howtoの10モジュール構成を解剖し、**今日から自分のプロジェクトに取り入れられる実践パターン**を抽出します。

:::message
**対象読者**: Claude Codeを使い始めたが、CLAUDE.mdの書き方やサブエージェント設計がよくわからない方。基本的なCLI操作ができる前提です。
:::

## なぜclaude-howtoは★9,600を超えたのか

2025年11月に作成されたこのリポジトリが、わずか5ヶ月で爆発的に成長した理由は3つあります。

### 1. 公式ドキュメントの「隙間」を埋めている

Anthropicの公式ドキュメントは機能説明としては優秀ですが、「この機能とあの機能をどう組み合わせるか」という**設計パターン**が不足しています。claude-howtoはまさにその隙間を埋めています。

### 2. コピペで即動くテンプレート

各モジュールに**本番環境で使えるテンプレート**が付属しています。「15分で最初のスラッシュコマンドが動く」という即効性が、Star数に直結しています。

### 3. Mermaidダイアグラムによる可視化

テキストだけでは分かりにくいClaude Codeの内部動作を、フローチャートやシーケンス図で可視化しています。「なるほど、こう動いていたのか」という理解が深まります。

## 10モジュールの全体像

claude-howtoは以下の10モジュールで構成されています。

| # | モジュール | 対象レベル | 所要時間 | 学べること |
|---|----------|-----------|---------|-----------|
| 01 | Slash Commands | 初心者 | 60分 | コマンドの作り方と共有方法 |
| 02 | Memory | 初心者+ | 90分 | 8層のメモリ階層と永続化設定 |
| 03 | Skills | 中級 | 90分 | 自動呼び出し可能な再利用コンポーネント |
| 04 | Subagents | 中級+ | 90分 | 専門エージェントの設計と委任パターン |
| 05 | MCP | 中級+ | 90分 | 外部ツール・API連携 |
| 06 | Hooks | 中級 | 60分 | イベント駆動の自動化 |
| 07 | Plugins | 上級 | 60分 | 機能のバンドル化と配布 |
| 08 | Checkpoints | 中級 | 45分 | セッション状態の保存・巻き戻し |
| 09 | Advanced Features | 上級 | 90分 | プランニング、拡張思考、バックグラウンドタスク |
| 10 | CLI Reference | 初心者+ | 60分 | コマンドライン完全リファレンス |

全体で**11〜13時間**。週末2日で一気に学ぶか、1日1モジュールずつ進めるか、自分のペースで選べます。

## 核心モジュール深掘り：今日から使える4つの設計パターン

10モジュールすべてを紹介するのは冗長なので、**実務インパクトが最も大きい4つ**に絞って解説します。

### パターン1: Slash Commands → Skills への進化

claude-howtoのModule 01で最初に学ぶのがスラッシュコマンドですが、Module 03で**スキルへの移行**が推奨されています。

従来のコマンド（`.claude/commands/review.md`）：

```markdown
コードレビューを実施してください。
- セキュリティの問題を確認
- パフォーマンスの問題を確認
- !`git diff HEAD`
```

スキル形式（`.claude/skills/review/SKILL.md`）：

```yaml
---
name: review
description: コード変更のレビューを実施する。PRの前にPROACTIVELYに実行
allowed-tools: Read, Grep, Glob, Bash
---

# コードレビュースキル

以下の観点でレビューを実施:
1. セキュリティ脆弱性
2. パフォーマンスの問題
3. コーディング規約違反

変更差分: !`git diff HEAD`
```

**スキルの利点：**
- `description`に「PROACTIVELY」と書くと、適切な場面で**自動呼び出し**される
- `allowed-tools`でツールアクセスを制限でき、安全性が向上
- ディレクトリ構造を持てるので、テンプレートやスクリプトを同梱可能

:::message
**移行のコツ**: 既存の`.claude/commands/`を一気に移行する必要はありません。よく使うコマンドから順にスキルに昇格させましょう。
:::

### パターン2: 8層メモリ階層を理解する

claude-howtoのModule 02で解説されるメモリシステムは、**8層の優先度階層**を持っています。上位が下位を上書きします。

```
優先度: 高 ←――――――――――――――――――→ 低

[マネージドポリシー] > [マネージドドロップイン] > [プロジェクトCLAUDE.md]
> [プロジェクトルール] > [ユーザーCLAUDE.md] > [ユーザールール]
> [ローカルCLAUDE.md] > [オートメモリ]
```

実務で特に重要なのは以下の3つです。

**プロジェクトCLAUDE.md（チーム共有）**

```markdown
# プロジェクトルール
- TypeScript strict mode必須
- テストカバレッジ80%以上
- コミットメッセージはConventional Commits
```

**プロジェクトルール（パス別ルール）**

`.claude/rules/api-rules.md`:
```yaml
---
paths: src/api/**/*.ts
---

# APIエンドポイントルール
- 入力検証にはZodを使用
- エラーレスポンスはRFC 7807形式
- レート制限を必ず実装
```

**ローカルCLAUDE.md（個人設定、gitignore対象）**

```markdown
# 個人設定
- レスポンスは日本語で
- 変更前に必ず確認を求めること
- vim風のキーバインド設定を維持
```

:::message alert
**よくある間違い**: CLAUDE.mdに「プロジェクトの全情報」を詰め込もうとすること。CLAUDE.mdは**ルール**を書く場所であり、ドキュメントではありません。コードから読み取れる情報は書かない。
:::

### パターン3: サブエージェント設計の3パターン

Module 04のサブエージェントは、claude-howtoの中でも最も実践的な価値が高いセクションです。

**読み取り専用エクスプローラ（Haiku、高速・低コスト）**

```yaml
---
name: explore
description: コードベースの調査。ファイル検索や構造把握に使用
model: haiku
tools: Glob, Grep, Read
---

高速にコードベースを探索し、関連ファイルと構造を報告する。
ファイルの変更は一切行わない。
```

**専門レビュアー（読み取り+分析）**

```yaml
---
name: security-reviewer
description: セキュリティレビュー。コード変更後にPROACTIVELY実行
tools: Read, Grep, Glob, Bash
---

OWASP Top 10の観点でセキュリティレビューを実施する。
以下に特に注目:
- SQLインジェクション
- XSS
- 認証・認可の不備
```

**Git Worktree分離型（安全な変更）**

```yaml
---
name: refactor-agent
description: リファクタリング作業。メインブランチを汚さず安全に実行
isolation: worktree
tools: Read, Write, Edit, Bash, Grep
---

独立したworktreeで作業する。
変更が完了したらブランチ名を報告し、レビューを待つ。
```

**使い分けの判断基準：**
- **調査だけ？** → `explore`（Haiku、読み取り専用）
- **分析+レポート？** → 専門エージェント（Sonnet、読み取り+Bash）
- **コード変更？** → Worktree分離型（Opus/Sonnet、全ツール）

### パターン4: Hooksによるイベント駆動自動化

Module 06のHooksは、特定のイベント発生時にシェルコマンドを自動実行する仕組みです。

`.claude/settings.json`に定義します：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "command": "npx eslint --fix $CLAUDE_FILE_PATH"
      }
    ],
    "Stop": [
      {
        "command": "echo \"Session ended at $(date)\" >> .logs/sessions.log"
      }
    ]
  }
}
```

**主要なイベントトリガー：**

| イベント | 発火タイミング | 活用例 |
|---------|-------------|--------|
| `UserPromptSubmit` | プロンプト送信前 | 入力ログ記録 |
| `PostToolUse` | ツール実行後（ファイル編集含む） | Lint自動実行、フォーマット |
| `Stop` | セッション終了時 | ログ保存、振り返り記録 |

:::message
**実用Tips**: `PostToolUse`でLint自動修正を入れると、Claudeが生成したコードの品質が即座に底上げされます。手動でLintを走らせる手間がなくなります。
:::

## 競合ガイドとの比較：claude-howtoの立ち位置

2026年3月時点で、Claude Codeの学習リソースは複数存在します。

| リポジトリ | ★数 | 特徴 |
|-----------|------|------|
| claude-code-best-practice | 25,800+ | リファレンス実装型、Command→Agent→Skill設計パターン |
| **claude-howto** | 9,600+ | モジュール式学習パス、Mermaid図解、自己評価クイズ |
| Claude-Code-Everything-You-Need-to-Know | 1,400+ | 網羅的ガイド、BMAD方法論 |

★数ではclaude-code-best-practiceが上ですが、claude-howtoの強みは**「学習設計の質」**です。best-practiceが「完成形のリファレンス」を提供するのに対し、claude-howtoは初心者が段階的に上級者になるための**カリキュラム**として設計されています。「見て真似る」か「学んで理解する」か、好みで選びましょう。

## やってはいけないアンチパターン

claude-howtoを読んで実践する際に陥りがちな罠を3つ紹介します。

### 1. CLAUDE.mdの肥大化

```markdown
❌ 悪い例：CLAUDE.mdに500行以上のルールを書く
→ Claudeのコンテキストを圧迫し、肝心の作業に使えるトークンが減る

✅ 良い例：CLAUDE.mdは50行以内、詳細は.claude/rules/に分割
```

### 2. サブエージェントの乱用

```markdown
❌ 悪い例：1ファイルの修正にサブエージェントを3つ起動
→ オーバーヘッドがメリットを上回る

✅ 良い例：独立した並列タスクがある時だけサブエージェントを使う
```

### 3. 全モジュールを一気に導入

```markdown
❌ 悪い例：Hooks + Skills + Subagents + MCP を同時に設定
→ 問題が起きた時にどこが原因か特定できない

✅ 良い例：1週間に1モジュールずつ導入し、効果を確認してから次へ
```

## 15分で始める最小構成

claude-howtoの全10モジュールを一気に学ぶ必要はありません。まずは以下の**最小構成**から始めましょう。

**Step 1: CLAUDE.mdを作る（5分）**

```markdown
# プロジェクトルール
- レスポンスは日本語で
- コード変更前に確認を求める
- テストが通ることを確認してからコミット
```

**Step 2: 最初のスキルを作る（5分）**

`.claude/skills/explain/SKILL.md`:
```yaml
---
name: explain
description: コードの説明。ファイルを指定すると詳しく解説する
---

指定されたファイルを読み、以下を説明してください：
1. このファイルの役割
2. 主要な関数/クラスの説明
3. 他ファイルとの依存関係
```

**Step 3: 使ってみる（5分）**

```bash
claude
> /explain src/main.ts
```

これだけで、claude-howtoの学習パスの最初の2モジュール（Commands + Memory）の基礎を体験できます。

## まとめ

- **claude-howto**は★9,600超のClaude Code学習ガイド。「何ができるか」ではなく「どう組み立てるか」を教えてくれる
- **10モジュール・13時間**の体系的カリキュラム。初心者から上級者まで段階的に学べる
- **即効性が高い4つの設計パターン**: Skill移行、8層メモリ、サブエージェント3型、Hooks自動化
- **最小構成は15分**で始められる。CLAUDE.md + 1スキルからスタート
- **アンチパターンを避ける**: CLAUDE.md肥大化、サブエージェント乱用、一気導入は禁物

:::message
**次のステップ**: [claude-howto リポジトリ](https://github.com/luongnv89/claude-howto)をクローンして、Module 01から順に試してみましょう。各モジュール末尾の自己評価クイズで理解度を確認できます。
:::

## 参考リンク

- [luongnv89/claude-howto](https://github.com/luongnv89/claude-howto) — 本記事で解説したリポジトリ
- [Claude Code 公式ドキュメント](https://docs.anthropic.com/en/docs/claude-code) — Anthropic公式リファレンス
- [CLAUDE.mdを制する者がClaude Codeを制す](https://zenn.dev/biki/articles/claude-code-claude-md-guide) — Zennの関連記事
- [Claude Codeで開発を10倍速にする完全ガイド](https://zenn.dev/riche/articles/claude-code-dev-guide-2026) — Zennの関連記事

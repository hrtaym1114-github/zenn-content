---
title: "【2026年最新】Git Worktreeで並列開発を加速する完全ガイド — 基本からClaude Code統合まで"
emoji: "🌿"
type: "tech"
topics: ["Git", "ClaudeCode", "AI", "開発効率化", "ターミナル"]
published: true
---

## この記事で分かること

「機能開発中に緊急バグが来た。でもstashして切り替えるのが面倒すぎる……」

Gitを使っていれば誰もが経験するこのジレンマを根本的に解決するのが **Git Worktree** です。さらに2026年2月からはClaude Codeが`--worktree`フラグをネイティブサポートし、AIエージェントとの組み合わせで並列開発が劇的に変わりました。

本記事では以下を解説します。

- Git Worktreeの概念と基本コマンド
- ブランチ切り替えとの違い・使い分け
- Claude Codeの`--worktree`フラグによる並列AIセッション
- 実践的な3つのワークフローパターン
- やりがちなアンチパターンと回避策

:::message
**対象読者**: Gitの基本操作は知っているが、Git Worktreeをまだ使っていない開発者。Claude Codeユーザーも歓迎。
:::

---

## なぜ「ブランチ切り替え」では足りないのか

通常の開発では、機能ブランチで作業中に緊急対応が入ると以下の手順が必要です。

```bash
# 現在の作業を退避
git stash

# ブランチ切り替え
git checkout hotfix/login-bug

# 修正作業...

# 元のブランチに戻る
git checkout feature/new-dashboard
git stash pop
```

この方法には問題があります。

1. **IDEが再インデックス** — 大規模プロジェクトで重い
2. **ビルドキャッシュが消える** — `node_modules`等が無効化されることも
3. **stashの管理が煩雑** — 複数の「作業中」が混在すると混乱
4. **「今どの作業をしていたか」を失いやすい**

Git Worktreeを使うと、**同じリポジトリから複数の作業ディレクトリを独立して持てます**。切り替えではなく、並列に存在させるアプローチです。

---

## Git Worktreeの基本

### ブランチとWorktreeの違い

| 概念 | 説明 |
|------|------|
| **ブランチ** | `.git`内のコミット履歴の分岐（メタデータ） |
| **Worktree** | ブランチをチェックアウトした実際の作業ディレクトリ |

1つのリポジトリに対して複数のWorktreeを作ることができ、それぞれが独立したファイル状態を持ちます。

```
my-project/              ← メインWorktree（main/masterブランチ）
├── .git/                ← 共有されるGitデータベース
└── src/

../my-project-feature/   ← 追加Worktree（feature/authブランチ）
└── src/

../my-project-hotfix/    ← 追加Worktree（hotfix/loginブランチ）
└── src/
```

`.git`データベースは共有されるため、ブランチ・コミット履歴・設定はすべて同じものが見えます。各Worktreeのファイル状態だけが独立しています。

:::message
**同じブランチを複数のWorktreeに割り当てることはできません。** 1ブランチ = 1Worktreeが原則です。
:::

---

## 基本コマンド一覧

### Worktreeの作成

```bash
# 新しいブランチを作りながらWorktreeを作成（推奨）
git worktree add -b feature/auth ../my-project-feature

# 既存ブランチでWorktreeを作成
git worktree add ../my-project-hotfix hotfix/login-bug
```

`git worktree add <パス> <ブランチ>` が基本形です。`-b`フラグで新規ブランチを同時作成できます。

### Worktreeの確認・削除

```bash
# 全Worktreeを一覧表示
git worktree list

# 出力例:
# /Users/user/my-project        abc1234 [main]
# /Users/user/my-project-feat   def5678 [feature/auth]
# /Users/user/my-project-fix    ghi9012 [hotfix/login-bug]

# Worktreeを削除（ディレクトリも削除）
git worktree remove ../my-project-feature

# 手動でフォルダを削除した後、Gitの管理情報だけ整理
git worktree prune
```

### よく使うコマンドまとめ

| コマンド | 用途 |
|---------|------|
| `git worktree add -b <branch> <path>` | 新ブランチ + Worktree作成 |
| `git worktree add <path> <branch>` | 既存ブランチのWorktree作成 |
| `git worktree list` | 一覧表示 |
| `git worktree remove <path>` | 削除 |
| `git worktree prune` | 孤立した参照のクリーンアップ |

---

## ディレクトリ構成のベストプラクティス

### プロジェクト外（隣）に配置する

```bash
# リポジトリ内に作成 → 非推奨
git worktree add .worktrees/feature-auth -b feature/auth

# リポジトリ外（隣）に作成 → 推奨
git worktree add ../my-project-feature-auth -b feature/auth
```

**リポジトリ内に作ると問題が起きやすい理由**:
- エディタの全文検索に不要なコードが混入する
- `git status`に誤検出が出ることがある
- `.gitignore`の管理が複雑になる

リポジトリの親ディレクトリに、プロジェクト名+ブランチ名のディレクトリを作るのが定番です。

### 環境の初期化を忘れずに

新しいWorktreeは空のファイル状態から始まります。プロジェクトの依存パッケージは別途インストールが必要です。

```bash
# JavaScript/TypeScriptプロジェクトの場合
cd ../my-project-feature
npm install  # または yarn / pnpm install / bun install

# Pythonプロジェクトの場合
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

:::message alert
`.env`ファイルや`node_modules`などは各Worktreeに独立して存在します。シンボリックリンクでメインから共有する方法もありますが、環境変数が意図せず共有されるリスクがあるため注意してください。
:::

---

## Claude Codeとの統合

### `--worktree`フラグ（2026年2月実装）

Claude Code v1.x からGit Worktreeのネイティブサポートが追加されました。Boris Cherny（Claude Code開発者）が紹介した`--worktree`フラグを使うと、**Claude Code自身が自動でWorktreeを作成し、その中でセッションを開始してくれます**。

```bash
# Claudeが自動でWorktreeを命名して作成
claude --worktree

# ブランチ名を指定する
claude --worktree feature/auth
```

手動で`git worktree add`する必要がなく、Claude Codeが命名からWorktree作成まで担当してくれます。

### 並列セッションの立ち上げ

複数のターミナルタブ/ウィンドウを開いて、それぞれ別タスクのWorktreeでClaudeを起動します。

```bash
# ターミナル1: 機能開発
cd ../my-project-feature
claude

# ターミナル2: バグ修正（並列で動かしたまま）
cd ../my-project-hotfix
claude

# ターミナル3: 分析・調査専用
cd ../my-project-analysis
claude
```

各Claudeセッションは完全に独立したファイル状態で動作します。セッション1がファイルを編集しても、セッション2には影響しません。

### `claude --worktree` vs 手動Worktree作成

| 方法 | 手間 | 向いている場面 |
|------|------|--------------|
| `claude --worktree` | 少ない | その場でAIに任せたいとき |
| 手動 `git worktree add` | やや多い | ブランチ名・パスを細かく指定したいとき |
| cmux CLI | 最小 | 複数Worktreeを継続的に管理するとき |

---

## 実践ワークフローパターン

### パターン1: 緊急バグ修正を止めずに機能開発を続ける

最もよくあるユースケースです。

```bash
# 機能開発中...
# (feature/new-dashboardのWorktreeでClaude稼働中)

# 緊急バグ報告が来た！
# → 機能開発のClaudeはそのままに、別Worktreeを作成
git worktree add -b hotfix/login-crash ../my-project-hotfix

cd ../my-project-hotfix
npm install
claude  # バグ修正タスクを指示

# バグ修正完了 → mainにマージ
cd ../my-project  # メインに戻る
git merge hotfix/login-crash
git worktree remove ../my-project-hotfix
git branch -d hotfix/login-crash

# 機能開発のClaudeは継続中
```

ポイントは **2つのClaudeセッションが同時に動いていても互いに干渉しない**ことです。

### パターン2: Plan Mode → 実装の分離（官チームの推奨）

Claude Code公式チーム（Boris Cherny）が実践するパターンです。

```bash
# Worktree1: 計画立案専用（読み取り専用のPlan Mode）
cd ../my-project-plan
claude --permission-mode plan
# → 「認証システムのリファクタリング計画を作成して」

# 計画をレビュー...

# Worktree2: 計画に基づいて実装
cd ../my-project-impl
claude
# → 「plan/をもとに実装して」
```

計画フェーズでコードを書かせず、実装は承認済みの計画に基づいて行うことで、予期しない変更を防ぎます。

### パターン3: コードレビューを並列で

```bash
# チームメンバーのPRをチェックアウト
git worktree add -b review/pr-123 ../my-project-review origin/feature/payment-refactor

cd ../my-project-review
claude
# → 「このコードをセキュリティ観点でレビューして」

# レビュー中も自分の開発は止まらない
```

---

## アンチパターンと注意点

### 1. Worktreeの乱立

```bash
# NG: 管理できないほど増やす
git worktree list
# → 10個のWorktreeが散乱...
```

**推奨上限は3-4個**。完了したらすぐに`git worktree remove`でクリーンアップする習慣をつけましょう。

### 2. 同じブランチを使おうとする

```bash
# NG: 既にmainがチェックアウトされているのに別Worktreeでmainを作ろうとする
git worktree add ../project-main2 main
# エラー: fatal: 'main' is already checked out
```

Git Worktreeは1ブランチ = 1Worktreeが原則です。同じブランチを複数のWorktreeに割り当てることはできません。

### 3. Worktreeのディレクトリを直接rmで削除する

```bash
# NG: Gitの管理情報が残る
rm -rf ../my-project-feature

# OK: 正規の削除コマンドを使う
git worktree remove ../my-project-feature

# 直接削除してしまった場合の後処理
git worktree prune
```

### 4. マージコンフリクトを放置する

Worktreeはファイルの競合は防ぎますが、**マージ時のコンフリクトは防げません**。関連する変更は同じWorktreeで行い、定期的に`git rebase main`でmainの変更を取り込みましょう。

### 5. 環境変数を各Worktreeにコピーし忘れる

```bash
# 新しいWorktreeには.envがない
ls ../my-project-feature/.env
# → No such file

# 解決策: シンボリックリンクを張る
ln -s $(pwd)/.env ../my-project-feature/.env
```

---

## まとめ

Git Worktreeを使うと：

1. **ブランチ切り替えなしに並列作業** — stash不要、IDEの再インデックス不要
2. **Claude Codeの並列セッション** — `--worktree`フラグで独立した環境を自動作成
3. **コンテキストの保持** — 「何の作業をしていたか」がWorktreeごとに独立
4. **チームの生産性向上** — PRレビューと開発を同時進行

最初のステップとして、次の緊急バグが来たときに試してみてください。

```bash
git worktree add -b hotfix/bug-123 ../$(basename $(pwd))-hotfix
cd ../$(basename $(pwd))-hotfix
# → ここで通常通り作業。元の開発は一切止まらない
```

:::message
**次のステップ**: Worktreeの作成・管理を自動化したい場合は、[cmux CLI](https://github.com/craigsc/cmux)（tmux for Claude Code）を使うとワンコマンドで完結します。詳しくは「[cmuxでClaude Codeを並列運用する完全ガイド](https://zenn.dev/amu_lab/articles/cmux-claude-code-parallel-guide)」をご覧ください。
:::

---

## 参考リンク

- [Git公式ドキュメント: git-worktree](https://git-scm.com/docs/git-worktree)
- [Claude Code公式ドキュメント: Git Worktreeを使った並列セッション](https://code.claude.com/docs/ja/common-workflows)
- [Boris Cherny on X: claude --worktree の紹介](https://x.com/bcherny/status/2025007394967957720)
- [世界一わかりやすくGit worktreeを解説！AI駆動開発でも活用できる並列開発の方法](https://zenn.dev/tmasuyama1114/articles/git_worktree_beginner)
- [Claude Code × worktree で同時並列自動開発するしくみ](https://zenn.dev/progate/articles/claude-code-worktree-parallel-automation)

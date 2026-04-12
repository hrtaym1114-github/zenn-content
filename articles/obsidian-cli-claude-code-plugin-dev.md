---
title: "Obsidian CLI × Claude Code でプラグイン開発を自動化する"
emoji: "🔮"
type: "tech"
topics: ["obsidian", "claudecode", "plugin", "自動化"]
published: true
---

## はじめに — AIエージェントがObsidianプラグインを「自分で作って、自分でテストする」時代

2026年2月、Obsidianが公式CLIをリリースした。これにより、ターミナルからVaultの操作、プラグインの有効化・無効化、さらにはスクリーンショットの撮影までが可能になった。

この機能にいち早く目をつけたのが、Astroのコア開発者であるBen Holmes氏（[@BHolmesDev](https://x.com/BHolmesDev)）だ。彼はOpenAI Codexを使い、AIエージェントに以下の一連の作業を自動実行させるデモを公開した。

1. Obsidianプラグインのコードを生成・ビルド
2. Obsidian CLIでプラグインをプログラム的に有効化
3. `dev:screenshot`でObsidianのスクリーンショットを撮影し、自分の作業をe2e検証

このデモは大きな反響を呼んだ（likes: 398、bookmarks: 592）。AIエージェントが「コードを書く」だけでなく「動作を目で確認する」ところまで自律的に行える、という衝撃的なワークフローだった。

本記事では、この手法を**Claude Code**で再現する方法を解説する。私自身、Obsidian + Claude Codeのヘビーユーザーとして、`.claude/`配下にhooks・skills・agentsを多数構築してきた経験を踏まえ、実践的な構成を紹介する。

## Obsidian CLIとは

### 概要

Obsidian CLI は、Obsidian 1.12で追加された公式のコマンドラインインターフェースだ。2026年2月10日にCatalyst（有料）メンバー向けEarly Accessとしてリリースされ、2月27日のv1.12.4で全ユーザーに一般公開された。

100以上のコマンドが用意されており、これまでGUIでしか行えなかった操作をターミナルから実行できる。

### セットアップ

```bash
# 1. Obsidian 1.12以上をインストール
# 2. Settings → General → Command line interface を有効化
# 3. 画面の指示に従いPATHを設定
# 4. ターミナルを再起動

# 動作確認
obsidian version
```

**重要**: Obsidian CLIはデスクトップアプリが起動している状態でのみ動作する。バックグラウンドで常時起動しておく必要がある。

### プラグイン開発に関連する主要コマンド

プラグイン開発の自動化に直結するコマンドを抜粋する。

#### プラグイン管理

```bash
# インストール済みプラグイン一覧
obsidian plugins

# 有効なプラグインのみ表示
obsidian plugins:enabled

# プラグインの有効化
obsidian plugin:enable id=my-plugin

# プラグインの無効化
obsidian plugin:disable id=my-plugin

# コミュニティプラグインのインストール（enable付きで即有効化も可）
obsidian plugin:install id=my-plugin enable

# プラグインのアンインストール
obsidian plugin:uninstall id=my-plugin

# プラグインのホットリロード（開発中に使う）
obsidian plugin:reload id=my-plugin
```

#### 開発者ツール

```bash
# スクリーンショット撮影
obsidian dev:screenshot path=screenshot.png

# DOM要素の検査
obsidian dev:dom selector=".workspace-leaf" text

# コンソールログの確認
obsidian dev:console level=error

# JavaScriptエラーの確認
obsidian dev:errors

# CSS値の検査
obsidian dev:css selector=".workspace-leaf" prop=background-color

# JavaScript実行
obsidian eval code="app.vault.getFiles().length"

# モバイルエミュレーション
obsidian dev:mobile on
```

#### Vault操作

```bash
# ノートの読み取り
obsidian read file="My Note"

# ノートの作成
obsidian create name="New Note" content="# Hello"

# 検索
obsidian search query="search term" limit=10

# Vault情報
obsidian vault
```

## Claude Codeとの連携アーキテクチャ

Claude Codeからこれらのコマンドを活用するには、3つの仕組みを組み合わせる。

### 1. CLAUDE.md によるコンテキスト提供

Vaultルートの`CLAUDE.md`にObsidian CLI の使い方を記述することで、Claude Codeがプラグイン開発時にCLIを自律的に使えるようになる。

```markdown
# CLAUDE.md（プラグイン開発用セクションの例）

## Obsidian CLI

このVaultではObsidian CLIが有効化されている。
プラグイン開発時は以下のコマンドを活用すること。

### ビルド後の検証フロー
1. `npm run build` でビルド
2. `obsidian plugin:reload id=<plugin-id>` でホットリロード
3. `obsidian dev:screenshot path=screenshots/after-build.png` で結果を撮影
4. スクリーンショットを確認し、UIが期待通りか検証

### エラーチェック
- `obsidian dev:errors` でJSエラーを確認
- `obsidian dev:console level=error` でコンソールエラーを確認

### プラグインの場所
- 開発中プラグイン: `.obsidian/plugins/my-plugin/`
```

### 2. kepano/obsidian-skills の活用

Obsidianの創業者であるkepano氏が公開している[obsidian-skills](https://github.com/kepano/obsidian-skills)リポジトリを導入すると、Claude CodeがObsidian CLIを構造的に理解できる。

```bash
# Vaultルートの .claude/ 配下に配置
cd /path/to/vault
git clone https://github.com/kepano/obsidian-skills.git .claude/skills-obsidian
```

obsidian-skillsには以下の5つのスキルが含まれる。

- **obsidian-markdown** — Obsidian Flavored Markdownの作成・編集
- **obsidian-bases** — Obsidian Basesファイルの管理
- **json-canvas** — JSON Canvasの操作
- **obsidian-cli** — CLIによるVault操作・プラグイン開発
- **defuddle** — Webページからのクリーンなマークダウン抽出

### 3. Claude Code Hooks による自動化

Claude Codeのhooks機能を使えば、ファイル編集後に自動でビルド・リロード・検証を走らせることができる。

```json
// .claude/settings.json
{
  "hooks": {
    "afterFileEdit": [
      {
        "matcher": "plugins/my-plugin/src/**/*.ts",
        "command": "cd .obsidian/plugins/my-plugin && npm run build && obsidian plugin:reload id=my-plugin"
      }
    ]
  }
}
```

この設定により、プラグインのTypeScriptファイルを編集するたびに自動でビルドとリロードが実行される。

## 実践: プラグイン自動開発ワークフロー

ここからは、Claude Codeに指示を出してObsidianプラグインを開発する具体的なワークフローを示す。

### ステップ1: プロジェクトの初期化

まず、Obsidianプラグインのスキャフォールディングを行う。

```bash
# Vault内のプラグインディレクトリに移動
cd /path/to/vault/.obsidian/plugins/

# プラグイン用ディレクトリ作成
mkdir my-word-count && cd my-word-count

# Obsidian公式サンプルプラグインをベースにする
npm init -y
npm install obsidian --save-dev
npm install typescript --save-dev
```

### ステップ2: Claude Codeへの指示

Claude Codeに以下のような指示を出す。

```
Obsidianプラグイン「Word Count Status Bar」を作成して。
- ステータスバーに現在のノートの文字数を表示する
- ファイル切り替え時に自動更新する
- main.tsに実装し、npm run buildでビルドしたあと、
  obsidian plugin:reload で動作確認して。
- dev:screenshot で結果のスクリーンショットを撮って、
  UIが正しく表示されているか確認して。
```

Claude Codeは以下の流れで自律的に作業を進める。

### ステップ3: Claude Codeの自律実行フロー

```
[1] main.ts を作成・実装
    ↓
[2] manifest.json, package.json を設定
    ↓
[3] npm run build を実行
    ↓  ビルドエラーがあれば自動修正してリトライ
[4] obsidian plugin:enable id=my-word-count
    ↓
[5] obsidian plugin:reload id=my-word-count
    ↓
[6] obsidian dev:screenshot path=screenshots/word-count-v1.png
    ↓  スクリーンショットを確認し、UIの問題があれば修正
[7] obsidian dev:errors
    ↓  エラーがあれば修正してステップ3に戻る
[8] 完了報告
```

### コード例: main.ts

Claude Codeが生成するプラグインの一例を示す。

```typescript
import { Plugin } from 'obsidian';

export default class WordCountPlugin extends Plugin {
  private statusBarEl: HTMLElement;

  async onload() {
    this.statusBarEl = this.addStatusBarItem();
    this.updateWordCount();

    this.registerEvent(
      this.app.workspace.on('active-leaf-change', () => {
        this.updateWordCount();
      })
    );

    this.registerEvent(
      this.app.workspace.on('editor-change', () => {
        this.updateWordCount();
      })
    );
  }

  private updateWordCount() {
    const activeFile = this.app.workspace.getActiveFile();
    if (!activeFile) {
      this.statusBarEl.setText('');
      return;
    }

    this.app.vault.read(activeFile).then((content) => {
      const words = content.split(/\s+/).filter(w => w.length > 0).length;
      const chars = content.length;
      this.statusBarEl.setText(`${words} words / ${chars} chars`);
    });
  }

  onunload() {
    this.statusBarEl.remove();
  }
}
```

### ステップ4: e2e検証

ビルド・リロード後、Claude Codeがスクリーンショットで結果を確認する。

```bash
# スクリーンショットを撮影
obsidian dev:screenshot path=screenshots/word-count-check.png

# DOM要素でステータスバーの内容を確認
obsidian dev:dom selector=".status-bar-item" text

# エラーがないか確認
obsidian dev:errors
obsidian dev:console level=error
```

Claude Codeはマルチモーダル対応なので、撮影したスクリーンショットの画像を直接解析し、「ステータスバーに文字数が正しく表示されている」「レイアウトが崩れていない」といった視覚的な検証を行える。これがBen Holmes氏のデモで示された"AIが自分の仕事を目で確認する"ワークフローだ。

## 応用: 自動e2eパイプラインの構築

ここまでの仕組みを組み合わせると、より高度な自動化パイプラインが構築できる。

### パイプライン構成

```
Claude Codeセッション開始
  │
  ├─ [Phase 1: 実装]
  │   コード生成 → TypeScript型チェック → ビルド
  │
  ├─ [Phase 2: 統合テスト]
  │   plugin:reload → dev:errors → dev:console
  │
  ├─ [Phase 3: 視覚テスト]
  │   dev:screenshot → 画像解析 → UI検証
  │
  ├─ [Phase 4: 機能テスト]
  │   eval code="..." → 期待値との比較
  │
  └─ [Phase 5: レポート]
      結果サマリー → 修正が必要なら Phase 1 に戻る
```

### eval を使った機能テスト

`obsidian eval` コマンドを使えば、プラグインの内部状態をプログラム的に検証できる。

```bash
# プラグインがロードされているか確認
obsidian eval code="app.plugins.plugins['my-word-count'] !== undefined"

# プラグインの設定値を確認
obsidian eval code="JSON.stringify(app.plugins.plugins['my-word-count'].settings)"

# Vault内のファイル数を取得（プラグインのテストデータ確認）
obsidian eval code="app.vault.getMarkdownFiles().length"
```

### モバイル表示のテスト

```bash
# モバイルエミュレーションをON
obsidian dev:mobile on

# モバイル状態でスクリーンショット
obsidian dev:screenshot path=screenshots/mobile-view.png

# モバイルエミュレーションをOFF
obsidian dev:mobile off
```

## Codexとの違い — なぜClaude Codeか

Ben Holmes氏のデモはOpenAI Codexを使用していたが、Claude Codeには固有の強みがある。

### Claude Codeの利点

| 項目 | Claude Code | Codex |
|------|------------|-------|
| **ローカル実行** | ターミナルで直接実行。Obsidianと同じマシンで動く | クラウドサンドボックスでの実行が基本 |
| **マルチモーダル** | スクリーンショットを直接解析できる | テキストベースの確認が主 |
| **Hooks** | ファイル編集トリガーで自動ビルド | 独自の自動化構成が必要 |
| **CLAUDE.md** | プロジェクト固有のコンテキストを常時保持 | セッション毎にコンテキスト設定 |
| **拡張性** | skills, agents, hooks の3層構造 | タスク指向の単発実行 |

### ローカル実行の決定的な優位性

Obsidian CLIは**デスクトップアプリが起動している状態でしか動かない**。つまり、Claude Codeのようにローカルのターミナルで動作するツールとの相性が本質的に良い。Claude Codeなら`obsidian dev:screenshot`を実行し、そのファイルをそのまま読み取って画像解析できる。

## CLAUDE.md テンプレート — プラグイン開発用

実際に使えるCLAUDE.mdのテンプレートを公開する。

```markdown
# Obsidian Plugin Development

## 環境
- Obsidian CLI: 有効（Settings → General で確認）
- Node.js: 18+
- プラグインディレクトリ: `.obsidian/plugins/<plugin-id>/`

## 開発ワークフロー
1. TypeScriptでコードを実装
2. `npm run build` でビルド
3. `obsidian plugin:reload id=<plugin-id>` でリロード
4. `obsidian dev:screenshot path=screenshots/<name>.png` で確認
5. `obsidian dev:errors` でエラーチェック

## 検証チェックリスト
- [ ] ビルドエラーなし
- [ ] dev:errors が空
- [ ] dev:console level=error が空
- [ ] スクリーンショットでUI確認
- [ ] モバイルエミュレーションでレイアウト確認

## コマンドリファレンス
- `obsidian plugin:reload id=<id>` — ホットリロード
- `obsidian dev:screenshot path=<file>` — スクリーンショット
- `obsidian dev:dom selector="<css>"` — DOM検査
- `obsidian dev:errors` — エラー確認
- `obsidian eval code="<js>"` — JS実行
```

## まとめ — Obsidianプラグイン開発の新しい形

Obsidian CLIの登場により、AIエージェントによるプラグイン開発が現実的になった。

従来のプラグイン開発では、コード修正のたびに手動でリロードし、UIを目視確認し、コンソールを開いてエラーを確認するという反復作業が必要だった。Obsidian CLI × Claude Codeの組み合わせは、この開発ループ全体を自動化する。

**Claude Codeが実現する開発ループ:**

```
コード生成 → ビルド → リロード → スクリーンショット → 視覚検証 → エラーチェック
    ↑                                                              ↓
    └──────────── 問題があれば自動修正して再実行 ──────────────────┘
```

Ben Holmes氏が示した「AIが自分の仕事を検証する」というコンセプトは、Claude Codeのローカル実行・マルチモーダル解析・hooks機構と組み合わせることで、さらに強力なワークフローになる。

Obsidianユーザーかつ開発者であれば、ぜひ試してみてほしい。プラグインのアイデアはあるが実装が面倒で放置していた、という人にとって、このワークフローは大きなブレイクスルーになるはずだ。

## 参考リンク

- [Obsidian CLI 公式ページ](https://obsidian.md/cli)
- [Obsidian CLI ヘルプドキュメント](https://help.obsidian.md/cli)
- [kepano/obsidian-skills（GitHub）](https://github.com/kepano/obsidian-skills)
- [Ben Holmes氏の元ツイート](https://x.com/BHolmesDev/status/2042241128259367198)
- [Obsidian 1.12 CLI Ultimate Guide](https://blog.wenhaofree.com/en/posts/articles/obsidian-1-12-cli-ultimate-guide/)

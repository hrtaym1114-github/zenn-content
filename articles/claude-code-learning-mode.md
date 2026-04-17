---
title: "【2026年最新】Claude Code Learning Mode 完全ガイド — /config と /output-style の違いから TODO(human) 運用まで"
emoji: "🧑‍🏫"
type: "tech"
topics: ["ClaudeCode", "Anthropic", "Claude", "AI", "生成AI"]
published: true
---

## この記事で分かること

Claude Code には、コードを全て AI に書かせずに**「あなたにも書かせる」**モードがあります。それが **Learning Mode**。`TODO(human)` マーカーを挟んで、意思決定ポイントで実装を委譲してくる機能です。

一方で情報が断片的で、多くの人が次のような疑問で詰まります：

- 公式ドキュメントを見ると `/config` 経由の説明しかない。でも解説記事では `/output-style learning` が使われている。**どっちが正しい？**
- GitHub の公式リポジトリには Learning が **`unshipped`**、Explanatory が **`deprecated`** と書かれている。**まだ動く？**
- Learning Mode と Explanatory Mode の**使い分け**がわからない
- セッション内で `/output-style` を打ったのに**切り替わらない**のはなぜ？

本記事では、

- 公式ドキュメントと現場ユースケースの**矛盾を整理**
- `TODO(human)` マーカーで動く**ペアプログラミング体験**の実態
- 5つの**ワークフローパターン**と7つの**アンチパターン**
- チーム導入時の**定量目安**

までを、公式Docs・GitHub・Boris Cherny 本人の発言を横断して整理します。

:::message
**対象読者**: Claude Code を実務で使っている開発者、チーム導入を検討している Tech Lead、新卒・中途の育成担当
:::

---

## Claude Code Learning Mode の「混乱ポイント」を整理しよう

まず、この機能について読者が最初につまずく**3つの混乱**を表で整理します。

| 混乱の源 | 公式Docs の記述 | GitHub Plugin README | 現場の記事・発言 | 結論 |
|---------|----------------|---------------------|----------------|------|
| **起動方法** | `/config` → Output style → Learning | 記述なし | `/output-style learning` | **どちらも動く**。公式推奨は `/config` |
| **Learningのステータス** | 組み込みスタイルとして記載 | `unshipped Learning output style` | Boris Cherny が2025-08に正式発表 | **正式リリース済み**。Plugin READMEが未更新 |
| **Explanatoryのステータス** | 組み込みスタイルとして記載 | `deprecated Explanatory output style` | 公式Docsに現在も掲載 | **利用可能**。Plugin READMEが古い |

### なぜ混乱するのか

Claude Code の Output Styles 機能は、**2段階で公開された**ことが混乱の源です。

1. **第1段階（〜2025年8月）**: コミュニティプラグインとして先行公開
   → GitHub リポジトリの Plugin READMEはこの時期に書かれ、Learningを `unshipped`、Explanatoryを `deprecated` と記述
2. **第2段階（2025年8月15日）**: Boris Cherny（Claude Code作者）がThreadsで2スタイルを**組み込み機能として正式発表**
   → `code.claude.com/docs/en/output-styles` に明記
   → しかし Plugin README は未更新のまま

結果、「公式Docsでは動くのに、GitHubでは `unshipped` と書かれている」という**見かけ上の矛盾**が残っている。

:::message alert
**実用的な結論**: 公式Docs（code.claude.com）の記述が現在の真実。GitHub Plugin README の `unshipped` / `deprecated` は無視してOK。
:::

### `/config` と `/output-style` はどっちを使うべきか

| 場面 | 推奨 | 理由 |
|------|------|------|
| 初めて触る | `/config` | 公式Docsに明記、UIメニューで確認できる |
| 頻繁に切り替える | `/output-style [name]` | タイプ数が少ない |
| チームで標準化 | `.claude/settings.local.json` の直接編集 | Gitコミットして共有できる |
| トラブル時 | `/config` | 現在の状態を確認できる |

**どちらも最終的には同じ**（`settings.local.json` の `outputStyle` フィールドが更新されるだけ）なので、好みで使い分けてOK。

---

## 前提知識：なぜ Learning Mode が必要か

AI に全てを書かせる「全自動コーディング」には共通の落とし穴があります。

> 「Pure agentic development risks developers becoming disengaged.」
> — [Shipyard: Pair programming with Claude Code](https://shipyard.build/blog/claude-code-output-styles-pair-programming/)

教育心理学に **Desirable Difficulty（望ましい困難）** という概念があります。学習者に**適度な負荷**をかけることで、長期記憶と転移学習が促進される現象です。AIに即答させるとこの「望ましい困難」が消え、**短期的には便利だが長期的にはスキルが身につかない**状態になる。

Learning Mode はこの課題への Claude Code 側からの公式解答で、「コードを書く手を動かす量」を意図的に維持するための仕組みです。

---

## Claude Code Learning Mode のセットアップと使い方

### 起動方法3選

#### 方法A: /config メニュー（公式推奨）

```bash
/config
# → メニューから「Output style」を選択
# → 「Learning」を選ぶ
```

[Claude Code公式ドキュメント](https://code.claude.com/docs/en/output-styles) に明記されている正統な手順。

:::message alert
**セッション再起動が必要**。Output Styleはシステムプロンプトに注入されるため、現セッション中には切り替わりません。これはプロンプトキャッシュを安定させるための公式仕様です。
:::

#### 方法B: スラッシュコマンド（ショートカット）

```bash
/output-style learning
```

:::message
公式の `commands` リファレンスページには `/output-style` は明記されていませんが、Claude Code 作者 Boris Cherny 本人のThreads投稿、および Tessl.io・Shipyard 等の解説記事で有効なショートカットとして確認されています。
:::

#### 方法C: 設定ファイル直接編集（チーム導入向け）

```json
// .claude/settings.local.json (プロジェクト単位)
// ~/.claude/settings.json (ユーザー全体)
{
  "outputStyle": "Learning"
}
```

これをリポジトリにコミットすれば、**チーム全員で同じ設定を共有**できます。

### コアとなる「TODO(human)」マーカー

Learning Mode では、Claude Code が**全てを書かず**、意思決定ポイントでユーザーに実装を依頼します。

```python
def calculate_discount(user, cart):
    # 基本ロジックはClaudeが実装
    base = sum(item.price for item in cart.items)

    # TODO(human): VIPユーザー（user.tier == "VIP"）の場合、
    # 15%割引を適用してください。割引後の金額を返すこと。
    pass
```

ユーザーが `TODO(human)` を埋めると、Claude が PRレビュー風にフィードバックを返してくれる仕組み。**シニアエンジニアとのペアプログラミング**に近い体験です。

### Claude が「自動実装する」 vs 「TODOを残す」判断基準

公式プラグインのREADMEに書かれている通り、Claude は以下のように判断します：

**TODO(human) を残す** — 学びの価値が高い判断:
- ビジネスロジック（複数の正解があるもの）
- エラーハンドリング戦略
- アルゴリズム実装
- データ構造の選択
- UX 判断
- 設計パターン・アーキテクチャ選択

**自動実装する** — 判断の余地がないもの:
- ボイラープレート・繰り返しコード
- 設定ファイル・セットアップ
- 単純な CRUD 操作

---

## Explanatory Mode との違い

Output Styles には Learning の他に **Explanatory** もあります。

| 項目 | Explanatory | Learning |
|------|-------------|----------|
| Claude の振る舞い | 全部書く + 解説を追加 | 一部をユーザーに書かせる |
| ユーザーの関与 | 読んで理解する | 手を動かして書く |
| 時間効率 | 速い | 遅い（学習が主） |
| 疲労度 | 低 | 中〜高 |
| 推奨対象 | コードベースの把握 | 新言語/概念の習得 |

比喩で言えば、

- **Default** = 「実装代行の優秀なエンジニア」
- **Explanatory** = 「実装しながら解説してくれる先生」
- **Learning** = 「要所であなたに書かせて指導するメンター」

### 教育的 Insight フォーマット

Learning / Explanatory モードでは、Claude が以下の形式で「Insight」を差し込んできます：

```
★ Insight ─────────────────────────────────────
この実装で Map 型ではなく Set 型を選んだ理由は、重複チェックが
O(1) で済むこと、そして本コードベースの `UserRegistry` が
同じパターンを採用しているためです。

トレードオフ: メモリ使用量は若干増えますが、
10,000ユーザー規模では差はミリ秒単位です。
─────────────────────────────────────────────────
```

この「理由の言語化」が、Default モードでは失われがちな**設計判断の学習機会**を復活させます。

---

## 5つのワークフローパターン

### パターン1: 新言語習得（Rust / Go / Elixir）

```bash
/output-style learning
```

「Rust で simple HTTP server を作って」と依頼 → Claude が基本構造を書き、`borrow checker` 絡みの判断ポイントで `TODO(human)` を挿入 → 所有権・借用の実践的理解が得られる。

**向いている教材**: Rust、Haskell、Elixir など「概念的に難しい」言語ほど効果的。

### パターン2: 新卒・中途エンジニア研修

組織ルールとして「入社後3ヶ月は Learning Mode 強制」を設定。`.claude/settings.local.json` をリポジトリにコミットし、チーム全体で共有。

3ヶ月後に Default に昇格する「卒業式」を設けると、新人のマイルストーンにもなります。

### パターン3: デバッグスキル向上

バグ修正依頼時、Claude が症状を再現するテストを書き、**原因特定ステップ**（ログ追加箇所、ブレイクポイント判定、二分探索のcommit）を `TODO(human)` でユーザーに委譲。

AIが全部直してしまうと、「なぜこうなっていたのか」の学習機会が丸ごと消えます。

### パターン4: React Hooks の使い分け学習

既存コンポーネントのリファクタリング依頼 → Claude が最適化ポイントで `TODO(human)` を置き、「ここは `useMemo` か `useCallback` か、依存配列は何にすべきか」をユーザーに判断させる。

### パターン5: ペアプログラミング（人間2名 + Claude 1）

モブプロ形式で Learning Mode を使用。2人の人間が相談しながら `TODO(human)` を埋め、Claude がレビュアー役を務める。**最強のレベルアップ環境**。

Claude Code の出力がホワイトボード代わりになるので、1時間で通常1週間分の学習効果が得られます（体感ベース）。

---

## 公式ドキュメントのベストプラクティス

> Output styles directly modify Claude Code's system prompt.
>
> — [Claude Code 公式ドキュメント: Output styles](https://code.claude.com/docs/en/output-styles)

### 推奨1: セッション時間を30〜45分で区切る

Learning Mode は頭を使うため、長時間セッションは疲労で学習効率が落ちます。**Pomodoro単位の運用**が推奨。

### 推奨2: `keep-coding-instructions: true` を検討する

カスタム Output Style 作成時、コーディング系の組み込み指示を残したい場合は以下をフロントマターに追加：

```markdown
---
name: Rust Learning Coach
description: Rustの所有権と借用を重点的に教える
keep-coding-instructions: true
---

# Rust Learning Coach 指示

あなたは Rust 言語を教えるペアプロ相手です。
Rust の所有権・借用・ライフタイムに関わる判断ポイントで
TODO(human) を挿入してください。そのほかのボイラープレートは自動で書いてください。
```

これを `.claude/output-styles/rust-coach.md` に保存すれば、あなた専用の学習コーチが完成します。

### 推奨3: トークン消費を `/compact` で管理

Learning / Explanatory は**出力トークンが10〜30%増加**するため、長時間セッションでは `/compact` でコンテキスト整理を忘れずに。

---

## やりがちなアンチパターン 7選

### 1. 納期直前に Learning Mode を使う

:::message alert
焦りの中で `TODO(human)` に答えられず、精神的負荷が増大します。Learning Mode は**学習投資の時間枠**で使うべきで、納期直前は Default が合理的。
:::

### 2. GitHub Plugin README の `unshipped` / `deprecated` を信じる

「Learning は未リリース」「Explanatory は廃止」と誤解して使わない人がいますが、**これはPlugin READMEが古いだけ**。Boris Cherny が2025年8月に正式発表済みで、公式Docsにも明記されています。

### 3. Learning Mode を常用する

速度低下が利益を上回る場面があります。**週1日「Learning Day」** など、意図的スキル投資の時間枠に限定するのが現実解。

### 4. 大規模リポジトリで Learning Mode

コードベースが巨大すぎると、`TODO(human)` の文脈が複雑化してユーザーが判断できなくなります。**小モジュール・小ファイルに限定**して使用してください。

### 5. 新人にカスタマイズなしの Default Learning を渡す

組み込みLearning の説明は英語混じり・専門用語多め。**役割・スキル適合のカスタムOutput Style**を `.claude/output-styles/` に作って渡しましょう。

### 6. `/output-style` を打った直後に結果を期待する

**セッション再起動必須**。打った直後には切り替わりません。これは仕様（プロンプトキャッシュ安定のため）です。

### 7. 設定ファイルに `outputStyle: "learning"`（小文字）と書く

正しくは `"Learning"`（頭大文字）。**小文字はエラーにはならず単に無視される**ので、気づきにくい罠です。以下が正解：

```json
{
  "outputStyle": "Learning"  // Default / Explanatory / Learning（頭大文字必須）
}
```

---

## Learning Mode 使用時の定量目安

| 条件 | 推奨値 | 理由 |
|------|--------|------|
| 1セッションの時間 | 30〜45分 | 集中力の持続限界 |
| 1日のLearning Mode利用 | 最大2時間 | 残りはDefaultで生産性確保 |
| `TODO(human)` あたりの所要時間 | 5〜15分 | 超える場合は粒度過大、分割推奨 |
| 追加トークンコスト | +10〜30% | Learning特有の説明増加分 |
| チーム導入の最適人数 | 1-3名 | 全員同時はワークフロー阻害 |
| 新人卒業目安 | 3ヶ月 | Learning → Default 移行の標準 |

---

## 関連機能との比較

| 機能 | 何をするか | Learning Modeとの違い |
|------|-----------|---------------------|
| **Output Styles** | システムプロンプトを書き換える | Learning/Explanatory/Default はこれの一種 |
| **CLAUDE.md** | プロジェクト知識をユーザーメッセージとして追加 | プロンプトを置換しない |
| **--append-system-prompt** | システムプロンプトの末尾に追記 | Default指示を消さない |
| **Sub-agents** | タスク特化エージェントを呼び出す | Output Stylesはメインループに作用 |
| **Skills** | ユーザーがスラッシュで呼ぶワークフロー | 常時アクティブではない |
| **Plugins** | コマンド・スキル・Output Stylesを一括配布 | 配布メカニズム、構成要素の一つ |

---

## 実践チェックリスト

### 導入時
- [ ] Claude Code v2.0以降を確認
- [ ] `/config` → Output style → Learning を選択 **または** `/output-style learning` を実行
- [ ] セッション再起動した
- [ ] `/config` で `Output style: Learning` を確認した
- [ ] `.claude/settings.local.json` の `outputStyle` を確認した
- [ ] 複雑な依頼で `TODO(human)` が挿入されることを確認した

### チーム運用時
- [ ] `.claude/settings.local.json` をリポジトリにコミットした
- [ ] カスタムOutput Styleを `.claude/output-styles/` に配置した
- [ ] 新人の卒業目安（3ヶ月）をドキュメント化した
- [ ] 週1日の「Learning Day」をチームカレンダーに登録した

### トラブル時
- [ ] セッション再起動を試した
- [ ] `settings.local.json` の `outputStyle` の **大文字小文字**を確認（`Learning` が正解）
- [ ] Claude Codeのバージョンを確認（`claude --version`）
- [ ] GitHub Plugin README の `unshipped` 記述に惑わされていないか確認

---

## まとめ

- **要点1**: Claude Code Learning Mode は `/output-style` 機能の組み込みスタイル。`/config` または `/output-style learning` で起動
- **要点2**: 核心は `TODO(human)` マーカーによるペアプログラミング体験
- **要点3**: GitHub Plugin README の `unshipped` / `deprecated` 記述は古い情報。公式Docsが真実
- **要点4**: Explanatory は「解説付き実装」、Learning は「ユーザーに書かせる」。用途で使い分け
- **要点5**: 常用せず「学習投資の時間枠」で使う。新人は3ヶ月で Default 卒業が目安

AI は「実装代行マシン」だけでなく「指導するメンター」にもなれます。Learning Mode はその入口。まずは今日、`/output-style learning` を1セッションだけ試してみてください。

---

## 参考リンク

**公式ドキュメント**
- [Claude Code Output Styles 公式ドキュメント](https://code.claude.com/docs/en/output-styles)
- [Claude Code 公式ドキュメント](https://code.claude.com/docs/en/overview)
- [GitHub: anthropics/claude-code Learning Output Style Plugin README](https://github.com/anthropics/claude-code/blob/main/plugins/learning-output-style/README.md)

**コミュニティ解説**
- [Shipyard: Pair programming with Claude Code](https://shipyard.build/blog/claude-code-output-styles-pair-programming/)
- [Tessl: Claude Code now lets you customize its communication style](https://tessl.io/blog/claude-code-now-lets-you-customize-its-communication-style/)
- [azukiazusa.dev: Claude Code Learning Mode](https://azukiazusa.dev/blog/claude-code-learning-mode/)

**Boris Cherny（Claude Code 作者）の発表**
- [Threads: Explanatory と Learning の2スタイル発表](https://www.threads.com/@boris_cherny/post/DNYwCIByqxl)

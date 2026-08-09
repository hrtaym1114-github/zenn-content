---
title: "【2026年最新】Agent Skills を整理する — google/addyosmani/mattpocockの違いと選び方"
emoji: "📚"
type: "tech"
topics: ["ClaudeCode", "AI", "GitHub", "AIエージェント"]
published: true
---

<!--
## メタデータ（Obsidian管理用・Zenn側には公開されない）
- **ステータス**: 下書き
- **スラッグ**: agent-skills-repos-comparison-2026
- **ファクトチェック**: 済（2026-08-09 Genspark / [[20260809_zenn-agent-skills-repos-comparison-2026-factcheck]]）
- **ファクトチェック修正**: 済（2026-08-09 計7箇所修正：rough edges差替／addy・google 2ステップ／agentskills.io／skills.sh／参考リンク6件／AGENTS.md注記。※作成日はGitHub API実証でgsk指摘を却下・記事が正しい）
- **鮮度レビュー**: 済（2026-08-09 as-of / Outdated: 2件→対応済：2ステップ・skills.sh追記）
- **網羅性レビュー**: 済（2026-08-09 critic / Missing: 4件→対応済：参考リンク6件・AGENTS.md注記追加）
- **Spiral適用**: 済（2026-08-09 humanize / 範囲: リード・所感・まとめ）
- **as-of**: 2026-08-09（star数・リポジトリ構成はこの時点）
-->

## この記事で分かること

XやGitHubで「Agent Skills」と探すと、似たような名前のリポジトリが次々出てきて困りませんか。

- `google/skills`
- `addyosmani/agent-skills`
- `mattpocock/skills`
- さらに `obra/superpowers`

どれも「Agent Skills」を名乗り、どれも星がたくさん付いていて、**結局自分はどれを入れればいいのか分からない** – という状態に私は何度もなりました。

この記事は、その「どれを選ぶか」を1本で解決します。結論を先に言うと、これらは競合ではありません。**前提にしている標準は1つで、その上に乗るスキル集（コレクション）のドメインが違う**だけです。

読み終えると、次ができるようになります。

1. **4つのコレクションが、それぞれ何のためのものか一言で言える**
2. **自分の状況（Google Cloudを使う／TDDを徹したい／個人開発を速くしたい）に合った1つを選べる**
3. **複数を同時に使うときの衝突を避けられる**

:::message
**対象読者**: Claude Code・Codex等のAIコーディングエージェントを使い始め、「Agent Skills」系のリポジトリが乱立していてどれを導入すべきか迷っているエンジニア。
:::

> **補足**: 本記事は「**どのスキル集を入れるか**」を選ぶ記事です。Agent Skillsという**仕組み**自体（標準／実装／方法論の3レイヤー）を整理したい方は、姉妹記事『AGENTS.mdとAgent Skillsの使い分け完全ガイド』をどうぞ。本記事はその「Layer 3：コンテンツ」に当たる部分を深掘りします。

---

## [★]「Agent Skills」は4種類ある — まずドメインで分ける

混乱の最大原因は、**4つすべてを「同じ種類の競合」と並べてしまう**ことです。

実際には、扱っているスキルの**ドメイン（領域）**が決定的に違います。先にこの表を見てください。

| コレクション | 作者 | ドメイン | 一言でいうと |
|---|---|---|---|
| **google/skills** | Google | **Google製品固有** | Google Cloud・GKE・BigQuery等をエージェントに扱わせる |
| **obra/superpowers** | Jesse Vincent | **汎用・自律methodology** | 曖昧な作業を丸投げして朝レビュー、の自律開発 |
| **addyosmani/agent-skills** | Addy Osmani | **汎用・広域SDLC** | 計画→実装→レビュー→shipまでの工程を網羅 |
| **mattpocock/skills** | Matt Pocock | **汎用・個人のClaude Code流儀** | 「grilling」で要件を鋭く詰める個人ワークフロー |

### 最も誤解されやすい：google/skills だけ用途が違う

トレンド記事は4つを「Agent Skills系リポジトリ」と同列に並べがちですが、**`google/skills` の中身は他の3つと別物**です。

README冒頭にこうあります。

> Agent Skills for Google products and technologies, including Google Cloud
>
> — [google/skills README](https://github.com/google/skills)

収録されているのは「Authenticating to Google Cloud」「GKE Basics & Critical Gotchas」「BigQuery AI & ML」「Firebase Basics」「Google Ads API Quickstart」など、**Googleのプロダクトを操作するためのスキル**です。汎用的なコーディング手法ではありません。

つまり「自分のアプリ開発にどれを使おうか」と迷っている人が `google/skills` を入れても、**自分のコードベース向けのスキルはほとんど入っていない**ことになります。この記事で一番最初に伝えたかったのはこれです。

### 残り3つは「汎用エンジニアリング手法」のバリエーション

`obra/superpowers`・`addyosmani/agent-skills`・`mattpocock/skills` は、どれも「AIコーディングエージェントにエンジニアリングの作法を教える」点では共通しています。違うのは**アプローチ**です。

- **superpowers**：エージェントに**自律的に推論・計画させる**重厚なmethodology。subagent駆動＋worktree隔離
- **agent-skills**：SDLCの**全工程を網羅**。レビューを複数ペルソナ（code-reviewer／security-auditor等）で並行実行
- **mattpocock/skills**：作者の**個人のClaude Code使い方**をそのまま抽出。特徴は「grilling」という1問ずつ設計を詰める尋問ループ

この3者の違いは、本記事後半の「5つの選び方パターン」で実例付きで整理します。

:::message alert
**よくある勘違い**:
- ❌ 「4つは競合している」→ **誤り**。前提の標準は1つ（[agentskills.io](https://agentskills.io)）で、その上の異なるドメイン/切り口のコレクション。
- ❌ 「star数が多い方が正解」→ **危険**。後述の通り、star数は各所でバラバラに引用され信頼できないと、比較資料自身が注意喚起しています。
:::

---

## 前提：そもそも「Agent Skills」の標準は1つしかない

ドメインの違いを理解するには、大元の標準を知る必要があります。

> A standardized way to give AI agents new capabilities and expertise.
>
> — [agentskills.io](https://agentskills.io)

Agent Skillsは、[agentskills.io](https://agentskills.io) で定義された**1つのオープン標準**です。スキル＝フォルダ1つで、中に `SKILL.md` を置き、最低限 `name` と `description` を書きます。エージェントは最初に名前と説明だけを読み（Discovery）、タスクに合致したときだけ本文を読み込む（progressive disclosure）という仕組みです。

この標準は**Anthropicが主導**して公開されましたが、その後コミュニティを巻き込んだ議論も起きています。Zennでは次のような批判的な記事もバズりました。

- [Agent SkillsがVercelに乗っ取られそうになっている件について](https://zenn.dev/tkithrta/articles/b7afbf76e7bb31)（注目を集めた話題の記事）
- [Agent Skillsを業務プロダクトに導入してはいけない](https://zenn.dev/ncdc/articles/206fbad44d1dba)（注目を集めた話題の記事）

重要なのは、**本記事で扱う4つのコレクションはすべて、この1つの標準に準拠している**ということです。それぞれの `SKILL.md` に `name`+`description` のfrontmatterがあり、`.agents` ディレクトリと `.claude-plugin` を併置して複数環境に対応しています。

つまり4者は「標準を巡る競合」ではなく、**「同一の標準プラットフォーム上で、異なるドメインのスキルを配布している」**関係です。これが分かると、選び方は劇的にシンプルになります。

---

## 各コレクションのインストール方法

4つとも共通のCLI `npx skills add`（[vercel-labs/skills](https://github.com/vercel-labs/skills) 提供の汎用CLI）か、各ハーネスのプラグイン機能で入れます。スキルの検索・一括インストールは [skills.sh](https://skills.sh)（Vercel運営のハブ）も使えます。

### google/skills（Google製品固有）

```bash
npx skills add google/skills
# または Claude Code の場合（2ステップ）
claude plugin marketplace add google/skills
claude plugin install <プラグイン名>@google-plugins
```

Google Cloud・GKE・BigQuery等を扱うプロジェクトでのみ意味があります。Apache-2.0ライセンス。

### addyosmani/agent-skills（広域SDLC）

```bash
npx skills add addyosmani/agent-skills
# または Claude Code の場合（2ステップ）
/plugin marketplace add addyosmani/agent-skills
/plugin install agent-skills@addy-agent-skills
```

Claude Code・Codex・Cursor・Gemini CLI・Windsurfなど**10以上のハーネス**向けの手順がREADMEに個別に書かれています。MIT。

### mattpocock/skills（個人のClaude Code流儀）

```bash
# Claude Code 公式マーケットプレイス入り
claude plugins install mattpocock-skills
# または汎用CLI
npx skills@latest add mattpocock/skills
```

Claude Codeファーストです。Codex等は `npx skills add` 経由で入れられますが、ネイティブのCodex pluginはREADMEで「roadmap」と明記されています。MIT。

### obra/superpowers（自律methodology）

```bash
# Claude Code 公式マーケットプレイス
/plugin install superpowers@claude-plugins-official
# または作者のマーケット経由
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

複数ハーネス対応ですが、導入手順はハーネスごとに異なります。公式READMEの該当環境向け手順を確認してください。MIT。

---

## [★] 5つの選び方パターン

実務で遭遇する典型シナリオを5つ挙げます。

### パターン1: Google Cloud / GKE / BigQuery を扱うなら

- **選択**: **google/skills 一択**
- **理由**: 他の3つにはGoogleプロダクト固有のスキルは入っていません。GKEのCritical GotchasやBigQueryのAI/ML操作をエージェントに任せたい場合は、これ以外に選択肢がありません。
- **注意**: Google製品を使わないプロジェクトでは**ほぼ無意味**です。誤って「汎用スキル集」として入れないこと。

### パターン2: 「設計から実装までエージェントに丸投げしたい」

- **選択**: **obra/superpowers**
- **理由**: superpowersは、曖昧で大きな作業をエージェントに投げ、朝レビューする、という**自律推論重視のmethodology**です。subagent駆動開発＋git worktree隔離＋厳格なパイプライン（brainstorm→plan→TDD→review→merge）を提供します。
- **向いている人**: 「タスクを細分化するのは面倒、エージェントに任せたい」中〜上級者

### パターン3: 「工程ごとの作法を網羅的に入れたい」

- **選択**: **addyosmani/agent-skills**
- **理由**: spec-driven-development・test-driven-development・code-review-and-quality・security-and-hardeningなど、**SDLC全工程**（Define→Plan→Build→Verify→Review→Ship）を24個のスキルで網羅します。レビューを code-reviewer／security-auditor／test-engineer／web-performance-auditor の**複数ペルソナで並行実行**するのが特徴。
- **向いている人**: チームでエンジニアリング規約を統一したい人。Googleの『Software Engineering at Google』を典拠としている点も、文化に馴染みがあれば腑に落ちやすいはず。

### パターン4: 「Claude Code 個人開発で、要件を鋭く詰めたい」

- **選択**: **mattpocock/skills**
- **理由**: 作者Matt Pocock自身の `.agents` ディレクトリから抽出した**個人の実践ワークフロー**です。最大の特徴は **grilling**（grill-me／grill-with-docs）。決定木を1問ずつ解いていく尋問ループで、**要件定義が最も鋭い**と評価されています。tdd・diagnosing-bugs・wayfinder等も収録。
- **注意**: READMEが「ネイティブのCodexプラグインは roadmap（開発予定）」と正直に書いています。Claude Code専業なら最適ですが、Codex中心の人は `npx skills add` 経由で入れる必要があります。

### パターン5: 複数を組み合わせたい

- **選択**: **ドメインが違うものは併用可、router系は1つに**
- **理由**: 例えば「google/skills（Google Cloud用）＋ addyosmani/agent-skills（SDLC用）」のように、**ドメインが重ならない組み合わせ**なら問題ありません。
- **注意**: ただし superpowers と agent-skills のように、どちらも「ワークフローを制御するrouter」を持つmethodologyを**同時に有効にすると衝突します**。詳細は次節の公式注意喚起を参照。

---

## [★] 公式ベストプラクティスと、併用時の注意

`addyosmani/agent-skills` は `docs/comparison.md` という**公式の3者比較ドキュメント**を公開しています。これが現時点で最も信頼できる一次比較資料です。

> 個別のスキルをcherry-pick（部分採用）するのはOK。しかし、2つのactive router（ワークフロー制御の本体）を同時に実行すると衝突する。
>
> — [addyosmani/agent-skills docs/comparison.md](https://github.com/addyosmani/agent-skills/blob/main/docs/comparison.md)（要約）

このドキュメントが3者（agent-skills／superpowers／Pocock）をどう位置づけているか、要点を抜き出します。

- **agent-skills（addyosmani）**：広いライフサイクル覆盖。アンチ合理化テーブル、CI対応の3層evalフレームワーク付き
- **Superpowers（obra）**：自律・推論重視のmethodology。「大きく曖昧な作業を丸投げして朝レビュー」向け
- **Matt Pocock's skills**：個人のClaude Codeワークフロー。要件定義が最も鋭い

### star数で選ばない — 比較資料自身の注意喚起

comparison.md には、こんな注記があります。

> *(We deliberately leave out star counts…: they are cited wildly differently across blogs and change weekly.)*
>
> — [同上](https://github.com/addyosmani/agent-skills/blob/main/docs/comparison.md)

「star数は各ブログでバラバラに引用され、毎週変わるから信頼できない」。本記事でも、参考までに※2026年8月時点の数値を掲載しますが、**選択の根拠にはしません**。

| コレクション | ※2026年8月時点のstar | 作成日 |
|---|---|---|
| obra/superpowers | 約269,000 | 2025-10-09（先駆け） |
| mattpocock/skills | 約210,000 | 2026-02-03 |
| addyosmani/agent-skills | 約85,000 | 2026-02-15 |
| google/skills | 約17,000 | 2026-03-31 |

superpowersが最も古く・最も大きいことが分かります。この領域の**先駆け**であり、3コレクションはその後に登場した後発です。

---

## [★] やりがちなアンチパターン7選

### 1. star数で選ぶ

:::message alert
**問題**: star数が多い＝自分に合う、ではない。comparison.md自身がstar数の信頼性に注意喚起しています。また、star数の割にコミュニティでの実討論が薄いケースもあります。
**対策**: ドメインと自分のワークフローで選ぶ。star数は「活動量の目安」程度に。
:::

### 2. google/skills を汎用エンジニアリングスキルと勘違いする

READMEの「Google Cloud」を見落とし、「Agent Skills集だから」と入れると、自分のコードベース向けスキルが入っていないことに後で気づきます。**Googleプロダクトを扱う人専用**と覚えてください。

### 3. router系のmethodologyを同時に有効にする

superpowers と agent-skills のように、どちらもワークフローを制御するrouterを持つものを同時に有効化すると、**どちらのフローに従うか衝突**します。部分採用（個別スキルのみ）はOK。全体を有効にするrouterは1つに。

### 4. 業務プロダクトに評価なしで導入する

Zennで「Agent Skillsを業務プロダクトに導入してはいけない」（117 likes）と指摘がある通り、**自分のプロジェクトの文脈と合うか検証してから**導入してください。個人開発で試し、効果と副作用を測ってからチーム展開が安全です。

### 5. 標準（name + description）を無視してハーネス固有機能に依存する

コレクション内のスキルが `allowed-tools` 等の特定ハーネス機能に依存していると、ハーネスを変えたときに動きません。複数ハーネスを行き来するなら、**標準コア（name + description + 本文）だけで書かれたスキル**を優先して採用してください。

### 6. 古いforkを使い続ける

これらのコレクションは週単位で更新されます。数ヶ月前にforkしたものを使い続けると、最新のSKILL.md形式や非推奨フラグに追従できません。公式リポジトリを直接参照するか、pluginの更新機能を使いましょう。

### 7. 自作スキルと名前衝突させる

`tdd` や `code-review` のような一般名のスキルを自作すると、コレクション側と衝突して**どちらが発火するか不明**になります。自作スキルには `myteam-` のような接頭辞を付けてください。

---

## あなたはどれを選ぶべきか — 判定フロー

迷ったときの判定表です。

| あなたの状況 | 推奨 | 理由 |
|---|---|---|
| Google Cloud / GKE / BigQuery を扱う | **google/skills** | 専用スキルしか入っていない |
| 大きな作業を丸投げして朝レビューしたい | **obra/superpowers** | 自律推論のmethodology |
| 計画→実装→レビュー→ship の工程を網羅したい | **addyosmani/agent-skills** | SDLC全工程＋複数レビューペルソナ |
| Claude Code 個人開発で要件を鋭く詰めたい | **mattpocock/skills** | grilling による尋問ループ |
| とりあえず1つ試したい（Claude Code中心） | **mattpocock/skills** か **superpowers** | 導入ハードルが低く、効果を実感しやすい |

:::message
**判断のコツ**:
- 「**Googleのプロダクト**を扱いたい」→ google/skills
- 「**エージェントに開発を任せる作法**を入れたい」→ superpowers / agent-skills / mattpocock から、自分のスタイルに合うものを1つ
- 「**個人Claude Codeの生産性**を上げたい」→ mattpocock/skills
:::

---

## 4コレクション比較表

| 項目 | google/skills | obra/superpowers | addyosmani/agent-skills | mattpocock/skills |
|---|---|---|---|---|
| **作者** | Google | Jesse Vincent | Addy Osmani | Matt Pocock |
| **ドメイン** | Google製品固有 | 汎用・自律methodology | 汎用・広域SDLC | 汎用・個人CC流儀 |
| **特徴的機能** | GKE/BigQuery/Firebase等 | subagent駆動＋worktree | 複数レビューペルソナ・eval | grilling尋問ループ |
| **主な対応ハーネス** | Claude Code/Codex/Antigravity | 複数（手順は環境による） | 10以上（個別手順あり） | Claude Code first |
| **※star(2026-08)** | 約17,000 | 約269,000 | 約85,000 | 約210,000 |
| **ライセンス** | Apache-2.0 | MIT | MIT | MIT |
| **向いている人** | Google Cloud利用者 | 自律開発したい中上級者 | チームで規約統一したい人 | Claude Code個人開発者 |

※star数は2026年8月時点の参考値であり、選択の主な根拠にはしないでください。

---

## 実践チェックリスト

### 導入前
- [ ] 扱いたいドメインを1つに絞ったか（Google製品固有／汎用エンジニアリング）
- [ ] google/skills を選ぶ場合、本当にGoogleプロダクトを扱うか確認したか
- [ ] AGENTS.md（ドキュメント埋め込み）で代替できないか確認したか（[Vercel調査](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals)では特定ユースケースでスキルより優れる場合も）
- [ ] 業務プロダクトなら、個人開発で一度試してからか

### 導入時
- [ ] router系methodologyを複数同時に有効にしていないか
- [ ] 自作スキルと名前衝突していないか（接頭辞を付けたか）
- [ ] 対象ハーネスが対応しているか（mattpocockをCodex中心で使う場合の注意等）

### 運用時
- [ ] 公式リポジトリを最新に保っているか（古いforkを使っていないか）
- [ ] SKILL.mdが標準（name + description）を満たしているか
- [ ] 副作用のあるスキルが自動発火していないか（明示呼び出し限定にしたか）

---

## まとめ

- **要点1**: 4つのコレクションは競合ではなく、同じ標準（agentskills.io）の上の異なるドメインのコレクション
- **要点2**: **google/skills だけ用途が違う**（Google Cloud等のGoogle製品固有）。他3つは汎用エンジニアリング手法のバリエーション
- **要点3**: 選択はstar数ではなくドメインと自分のワークフローで。比較資料自身がstar数の信頼性に注意喚起している
- **要点4**: router系methodology（superpowers／agent-skills）を同時に有効化すると衝突する。部分採用はOK
- **要点5**: まず1つ選んで1週間試す。設定を増やすより、自分に合った1つを見つける方が生産性に効く

私自身、最初は「starが多い=正解」と4つ全部入れようとして、router同士が衝突してどのスキルが発火しているか分からない状態に陥りました。この記事の比較表が、その回り道を1つ省けたら嬉しいです。

まずは自分の状況を1つ選び、公式リポジトリのREADMEを開いて、記載のインストール手順を1つだけ試してみてください。

---

## 参考リンク

- [Agent Skills 標準（agentskills.io）](https://agentskills.io) — 大元のオープン標準
- [google/skills](https://github.com/google/skills) — Googleプロダクト固有スキル集
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — 広域SDLCスキル集
- [addyosmani/agent-skills docs/comparison.md](https://github.com/addyosmani/agent-skills/blob/main/docs/comparison.md) — 公式3者比較資料（本記事の主要ソース）
- [mattpocock/skills](https://github.com/mattpocock/skills) — 個人Claude Codeワークフロー
- [obra/superpowers](https://github.com/obra/superpowers) — 自律methodology（先駆け）
- [Zenn: Agent SkillsがVercelに乗っ取られそうになっている件について](https://zenn.dev/tkithrta/articles/b7afbf76e7bb31) — 標準主導権を巡る議論
- [Zenn: Agent Skillsを業務プロダクトに導入してはいけない](https://zenn.dev/ncdc/articles/206fbad44d1dba) — 導入時の注意点

### その他の主要コレクション・ハブ

- [skills.sh](https://skills.sh) — Vercel運営のスキル発見・インストールハブ（4コレクションすべて収録）
- [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) — Vercel公式スキル集（npx skills CLI提供元）
- [NVIDIA/skills](https://github.com/NVIDIA/skills) — NVIDIA製品固有スキル集（google/skillsと同カテゴリ）
- [firebase/agent-skills](https://github.com/firebase/agent-skills) — Firebase専用公式スキル集（google/skillsとは別リポジトリ）
- [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) — コミュニティ製1000件超のキュレーション
- [Vercel: AGENTS.md outperforms skills](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals) — 特定ユースケースでAGENTS.mdが優れるというVercel調査

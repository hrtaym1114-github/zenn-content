---
title: "【2026年最新】MiMo Code完全ガイド — Claude Codeと何が違うのか、本当に勝てるのか整理する"
emoji: "🤖"
type: "tech"
topics: ["claudecode", "ai", "oss", "mimocode"]
published: true
---


:::message
この記事は **2026年6月13日時点** の公開情報をもとに整理しています。MiMo Code は v0.1.0 がリリースされたばかりで仕様変更が激しく、コマンドや数値は今後変わる可能性があります。本文中のバージョン依存の記述には `※2026年6月時点` を付けています。
:::

## 1. この記事で分かること

スマホメーカーのXiaomiがOSSで公開したAIコーディングエージェント **「MiMo Code」** が、「**ブラインドテストでClaude Codeに勝った**」と主張し、2026年6月10日前後に一気に話題になりました（GIGAZINE はてブ82users、Hacker News 352pt）。わずか5人のチームが14日で作り上げたという開発スピードも注目を集めています。

ただ、結論から言えば、**鵜呑みにするのは危険です**。その「勝った」という数字は第三者検証のない自己申告であり、公開直後のv0.1.0ではユーザーのnpmパッケージを無確認で削除するという事故まで報告されています。さらにこの話題には、ニュースを読むだけでは混乱しやすいポイントが4つ重なっています。

- **「MiMo」という名前が複数のものを指す** — Xiaomiには `MiMo-7B` や `MiMo-V2.5` という **LLMシリーズ** が前から存在し、今回の `MiMo Code` は別物（ツール）です
- **「Claude Code vs MiMo Code」の比較軸が曖昧** — モデルの勝負なのか、ハーネス（CLIの作り）の勝負なのかが混同されがち
- **「勝った」というベンチ主張の真偽** — どの数値が第三者検証済みで、どれが自己申告なのか
- **日本語の一次情報がほぼゼロ** — 公式README・各種ニュースが英語中心

この記事は「使ってみた感想」ではなく、**これらの混乱を最短で整理する**ことをゴールにします。読み終えると「MiMo Codeとは結局何で、Claude Codeとどう違い、いま導入すべきか」を自分で判断できる状態になります。

---

## 2. 【混乱ポイントの整理】MiMo Code とは何で、何でないか

ここが本記事の核心です。MiMo Code を語る前に、**3つの「MiMo」を分離**しておかないと、ニュースを読むたびに混乱します。

### 「MiMo」はXiaomiのAIブランド名（特定の1製品ではない）

`MiMo` は Xiaomi が自社のAI製品群につける **ブランド名** であって、特定の1製品を指す言葉ではありません。Wikipedia でも "a family of large language models (LLMs) developed by Xiaomi"（Xiaomi製のLLM**ファミリー**）と説明されています（[Wikipedia: Xiaomi MiMo](https://en.wikipedia.org/wiki/Xiaomi_MiMo)、※2026年6月時点）。

:::message
なお「`MiMo` = Mi Model（Xiaomi Model）の略」とする説明を見かけることがありますが、公式README・原論文（[arXiv:2505.07608](https://arxiv.org/abs/2505.07608)）・Wikipedia のいずれにも**この略称の明確な定義は確認できません**。由来は公式には未確定と理解しておくのが安全です（※2026年6月時点）。
:::

重要なのは略語の由来ではなく、**同じ「MiMo」という名称が、複数のまったく別のもの（モデル群とツール）に付けられている**という事実です。これが混乱の根本的な原因になっています。

### 整理: 3つの「MiMo」

| 名前 | 種類 | 何か | 公開時期 |
|------|------|------|---------|
| **MiMo-7B / MiMo-V2 / MiMo-V2.5** | **LLM（モデル）** | 推論・コード特化の言語モデル本体 | MiMo-7B: 2025年4月 〜 V2.5: 2026年4月 |
| **MiMo-VL / MiMo-Audio** | **マルチモーダルLLM** | 画像・音声対応のモデル | 2025〜 |
| **MiMo Code** | **ハーネス（CLIツール）** | ターミナルで動くAIエージェント本体 | **2026年6月10日前後** |

出典: [Xiaomi MiMo (Wikipedia)](https://en.wikipedia.org/wiki/Xiaomi_MiMo)、[XiaomiMiMo/MiMo (GitHub)](https://github.com/XiaomiMiMo/MiMo)（※2026年6月時点）

:::message
**最重要の区別**: `MiMo-V2.5` は**モデル**（頭脳）、`MiMo Code` は**ハーネス**（モデルを動かすCLIの器）。ニュースで「MiMoが勝った」とあるとき、それがモデルの話かハーネスの話かで意味がまったく変わります。後述のベンチマーク検証（H2-7）で、この区別が決定的に効いてきます。
:::

### MiMo Code とは何か（What it is）

公式READMEによれば、MiMo Code は **ターミナルネイティブのAIコーディングアシスタント** です（[XiaomiMiMo/MiMo-Code README](https://github.com/XiaomiMiMo/MiMo-Code/blob/main/README.md)、※2026年6月時点）。位置づけとしては **Claude Code / OpenCode と同じカテゴリ** のツールで、実際に **OpenCode をフォークして作られています**（[BigGo Finance](https://finance.biggo.com/news/V2znu54BJ9W2lKGkFA_y)、※2026年6月時点）。

主な特徴（READMEより）:

- **build / plan / compose の複数モード**（Claude CodeのPlan Modeに近い思想）
- **SQLite FTS5 による全文検索を使ったクロスセッションメモリ**（セッションをまたいでプロジェクト知識を保持）
- **サブエージェントのオーケストレーション**
- **音声入力**
- **goal-driven autonomous loop（目標駆動の自律ループ）**
- ライセンスは **MIT**（ソースコード部分。ホスティングサービスには別途利用規約あり）

### MiMo Code とは何でないか（What it is NOT）

- ❌ **新しい万能モデルではない** — MiMo Code は「器（ハーネス）」であり、頭脳は別のモデル（MiMo Auto / MiMo Platform / OpenAI互換API）を使う
- ❌ **Claude Codeの完全な置き換えではない** — 後述するように安定性に重大な課題がある（v0.1.0）
- ❌ **ゼロから書かれた独自プロダクトではない** — OpenCodeフォークで、内部パッケージ名を `@opencode-ai/*` → `@mimo-ai/*` にリネームしている（[BigGo Finance](https://finance.biggo.com/news/V2znu54BJ9W2lKGkFA_y)、※2026年6月時点）

---

## 3. なぜ今 MiMo Code が話題なのか

3つの要因が重なって短期間でバズりました。

1. **「Claude Codeに勝った」という挑発的な主張** — Anthropicの事実上の標準ツールに、大企業が真っ向から挑戦状を出した構図がニュース性を持った
2. **OSS（MIT）+ 大企業製という意外性** — スマホメーカーのXiaomiがコーディングエージェントを無料公開したギャップ
3. **公開直後の急成長** — 2週間で **GitHub 5,100スター超**、わずか **5人チームが14日間** で作ったという開発スピード（[BigGo Finance](https://finance.biggo.com/news/V2znu54BJ9W2lKGkFA_y)、※2026年6月時点）

ただし話題性と品質は別物です。同じ期間に **GitHub Issuesが200件超** 積み上がり（後述）、「バズと炎上が同時進行」しているのが現状です（※2026年6月時点）。

---

## 4. セットアップ・インストール

公式READMEに記載されたインストール方法は以下です（[XiaomiMiMo/MiMo-Code README](https://github.com/XiaomiMiMo/MiMo-Code/blob/main/README.md)、※2026年6月時点）。

### macOS / Linux

```bash
curl -fsSL https://mimo.xiaomi.com/install | bash
```

### npm（Windows含むクロスプラットフォーム）

```bash
npm install -g @mimo-ai/cli
```

:::message alert
`curl | bash` 形式のインストールは、スクリプトの中身を確認せずに実行することになります。業務環境では一度スクリプトを `curl` で取得して目視してから実行する、もしくは npm 経由を選ぶことを推奨します。
:::

### モデルプロバイダの選択肢

MiMo Code は「ハーネス」なので、動かすモデルを選びます。READMEに記載のある選択肢（※2026年6月時点）:

- **MiMo Auto**（組み込み・期間限定で無料）
- **Xiaomi MiMo Platform**（OAuth認証）
- **OpenAI互換のカスタムAPI**
- **Claude Code の認証情報をインポート**して流用

「MiMo Auto は期間限定無料」と明記されており、将来的に課金へ移行する可能性が示唆されています。**長期コストは現時点（v0.1.0）では未確定**です。

---

## 5. 核心機能・使い方

MiMo Code の設計思想は「**長時間・多ステップのタスクをどう破綻させずに走らせるか**」に寄っています。これが後のベンチマーク主張の根拠にも直結します。

### クロスセッションメモリ

最大の差別化ポイントが **SQLite FTS5（全文検索）ベースの永続メモリ** です。セッションをまたいでプロジェクトの理解・タスク階層を保持し、長期タスクで「コンテキストを忘れる」問題を緩和する設計です（[XiaomiMiMo/MiMo-Code README](https://github.com/XiaomiMiMo/MiMo-Code/blob/main/README.md)、※2026年6月時点）。

### 複数モード（build / plan / compose）

- **plan**: 実装前に計画を立てる（Claude CodeのPlan Modeに近い）
- **build**: 実際にコードを読み書き・コマンド実行・Git操作
- **compose**: ワークフローを組み立てる

### SKILL.md の JavaScript 変換

GIGAZINE によれば、MiMo Code は **自然言語で書かれた `SKILL.md` をJavaScriptコードに変換して決定論的に実行する** 仕組みを持つとされています（[GIGAZINE](https://gigazine.net/gsc_news/en/20260611-xiaomi-mimo-code/)、※2026年6月時点）。「曖昧な自然言語の手順」を「再現性のあるコード」に落とす発想です。

### 長時間タスク対策

長いセッションでは**セッションサマリーを抽出して新しいセッションを開始する**メカニズムで、コンテキスト肥大を回避します（[GIGAZINE](https://gigazine.net/gsc_news/en/20260611-xiaomi-mimo-code/)、※2026年6月時点）。

---

## 6. MiMo Code でできる 6つのこと / 使いどころパターン

READMEと各種報道から整理した、MiMo Code が想定する使いどころです（※2026年6月時点）。

1. **コードの読み書き** — 通常のコーディングエージェントとして
2. **コマンド実行・Git操作** — ターミナル内で完結
3. **超長尺タスクの実行** — 200ステップ超の多段階ワークフロー（ここが主張上の強み）
4. **クロスセッションのプロジェクト記憶** — 「昨日の続き」を覚えている
5. **サブエージェントのオーケストレーション** — タスクを分割して並列的に処理
6. **音声入力でのコーディング** — 実験的機能

:::message
強みが「**200ステップ超の長尺タスク**」に偏っている点に注意してください。逆に言えば、**短いタスクでは差が出にくい**ことを開発元自身のデータが示しています（H2-7で詳述）。
:::

---

## 7. ベンチマーク主張の検証 — 「Claude Codeに勝利」は本当か

ここが最も誤解されやすい部分です。結論から言うと、**「勝った」という数値はすべて Xiaomi の自己申告であり、第三者検証は2026年6月時点で存在しません**。

### 主張されている数値

Xiaomi が公表している比較（[TechTimes](https://www.techtimes.com/articles/318269/20260612/xiaomi-mimo-code-claims-beat-claude-code-benchmark-scores-are-self-reported.htm)、[VentureBeat報道](https://venturebeat.com/technology/xiaomis-new-open-source-agentic-ai-coding-harness-mimo-code-beats-claude-code-at-ultra-long-200-step-tasks)、※2026年6月時点）:

| ベンチマーク | MiMo Code | Claude Code | 差 |
|------------|-----------|-------------|----|
| SWE-Bench Pro | 62% | 57% | +5pt |
| Terminal Bench 2 | 73% | 68% | +5pt |
| ブラインドテスト（200ステップ超） | **勝率65%** | 35% | — |
| ブラインドテスト（200ステップ未満） | ほぼ50% | ほぼ50% | 差なし |

ブラインドテストは **576人の開発者・474の実プライベートリポジトリ・1,213回のダブルブラインドA/B比較** という規模で行われたとされています（[TechTimes](https://www.techtimes.com/articles/318269/20260612/xiaomi-mimo-code-claims-beat-claude-code-benchmark-scores-are-self-reported.htm)、※2026年6月時点）。

### 数値の「読み方」— ここで誤読が起きる

主張を額面通り受け取る前に、報道が指摘する**3つの注意点**を押さえてください。

**注意1: 第三者検証がない（self-reported）**
これらの数値は Xiaomi が自社インフラ上で内部実施したもので、**Scale AI の SEAL リーダーボード等の第三者評価には載っていません**（[TechTimes](https://www.techtimes.com/articles/318269/20260612/xiaomi-mimo-code-claims-beat-claude-code-benchmark-scores-are-self-reported.htm)、※2026年6月時点）。独立リーダーボードでは上位モデルでも22〜59%のレンジに収まる中、62%という数字は突出して見える、と同記事は指摘しています。

**注意2: 比較相手のモデル選定**
比較で使われたClaude側は **Claude Sonnet 4.6 であり、より高性能な Opus ではない** とされます（[TechTimes](https://www.techtimes.com/articles/318269/20260612/xiaomi-mimo-code-claims-beat-claude-code-benchmark-scores-are-self-reported.htm)、※2026年6月時点）。比較条件の対称性に議論の余地があります。

**注意3: 「ハーネスの勝利」と「モデルの勝利」の混同**
Xiaomi は優位性を **モデルではなくハーネス（エージェント設計）の差** に帰しています。一方でSWE-Bench Pro等は本来「単発のリポジトリ問題を解く能力」を測るもので、測定対象とアピールしたい強み（長尺タスクの状態管理）がズレているという指摘もあります（[TechTimes](https://www.techtimes.com/articles/318269/20260612/xiaomi-mimo-code-claims-beat-claude-code-benchmark-scores-are-self-reported.htm)、※2026年6月時点）。

**注意4: 上表の数値は「公式リーダーボード」とは別物**
上の比較表の「Claude Code 68%（Terminal Bench 2）」も Xiaomi の社内測定値です。**公式の Terminal-Bench 2.0 リーダーボードには MiMo Code 自体が未掲載**で、しかもそこでは Claude Code が（Sonnet より高性能な）**Opus 4.6 でも 58.0%**にとどまります（[Terminal-Bench 2.0 公式リーダーボード](https://www.tbench.ai/leaderboard/terminal-bench/2.0)、※2026年6月時点）。つまり Xiaomi の「68%」を公式リーダーボードの数値と並べて読むことはできません。比較表はあくまで「Xiaomi が自社条件で測った社内ベンチ」として扱ってください。

:::details なぜ「ハーネスの勝利」だと話が変わるのか
ハーネス（CLIの作り）が優れているなら、その工夫は **Claude Code にも OpenCode にも移植可能** です。実際 MiMo Code 自体が OpenCode フォークである以上、「永続メモリ」「セッション要約」といった工夫は他ツールが取り込めます。つまり「MiMo Code が勝った」は「現時点のMiMo Codeの実装が、ある条件で優れたスコアを出した」であって、「Xiaomiのモデルが本質的に優れている」を意味しません。
:::

### 検証の結論

- ✅ **言えること**: Xiaomiは大規模なブラインドテストを実施し、200ステップ超の長尺タスクで65%という数値を**主張している**
- ❌ **言えないこと**: 「MiMo Code は Claude Code より優れている」と断定すること（第三者検証なし・比較条件に議論あり・短尺タスクでは差なし）

:::message
さらに、この比較が固定している「Claude Code 側のモデル」も動いています。Anthropic は **MiMo Code 公開の前日（2026年6月9日）に Claude Fable 5 / Mythos 5 を公開**しました（[Anthropic公式](https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5)、※2026年6月時点）。ベンチで比較対象になった Sonnet 4.6 より新しい世代がすでに出ているため、「Claude Code vs MiMo Code」の力関係は数日単位で変わる前提で読むのが安全です。
:::

---

## 8. やりがちな誤解・アンチパターン 5選

1. **「MiMoモデルが勝った」と誤読する** — 勝ったと主張されているのは**ハーネス（MiMo Code）の設計**であり、モデル単体の性能比較ではありません（H2-2・H2-7参照）
2. **自己申告ベンチを「実測値」として引用する** — SWE-Bench Pro 62% 等は第三者検証されていません。SNSやブログで「MiMo CodeはSWE-Benchでトップ」と断言するのは過剰です
3. **短いタスクでも速い/強いと期待する** — 開発元データ上、200ステップ未満ではClaude Codeとほぼ互角（差なし）です
4. **v0.1.0をいきなり本番・重要リポジトリに入れる** — 公開直後に **エージェントが確認なしにユーザーのグローバルnpmパッケージを削除する**インシデントが報告されています（[BigGo Finance](https://finance.biggo.com/news/V2znu54BJ9W2lKGkFA_y)、※2026年6月時点）。破壊的操作の確認ゲートが不十分なバージョンです
5. **MiMo-V2.5（モデル）とMiMo Code（ツール）を同一視する** — ニュースを追うときに最も多い取り違え。モデルの更新とツールの更新は別軸です

:::message alert
特に **#4 のnpm削除インシデント** は実害のある報告です。テレメトリがデフォルトで有効、メモリリーク、無限推論ループ等の報告もあり、v0.1.0時点では**隔離環境（コンテナ・捨ててよいリポジトリ）での検証にとどめる**のが安全です（[BigGo Finance](https://finance.biggo.com/news/V2znu54BJ9W2lKGkFA_y)、※2026年6月時点）。
:::

---

## 9. Claude Code を使うべきか MiMo Code を使うべきか

「勝った/負けた」ではなく、**自分の状況にどちらが合うか**で判断する材料を整理します（※2026年6月時点）。

### MiMo Code を試す価値があるケース

- **200ステップ超の超長尺タスク**を頻繁に回す（主張上の強みが効く領域）
- **完全OSS・ローカル/自前API構成**にこだわりたい
- 新ツールの検証自体が目的で、**壊れてもよい隔離環境**を用意できる
- コストを抑えたい（MiMo Auto期間限定無料を活用）

### Claude Code を使い続けるべきケース

- **安定性・破壊的操作の安全設計**を最優先する（業務・本番）
- 短〜中尺の日常的なコーディングが中心（差が出にくい領域）
- 既存のClaude Codeワークフロー・MCP・サブエージェント資産がある
- v0.1.0特有のバグ（メモリリーク・削除事故等）を踏みたくない

### 現実的な結論

2026年6月時点では、**Claude Codeをメインに据えつつ、MiMo Codeは隔離環境で評価する**のが穏当な判断です。MiMo Code が持つ本質的な価値（永続メモリや長尺タスク管理）は注目に値しますが、v0.1.0の安定性リスクを本番環境で負う理由はまだ薄い、というのが報道とコミュニティ反応を総合した見立てです。

---

## 10. 関連ツール比較表

ターミナル型AIコーディングエージェントの整理（※2026年6月時点）。

| 項目 | MiMo Code | Claude Code | OpenCode |
|------|-----------|-------------|----------|
| 提供元 | Xiaomi | Anthropic | コミュニティOSS |
| ライセンス | MIT（OSS） | プロプライエタリ | OSS |
| ベース | OpenCodeフォーク | 独自 | 独自 |
| モデル | MiMo Auto / 互換API / Claude認証流用 | Claudeモデル | モデル非依存 |
| 永続メモリ | SQLite FTS5 | あり（独自） | プラグイン依存 |
| 公開 | 2026年6月（v0.1.0） | 提供中 | 提供中 |
| 安定性 | 低（バグ多数報告） | 高 | 中 |
| 強みの主張 | 200ステップ超の長尺 | 総合的な完成度 | 拡張性・自由度 |

:::message
MiMo Code は OpenCode フォークのため、内部パッケージを `@opencode-ai/*` → `@mimo-ai/*` にリネームしています。これにより **OpenCode向けプラグインがそのままでは動かない**ケースが報告されています（[BigGo Finance](https://finance.biggo.com/news/V2znu54BJ9W2lKGkFA_y)、※2026年6月時点）。
:::

---

## 11. 実践チェックリスト

MiMo Code を評価・検証するときの手順です。

- [ ] **隔離環境を用意する**（Dockerコンテナ or 捨ててよいリポジトリ）。本番・重要リポジトリでは試さない
- [ ] インストールは `npm install -g @mimo-ai/cli`、または `curl` スクリプトを**目視してから**実行
- [ ] **テレメトリ設定を確認**し、不要ならオフにする（デフォルト有効の報告あり）
- [ ] 破壊的操作（削除・グローバルパッケージ操作）の**確認ゲートの挙動を最初にテスト**する
- [ ] 評価は**200ステップ超の長尺タスク**で行う（強みが出る領域。短尺ではClaude Codeと差が出にくい）
- [ ] モデルは何を使っているか（MiMo Auto / 互換API）を意識し、コストと無料期間を確認
- [ ] GitHub Issues で**既知の不具合**を確認してから本格利用を判断する
- [ ] ベンチ数値を引用するときは**「Xiaomi自己申告・第三者未検証」と明記**する

---

## 12. まとめ

2026年6月時点での MiMo Code の整理を、要点5つにまとめます。

1. **MiMo Code はモデルではなくハーネス（CLIツール）** — `MiMo-V2.5`（モデル）と `MiMo Code`（ツール）は別物。`MiMo` は Xiaomi が複数のAI製品に付けるブランド名（略語の由来は公式未確定）
2. **OpenCodeフォークのMIT OSS** — Xiaomiの5人チームが14日で公開し、2週間で5,100スター超を獲得
3. **「Claude Codeに勝利」は自己申告** — SWE-Bench Pro 62%等は第三者検証なし。比較相手はSonnet 4.6で、優位は「200ステップ超の長尺タスク」に限定。短尺では差なし
4. **v0.1.0は安定性リスク大** — npmパッケージ削除事故・テレメトリ既定有効・メモリリーク等が報告。本番投入は時期尚早
5. **現実解は「Claude Codeをメイン＋MiMo Codeを隔離環境で評価」** — 永続メモリ・長尺タスク管理という設計思想は注目に値するが、リスクを本番で負う段階ではない

:::message
本記事は2026年6月13日時点の公開情報に基づく整理です。MiMo Code は v0.1.0 で更新が激しく、コマンド・数値・安定性は今後変わる可能性があります。導入判断の前に必ず公式リポジトリの最新状態を確認してください。
:::

### 参考リンク（一次・主要情報源）

- [XiaomiMiMo/MiMo-Code (GitHub)](https://github.com/XiaomiMiMo/MiMo-Code) — 公式リポジトリ・README
- [GIGAZINE: Xiaomi が MiMo Code を公開](https://gigazine.net/gsc_news/en/20260611-xiaomi-mimo-code/)
- [VentureBeat: MiMo Code beats Claude Code at 200+ step tasks](https://venturebeat.com/technology/xiaomis-new-open-source-agentic-ai-coding-harness-mimo-code-beats-claude-code-at-ultra-long-200-step-tasks)
- [TechTimes: Benchmark Scores Are Self-Reported](https://www.techtimes.com/articles/318269/20260612/xiaomi-mimo-code-claims-beat-claude-code-benchmark-scores-are-self-reported.htm)
- [BigGo Finance: 5,100スター・バグ多数の現状](https://finance.biggo.com/news/V2znu54BJ9W2lKGkFA_y)
- [Wikipedia: Xiaomi MiMo（モデルシリーズの整理）](https://en.wikipedia.org/wiki/Xiaomi_MiMo)

---
title: "【2026年最新】Claude Fable 5完全ガイド — Xboxゲームとの混同からモデル選択まで"
emoji: "🎮"
type: "tech"
topics: ["ClaudeCode", "Anthropic", "AI", "LLM"]
published: true
---

## この記事で分かること

「Fable 5」はAIモデル？それともゲーム？ 検索するとXboxのRPGとAnthropicの新モデルが混在していて、どっちを読めばいいか分からない。本記事はその混同を30秒で解いた上で、Claude Fable 5を**実務でいつ使うべきか**（Opus 4.8・Sonnet 5との使い分け、2倍の価格に見合う場面、fallback設計）まで整理する。

:::message
**対象読者**: Claude Code / Claude APIを業務で使い、モデル選択にコスト感覚のあるエンジニア
:::

※本記事の情報は2026年7月14日時点のものです。

---

## [★H2-2] 「Fable」は2つある — まず整理しよう

混乱の元は、**「Fable」という名前がAIモデルとゲームフランチャイズで重なっている**こと。さらにAnthropic内でも「Fable 5」と「Mythos 5」が似た名前で並ぶ。2段階で整理する。

### 第1の混同：Claude Fable 5 vs Fable（Xboxゲーム）

| 項目 | Claude Fable 5 | Fable（Xboxゲーム） |
|------|----------------|---------------------|
| 正体 | AnthropicのLLM | Playground GamesのオープンワールドRPG |
| リリース | 2026-06-09 | 2027-02-23予定 |
| 価格 | $10/$50（1Mトークンあたり） | $69.99〜 |
| 公式の数字 | 「Fable 5」（数字あり） | 「Fable」（リブート・数字なし） |

ゲーム側は初代Fable（2004）・II・IIIに続く**リブート作で、正式タイトルは数字なしの「Fable」**。だが「Fable」単語と「Fable 5」検索でAIモデル記事とゲーム記事が混在する。本記事は**AIモデルの方**を扱う。

### 第2の混同：Fable 5 vs Mythos 5

| 項目 | Claude Fable 5 | Claude Mythos 5 |
|------|----------------|------------------|
| 提供 | 一般提供（API/Bedrock/Vertex/Foundry） | Project Glasswingの承認顧客限定 |
| セーフガード | あり（危険クエリを拒否・フォールバック） | なし |
| 基盤モデル・価格 | 同じ | 同じ |

**要約: Mythos 5の一般向け安全版がFable 5**。同じ基盤で、セーフガード（拒否・フォールバック）の有無だけが違う。Mythos 5にアクセスできない人はFable 5を使えば同等の能力が得られる。

:::message alert
「Fable 5」と「Mythos 5」は**別物ではなく同基盤の提供範囲違い**。Mythos 5だけが特別高性能と誤解しないこと。
:::

---

## 前提知識：なぜFable 5が必要か

これまで一般提供の最上位はOpus 4.8だった。Anthropicはより強力な「Mythos級」基盤を限定的に持っていたが、安全性の懸念から一般には出せなかった。Fable 5は**このMythos級基盤に安全性分類器を載せて一般公開したモデル**。Opus 4.8では力不足の、最も要求の厳しい推論・長期エージェント作業を担う。

ベンチマーク（公式）:

- **SWE-Bench Pro 80.3%**（Opus 4.8の69.2%から+11.1pt）
- **FrontierCode Diamond 29.3%**（Opus 4.8の13.4%の2倍以上）

ただし**価格はOpus 4.8の2倍**（入力$10/出力$50）。能力が要る場面だけに絞るのが前提知識として重要。

---

## Fable 5のセットアップと使い方

### Claude Codeで使う

```bash
# Claude Code v2.1.170以降が必要
/model fable
```

### APIで使う

```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-fable-5",
    "max_tokens": 4096,
    "messages": [{"role":"user","content":"アーキ設計をレビューして"}]
  }'
```

### 提供プラットフォーム

Claude API / AWS上のClaude Platform / Amazon Bedrock / Google Cloud Vertex AI / Microsoft Foundry。Bedrock・Vertex・Foundryは**fallback実装がプラットフォームごとに異なる**ため、後述のアンチパターンを参照。

### サブスクリプションの扱い（※2026年7月14日時点）

無償提供期間は**2度延長され、日本時間7月20日午前3時59分まで**（Pro/Max/Team・Enterpriseの一部）。無償ユーザーも5時間あたり50メッセージまで有料プランと同範囲でアクセス可能。Web・モバイル・デスクトップ・Claude Code・Cowork・Designで追加設定なしで利用できる。

7/20以降はusage credits（別途課金）で継続するかOpus 4.8等へ切り替え。**本番設計をサブスク前提にしてはいけない**（延長は翌週プラン更新へのFable 5標準搭載を意味しない）。

---

## 核心機能・使い方

### 適応型思考が常に有効（オフ不可）

Fable 5では適応型思考（adaptive thinking）が唯一の思考モードで常時ON。`thinking: disabled`は非サポート。深さは**effortパラメータ**で制御: `low / medium / high / xhigh / max`（デフォルト`high`）。

### 生の思考は返らない

思考の連鎖は返却されない。`thinking.display`は`summarized`（要約）か`omitted`（空・デフォルト）。「思考過程を見せて」系の指示は**拒否カテゴリをトリガーする**ため使わない。

### 拒否とフォールバック

危険判定（サイバー・生物・化学）されたリクエストは拒否され、**HTTP 200で`stop_reason: "refusal"`が返る**（エラーではない）。通常は別モデル（多くはOpus 4.8）でフォールバック処理可能。フォールバック3方式:

| 方式 | 概要 | 提供状況 |
|------|------|----------|
| サーバーサイド | `fallbacks`パラメータでAPIが自動再試行 | ベータ |
| クライアントサイド | SDKミドルウェア（TS/Py/Go/Java/C#） | 一般 |
| 手動 | 任意プラットフォーム・言語で自構築 | 一般 |

出力前の拒否は**無課金**。フォールバック時のプロンプトキャッシュ切替コストは**フォールバッククレジットで返金**（二重課金回避）。

---

## [★H2-6] Fable 5を活かす5つのワークフローパターン

### パターン1: アーキテクチャ判断の最終審査
複数案の設計比較など「間違えると高コスト」な判断にFable 5を使う。Sonnet 5が提案を出し、Fable 5が最終裁定する二段構え。

### パターン2: 敵対的検証（Adversarial Verification）
コードを書いたモデルと別モデルで検証するMaker-Checker。Fable 5を検証役に使い「壊れている前提」で評価させる。

### パターン3: 長期エージェント作業
1Mコンテキスト・128k出力を活かした数時間〜数日の自律タスク。途中チェックインを減らせる。

### パターン4: 大規模リファクタリング
repo級のリファクタで全体整合性を見る。Opus 4.8でも対応可能だが、より高い推論が要る案件はFable 5へ。

### パターン5: Cheap fan-out, expensive judgment
Haiku 4.5が100ファイルを読み、Fable 5が「それが何を意味するか」を判定する構成。トークン単価ではなく**判断の質**でFable 5を位置づける。

---

## [★H2-7] 公式ベストプラクティス

Anthropic公式プロンプティングガイドとモデル選択ガイドから要点を引く。

> **難しい仕事で試す** — 簡単な一問一答では能力を過小評価しがち。調査・設計レビュー・コード調査・資料化が適している。
> — [Claude Fable 5 のプロンプティング（公式）](https://platform.claude.com/docs/ja/build-with-claude/prompt-engineering/prompting-claude-fable-5)

### 推奨1: 目的・読み手・成果物を書く
「何をしてほしいか」だけでなく「何のために使うか」まで伝えると出力の方向性が安定する。

### 推奨2: 出力形式を最初に指定する
指示追従が強くなり、短い指示で制御可能。

### 推奨3: 実行範囲を明確にする
「調査だけ」か「修正まで」かを明示。依頼されていないアクション（過剰リファクタ等）を防ぐ。

### Claude 5ファミリーの使い分け（公式モデル選択ガイド準拠）

| モデル | いつ使う |
|--------|----------|
| Sonnet 5 | 日常のデフォルト（全タスクの70-80%） |
| Opus 4.8 | 複雑なagentic coding・enterprise・大規模refactor |
| **Fable 5** | **最も難しく高価値な長期タスク・最終synthesis・敵対的検証** |
| Haiku 4.5 | 大量処理・分類・抽出・要約・サブエージェントfan-out |

---

## [★H2-8] やりがちなアンチパターン 7選

### 1. 簡単なタスクにFable 5を使う
:::message alert
2倍の価格に見合わない。簡単な一問一答では能力を過小評価も過大評価もする。日常タスクはSonnet 5。
:::

### 2. effortを常にmaxにする
高effortでは必要以上のリファクタ・抽象化をしがち。コスト爆発。日常codingは`high`（デフォルト）、難問のみ`xhigh/max`。

### 3. fallbackを設計しない
`stop_reason: "refusal"`をエラー扱いして止まる。refusalは**正常系**としてレスポンス分岐で処理すること。

### 4. ZDR（ゼロデータ保持）前提案件に組み込む
Fable 5は**30日データ保持が必須**でZDR非対応。契約・顧客説明と照合不可なら別モデル。

### 5. 「思考過程を見せて」系プロンプト
拒否カテゴリをトリガーする。生の思考は返らない仕様なので、要約ベースで運用する。

### 6. トークン単価だけで比較
「1リクエスト」ではなく**「1ジョブ完了までの総コスト」**で比較。Fable 5は少ターンで終わる場合がかえって安いこともある。

### 7. サブスク前提で本番設計
無償期間は2度延長され7/20（日本時間）までだが、これは翌週プラン更新でFable 5が標準になることを意味しない。本番はAPI課金（usage credits）前提で設計。

---

## コスト判断の最適値

| 条件 | 推奨 | 理由 |
|------|------|------|
| 日常codingのeffort | `high`（デフォルト） | 公式推奨・コスト性能バランス |
| 難問・agenticのeffort | `xhigh`〜`max` | 深い推論が必要な領域 |
| fallback想定率 | 5%未満 | 公式値。95%超セッションはFable 5直接動作 |
| Fable 5を使うタスク | 最難・最高価値のみ | Opus 4.8の2倍の価格 |
| 日常タスク | Sonnet 5 | コスト性能バランス最良 |

※Opus 4.7+・Fable 5・Sonnet 5は**新トークナイザで同テキストで約30%トークン増**。コスト試算に含めること。

---

## 関連ツール比較表

| モデル | コンテキスト | 最大出力 | 価格(入/出 per MTok) | 位置づけ |
|--------|-------------|----------|----------------------|----------|
| **Fable 5** | 1M | 128k | $10 / $50 | 最高性能（一般提供） |
| Opus 4.8 | 1M | 128k | $5 / $25 | 複雑agentic・enterprise・fast mode対応 |
| Sonnet 5 | 1M | 128k | $3 / $15（8/31まで$2/$10） | 日常デフォルト |
| Haiku 4.5 | 200k | 64k | $1 / $5 | 高速・大量・安価 |
| Mythos 5 | 1M | 128k | $10 / $50 | Glasswing限定・セーフガードなし |

> Opus 4.1は2026年8月5日退役予定。Opus 4.8へ移行。

---

## 実践チェックリスト

### 導入時
- [ ] Claude Code v2.1.170+に更新したか
- [ ] 30日データ保持が契約・顧客説明と整合するか（ZDR案件でないか）
- [ ] `stop_reason: "refusal"`を正常系として処理する実装にしたか
- [ ] fallback方式（サーバー/クライアント/手動）を決めたか

### 日常運用時
- [ ] 日常タスクはSonnet 5・Fable 5は最難タスク限定にしているか
- [ ] effortをタスク難度に応じて切り替えているか
- [ ] コストを1ジョブ単位で見ているか
- [ ] 新トークナイザの約+30%を試算に含めたか

### トラブル時
- [ ] refusalが返ったとき別モデルへフォールバックするか
- [ ] Bedrock/Vertex/Foundry間でfallback挙動の差を把握したか
- [ ] 7/20の無償期間終了後もusage credits移行を見越しAPI課金前提にしたか

---

## まとめ

- **要点1**: 「Fable」はAIモデル（Fable 5）とXboxゲーム（数字なし「Fable」）の2つ。本記事はAIモデルの方
- **要点2**: Fable 5 = Mythos 5（Glasswing限定）の一般安全版。同基盤・同価格、セーフガードの有無のみ違う
- **要点3**: Opus 4.8の2倍の価格だが、最難・高価値タスク（アーキ判断・敵対的検証・長期agent）でのみ使うべき
- **要点4**: 適応型思考は常時ON・effortで深さ制御。「思考過程を見せて」は拒否トリガー
- **要点5**: fallback設計が前提。refusalはHTTP 200の正常系、30日データ保持必須・ZDR非対応

「Fableってゲーム？」から「Fable 5をどのタスクに使うか」まで、一記事で整理できた。**高い判断力が必要な場面にだけFable 5を差す** – それが、2倍の価格に見合う唯一の使い方だ。

---

## 参考リンク

- [Claude Fable 5とClaude Mythos 5のご紹介（公式）](https://platform.claude.com/docs/ja/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5)
- [Claude Fable 5 のプロンプティング（公式）](https://platform.claude.com/docs/ja/build-with-claude/prompt-engineering/prompting-claude-fable-5)
- [モデルの概要 / 選択（公式）](https://platform.claude.com/docs/ja/about-claude/models/overview)
- [拒否とフォールバック（公式）](https://platform.claude.com/docs/ja/build-with-claude/refusals-and-fallback)
- [Fable（Xboxゲーム公式）](https://www.fablethegame.com/en-US)
- [AnthropicがClaude Fable 5の無償提供を再延長（itmedia）](https://www.itmedia.co.jp/news/articles/2607/13/news081.html)
---
title: "Jevが人を二分する理由を整理する — 型保証と判断の正しさは別物"
emoji: "🎯"
type: "tech"
topics: ["AI", "LLM", "Agent"]
published: true
---

## この記事で分かること

「Jev、すごくない？」と興奮してリンクを貼る人と、「……何がすごいの？」と首をかしげる人がいる。この記事で分かるのは、**その反応の分かれ目が何か**と、**Jevが本当に保証しているのは「型」だけで「判断の正しさ」ではない**ことの2つ。

Jevの独自性は「文章を生成しない」ことにある。判定だけを高速・低コストで返す新しいタイプのモデルで、公開されている検証では **精度はfrontier LLMの一段下**。それでも価値があるのは、**「分類はJev、生成はClaude」と住み分ける設計**に使うとき。

:::message
対象読者: LLMアプリケーションを自分で作る人。プロンプトでJSONを吐かせてパース地獄を経験したことがある人のほうが、この記事の価値は高い。
:::

---

## Jevで反応が二分する理由 — 分かれ目は「プログラム経験」である

はてなブックマークで154users（2026-09-17現在）、開発者向けコミュニティでは「これだよこれ！」と興奮する投稿が出る一方、日常でAIをチャットとして使っている人には「で、これ何に使うの？」と映る。[The Decoder](https://the-decoder.com/former-openai-researcher-builds-an-ai-model-that-judges-options-instead-of-writing-text/) などの報道も、両方の受け取り方のどちらかに振れている。

この二分は偶然ではなく、**プログラミング経験の有無**にほぼ対応している。

| 立場 | Jevへの反応 | 背景にある思考 |
|------|------------|--------------|
| プログラマー | 興奮する | 「AIの出力を **0か1か・どれか1つ** に決めてほしい」場面に日々直面している。Jevはその領域を正面から狙った初めてのモデル |
| 非プログラマー | ぴんと来ない | AI＝チャットで文章を返すもの、という像しかない。文章を返さないモデルの価値がそもそも想像できない |

プログラマーは関数の戻り値に**型**を要求する。`{"sentiment": "positive"}` が返ってくるはずが、たまに `"Positive"` や `positive。` が返ってきてパースが壊れる地獄を全員経験している。Jevは **戻り値の形を数学的に保証する**提案だから「領域が違う」と認識して興奮する。

> 📌 本記事の主軸はここ。仕様解説（日本語で多数公開済み）ではなく、「**なぜ型しか保証できないのか**」「**保証しない側の表**」「**公開検証の方法論批判**」に絞る。

---

## なぜ「判断だけを返す」モデルにしたのか — 文字列生成の放棄という設計判断

Jevを作ったTypeSafeの創業者Diogo Almeida（元OpenAI、ChatGPT研究に従事）は、設計思想を次のように言う。

> AI needs an interface software could depend on（ソフトウェアが依存できるインターフェイスをAIに）
>
> — [Introducing System One Models and Jev（TypeSafe公式ブログ）](https://typesafe.ai/blog/introducing-system-one-models-and-jev)

「**software could depend on**」の部分こそ本質で、ソフトウェアがAIに依存できるためには戻り値が不確定では困る。だからJevは文字列生成を放棄した。

| 設計トピック | 中身 | 意味 |
|------------|------|------|
| **出力プリミティブ** | `Choice`（最大255択）/ `Score` / `Noul`（yes/no） | 戻り値が最初から決まった「型」。文字列の余地がない |
| **並列サンプラ** | 全出力を単一クエリで生成 | トークンを逐次生成しない。レイテンシ70〜500msの源泉 |
| **訓練手法RLCD** | Reinforcement Learning for Calibrated Decisions | RLHF/RLVRではなく「較正された決定」を学習対象にする |

### RLCDが学習するのは「判断」であって「文章」ではない

従来モデルの学習対象は「トークンの系列」（文章）だが、RLCDは**申告された確率が実際の的中率と一致するよう較正**することに最適化される。ここに「**なぜ『それしか』保証できないのか**」の答えがある。Jevが保証するのは **出力の形** であり、**出力の正しさではない**。較正の主張（0.8の確信度なら80%当たる）は、2026-09-17時点で**ベンダー主張のまま**。アーキテクチャ論文も標準ベンチも未公開。

> 🔬 筆者確認（2026-09-17）: 公式ブログには「Our number is not empirical. Schema matching is guaranteed.」と明記されている。型エラー0%は**経験的計測ではなく数学的保証**だと、ベンダー自身が言っている。

---

## Jevが返すもの — 3つの出力プリミティブをSDKソースで読む

APIは2026-09-17時点でwaitlist制のため、本記事では**実行せず** SDK（v0.6.0, 2026-09-15公開）のソース読解で確認する。

- 型定義: `typesafe_sdk/_core/question_types.py`
- `Noul`: yes/no判定（criteriaでyes/no各状態の説明文を付与可能）
- `Choice`: ラベル→説明の `Mapping`。判定させたい選択肢を列挙する
- `Score`: 0始まりの順序付き説明リスト（ルーブリック）

```python
from typesafe_sdk import Choice, TypeSafeClient

with TypeSafeClient() as client:
    answer = client.jev.ask({
        "sentiment": Choice(
            instructions="次のカスタマー対応のトーンを判定してください",
            criteria={
                "positive": "好意的・感謝",
                "neutral": "事務的",
                "negative": "不満・クレーム",
            },
        ),
    })
    print(answer.answers["sentiment"].probabilities)
    # => {"positive": 0.87, "neutral": 0.10, "negative": 0.03}
```

応答型もソースで確認した（`_core/response_types.py`）:

- `NoulAnswer`: yes確率（0〜1）
- `ChoiceAnswer`: ラベル → 確率の辞書
- `ScoreAnswer`: 整数キー → 確率の辞書

この設計が「型保証」の実体。**選択肢は自分で列挙する**ので、モデルが定義外の文字列を返す余地が構造的にない。

---

## 検証するときの落とし穴 — 67.8% の分母は「平均」である

Jevに関する数字で最初に見るべきは、自社dashboardの比較結果。

> **Jev 67.8% 対 最良比較モデル74.1%**（711ケース・2026-09-17確認）

つまり**精度では負けている**。これは「Jevは精度より速度とコストを取ったモデル」という位置づけを補強する。ただし、この数字の読み方にはもっと深い落とし穴がある。

**正解ラベルの定義が、競合モデル2つ（GPT-6 AstraとClaude Fable 5.1）の出力の平均**だからだ。つまり「正解」が人間の合議でも実測のラベルでもなく、**比較したい相手の平均**になっている。これではJevが「正解」に近いかどうかの厳密な検証にはならない。

> ⚠️ 「Jevは67.8%（の精度）」と報じる日本語記事は複数あるが、**「その67.8%の分母は何か」を指摘した日本語記事は2026-09-17時点で見つからなかった**。本記事はそこを疑う立場を取る。

ベンダー自身も評価バイアスを認めている。LLM側の数値はOpenRouter由来で「almost certainly is bias（ほぼ確実にバイアスがある）」、ワークフローevalは「自社のモデル能力チームが作ったので一部バイアスの可能性がある」と。さらに価格の持続性についても：

> We can't prove it isn't subsidized（補助金を受けていないことは証明できない）
>
> — [TypeSafe公式ブログ](https://typesafe.ai/blog/introducing-system-one-models-and-jev)

---

## 唯一の第三者検証 — Everyの2つのテストが示したこと

「第三者検証ゼロ」という指摘は間違い。**Every（米メディア）が独立テストを公開済み**。ただし結果は両刃だ。

### テスト1: 777判定 / 0.7秒 / 約0.25セント（Mike Taylor）

Everyのevals責任者Mike Taylorが、自身の記事27本＋AIっぽい文章10本（計37文書）に同じ21質問を並列実行。**37文書 × 21問 = 777判定を0.7秒未満**、費用は約0.25セント。11実験トータルで1,709判定を**1セント未満**。

> "I'd want a more thorough accuracy check before putting it into production"
>
> — [Mini-Vibe Check（Every / Mike Taylor）](https://every.to/also-true-for-humans/mini-vibe-check-typesafe-s-jev-judged-everything-i-ve-written-in-0-7-seconds)

### テスト2: 欠陥検出6/7対7/7（Dan Shipper）

Every CEO Dan Shipperが、12文書（6正常/6欠陥）でJevとClaude Fable 5.1を比較。**Jevは欠陥6/7を検出（Fableは7/7）**。速度は約25倍（0.35秒 対8.83秒）、コストは約580倍安かった。

> Jevが見落とした1件は「一呼吸の推論」を要するもの。これはJevが**設計上持たない**能力（遅い・深い・逐次の推論）。速さと正しさのトレードオフが、設計思想そのものに出ている。

**Everyの結論**: 「より速く、より安く、わずかに精度が落ちる —— 当たり前のエンジニアリングトレードオフであり、新しいカテゴリーではない」と報道は評した。

---

## 保証していること・保証していないこと（一覧）

| 項目 | 状態 | 根拠 |
|------|------|------|
| 出力の型（戻り値の形状） | ✅ **数学的に保証** | "Schema matching is guaranteed." |
| 定義外の文字列が返らない | ✅ 構造的に不可能 | 全出力を単一クエリで生成・出力空間が事前列挙 |
| 判断の正しさ（正解率） | ❌ 未達（67.8% vs 74.1%） | 自社dashboard |
| 較正（確信度=的中率） | ❌ 未検証 | ベンダー主張のまま・論文なし |
| コンテキスト長 | ⚠️ 約3.2万トークンに制限 | 公式 |
| 画像・音声入力 / 日本語 | ⚠️ 未対応・公式で言及なし | 公式 |
| 価格の持続性 | ⚠️ 未証明（"can't prove it isn't subsidized"） | 公式 |

---

## 設計者がJevに何をさせたいか — 公式スキルのREADMEを読む

TypeSafe公式のスキル集 [`typesafe-ai/skills`](https://github.com/typesafe-ai/skills)（53★・MIT）を見ると、**設計者が想定する使い方**が見えてくる。

> Use TypeSafe to route incoming support tickets by department, with human review for uncertain decisions.
>
> — [typesafe-ai/skills README](https://github.com/typesafe-ai/skills)

この一文に設計思想が入っている。**判定が型付き**で、**不確実な判定は人間へ**（低確信度はhuman review）。

「自信のない判定を人間に回す」というルーティング設計こそ、確信度（probability）を返すJevの正しい使い方だ。このパターンは、当Vault（Obsidianベースの個人知識管理）で運用している `.claude/skills/` の構成と直接比較できる。

---

## 使いどころ — 「分類はJev、生成はClaude」の住み分け

Jevを「LLMの代わり」として使うと精度で負ける。**判定を担う部品として横に置く**のが正しい使い方。

| 用途 | 向き | 根拠 |
|------|------|------|
| センチメント/カテゴリ分類 | 🎯 Jev | 型保証・超低コスト・低レイテンシ |
| コンテンツの不適切判定 | 🎯 Jev + 人間レビュー | low confidenceを人に回せる |
| ルーティング（部署・優先度） | 🎯 Jev | 公式スキルの想定例そのもの |
| 自由形式の文章生成 | ❌ Jev | 生成しない設計 |
| 深い推論・複数ステップの判断 | ⚠️ Jevでは不足 | 欠陥検出6/7の事例が示す限界 |

### コスト試算（月10万件のセンチメント判定）

入力 $0.042/MTok・**出力無料**なので、費用はほぼ入力トークン量で決まる。1件あたり入力500トークンで月10万件を処理する想定:

```text
10万件 × 500トークン = 5000万トークン = 50 MTok
50 MTok × $0.042/MTok = $2.10 /月
```

月 **$2.10（約300円）** で10万件の判定ができる。この桁のコスト差が「AIをソフトウェアに組み込む」判断を変える。※2026年9月時点の価格。出力無料・超低価格の持続性はベンダー自身が未証明と留保している。

---

## まとめ

- **反応の二分は知能差ではなく接触モデル差**: 戻り値の型を要求したことのある人と、チャットしか知らない人で、同じモデルが別物に見える
- **保証は「型」だけ**: 戻り値の形状は数学的に保証されるが、判断の正しさには及ばない（67.8% vs 74.1%）
- **67.8% の分母は競合2モデルの平均**: 「数字を疑う」のが正しい読み方。日本語でこの指摘は空白
- **第三者検証は存在する**: Everyの777判定0.7秒は本物だが、精度はJev 6/7対Fable 7/7
- **正しい使い方は「横に置く」**: 分類・判定・ルーティングをJev、生成と深い推論を従来LLMに。月10万件で約$2

Jevは「幻覚ゼロの安いLLM」ではなく、**「確信度つきの型付き判定部品」**。その位置づけで見れば、興奮も困惑も、どちらも正しい。

---

## 参考リンク

- [Introducing System One Models and Jev（TypeSafe公式）](https://typesafe.ai/blog/introducing-system-one-models-and-jev)
- [Mini-Vibe Check（Every / Mike Taylor）](https://every.to/also-true-for-humans/mini-vibe-check-typesafe-s-jev-judged-everything-i-ve-written-in-0-7-seconds)
- [typesafe-ai/skills（GitHub）](https://github.com/typesafe-ai/skills)
- [typesafe-sdk（PyPI v0.6.0）](https://pypi.org/project/typesafe-sdk/)
- [The Decoder: Former OpenAI researcher builds an AI model that judges options](https://the-decoder.com/former-openai-researcher-builds-an-ai-model-that-judges-options-instead-of-writing-text/)
- [agenticな報道の一例（AIフレンズ）](https://aifriends.jp/typesafe-ai-jev-system-one-model/)

---



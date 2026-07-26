---
title: "【2026年最新】Claude Opus 5 完全ガイド — 「Fable 5の下位版？」の誤解からthinking破壊的変更まで"
emoji: "🧠"
type: "tech"
topics: ["Anthropic", "ClaudeCode", "LLM", "AI", "生成AI"]
published: true
---

## この記事で分かること

2026年7月24日にリリースされた **Claude Opus 5**。価格は Opus 4.8 と同じ $5/$25 のまま、Fable 5 の半額で「フロンティア級」を名乗っています。

ここで多くの人が2回つまずきます。1つ目は **「Opus 5 と Fable 5、結局どっちが上なの？」**。数字が同じ「5」で、片方が半額。序列が読めません。2つ目は **「価格据え置きなら model ID を差し替えるだけでは？」**。実際には 400 エラーになる破壊的変更が 2 つ入っており、さらに「プロンプトを足す」のではなく **「これまで書いていた指示を消す」** 必要があります。

本記事は、この2つの混乱を最短で整理し、移行時に踏みやすい地雷とその回避策までを一気通貫でまとめます。

:::message
**対象読者**: Claude API / Claude Code を業務で使い、Opus 4.8 以前から移行するエンジニア
:::

※本記事の情報は **2026年7月26日時点**（Opus 5 リリース2日後）のものです。ベータヘッダ名やベータ機能の仕様は変わりうるため、公式ドキュメントで最新を確認してください。

---

## [★] 「Opus 5 は Fable 5 の下位版」という誤解 — 3系統を整理する

最初に潰すべき誤解はこれです。

> **「5」は世代であって序列ではない。Opus / Fable / Mythos は並列に走る3本のラインです。**

Fable 5 が $10/$50、Opus 5 が $5/$25 なので「Opus 5 = Fable 5 の廉価版」と読みたくなりますが、実際にはベンチマーク上 **Opus 5 が Fable 5 を上回る領域のほうが多い**。安いほうが上、という直感に反する状態になっています。

### 3モデルの棲み分け

| 項目 | Claude Opus 5 | Claude Fable 5 | Claude Mythos 5 |
|------|---------------|----------------|-----------------|
| モデルID | `claude-opus-5` | `claude-fable-5` | `claude-mythos-5` |
| 価格（in/out per MTok） | **$5 / $25** | $10 / $50 | $10 / $50 |
| 入手性 | 全ユーザー | 全ユーザー | Glasswing パートナー限定 ※ |
| コンテキスト | 1M（既定=最大） | 1M | 1M |
| 最大出力 | 128K | 128K | 128K |
| thinking | 既定ON・`high`以下でのみ無効化可 | 常時ON（無効化は400） | Fable 5 と同じ |
| 位置づけ | 複雑なエージェンティックコーディング / 企業業務 | 最も高性能な一般提供モデル | Fable 5 と同能力の限定提供 |

※ Mythos 5 は現在 Glasswing パートナー（サイバー系セーフガード解除）限定ですが、Anthropic は**近く一部の生物学研究者にも展開予定**（生物・化学系セーフガード解除）と発表しています。より広い trusted access プログラムが用意されるまでの暫定措置という位置づけです。

### では、どう使い分けるのか

Anthropic 公式は Opus 5 を「Fable 5 のフロンティア知能に半額で肉薄する」と表現しています。Anthropic のローンチ比較表を突き合わせた第三者集計では、両モデルの数値が揃っている9項目のうち **Opus 5 が5勝、Fable 5 が3勝、1項目が実質同点**でした。

| ベンチマーク | Opus 5 | Fable 5 |
|---|---|---|
| Frontier-Bench | **43.3%** | 33.7% |
| BrowseComp | **90.8%** | 87.4% |
| OSWorld 2.0 | **70.6%** | 66.1% |
| AutomationBench | **26.0%** | 17.4% |
| GDPval-AA v2（Elo） | **1,861** | 1,747 |
| DeepSWE v1.1 | 68.8% | **69.7%** |
| Legal Agent Benchmark | 11.7% | **13.3%** |
| FrontierCode Main | 53.4% | 53.5%（実質同点） |

※数値は Anthropic の2026年6〜7月ローンチ比較表に基づく[第三者集計](https://llm-stats.com/blog/research/claude-opus-5-vs-claude-fable-5)であり、独立した再現テストではありません。

別ソースの [BenchLM.ai リーダーボード](https://benchlm.ai/benchmarks/swePro)（2026-07-25時点）では **SWE-bench Pro が Opus 5 = 79.2% / Fable 5 = 80.0%** で、首位は Mythos 5 の 80.3%。ソフトウェアエンジニアリングの最難関帯だけは Fable / Mythos が僅差で先行しています。

判断軸はシンプルです。

| 状況 | 選ぶモデル | 理由 |
|------|-----------|------|
| 日常のコーディング・エージェント運用 | **Opus 5** | 多くのベンチで同等以上、価格は半分 |
| 一晩回す長時間自律エージェント / 最難関のソフトウェアタスク | **Fable 5** | この領域だけは依然 Fable 5 が優位 |
| 攻撃的セキュリティ / 先端生物研究 | Mythos 5（要 Glasswing） | Opus 5 は公式に「Mythos 5 の後塵を拝する」と明記 |
| コスト最優先・軽いタスク | Sonnet 5 / Haiku 4.5 | Opus 系を使う必然性がない |

:::message alert
**セーフガードの挙動差にも注意。** Opus 5 はサイバーセキュリティ領域の分類器が **Fable 5 比で約85%少ない頻度**でしか介入しないとされています。逆に言えば Fable 5 は誤検知で止まりやすい。セキュリティ系の正当な業務で Fable 5 が拒否を返していたなら、Opus 5 で改善する可能性があります。
:::

---

## 前提：Opus 4.8 から何が変わったのか

価格が据え置きなので「無風のアップデート」に見えますが、変更点は API レベルまで及びます。まず全体像を押さえます。

### 変更点マップ

| 分類 | 内容 | 影響 |
|------|------|------|
| 🔴 破壊的 | thinking がデフォルトON になった | `max_tokens` を食い潰し、応答が途中で切れうる |
| 🔴 破壊的 | `thinking: disabled` は effort `high` 以下でのみ許可 | `xhigh`/`max` との併用で **400** |
| 🟡 挙動 | ユーザー向け応答・生成ドキュメントが長くなった | 冗長化。プロンプトで明示的に抑制が必要 |
| 🟡 挙動 | 指示しなくても自己検証する | 従来の「検証せよ」指示が**過剰検証**を招く |
| 🟡 挙動 | サブエージェントに積極的に委譲する | 4.8 とは**真逆**。コスト増 |
| 🟢 新機能 | 会話途中のツール変更（beta） | プロンプトキャッシュを壊さずツール追加/削除 |
| 🟢 新機能 | `fallbacks: "default"`（beta） | 拒否カテゴリ別に推奨フォールバック先を自動選択 |
| 🟢 改善 | プロンプトキャッシュ最小長 1,024 → **512 トークン** | 短いプロンプトもキャッシュ対象に |
| 🟢 改善 | effort が `low`〜`max` の5段階フル対応 | `low`/`medium` が実用水準に |
| ⚠️ 運用 | レートリミットが Opus 4.x とは**別バケット** | 移行しても旧枠は空かない／継承もされない |
| ⚠️ 運用 | Fast mode は **Claude API のみ**（$10/$50） | Bedrock / Google Cloud / Foundry では不可 |

### 提供プラットフォーム

```text
Claude API        : claude-opus-5
Amazon Bedrock    : anthropic.claude-opus-5
Google Cloud      : claude-opus-5
Microsoft Foundry : 提供あり
```

Opus 4.8 はいずれのプラットフォームでも引き続き利用できます。

なお Claude Code では `opus` エイリアスの解決先が Opus 5 に切り替わります。ただし条件があります。

- **Claude Code v2.1.219 以降**が必要。それ未満では `opus` は Opus 4.8 を返し続け、ピッカーに Opus 5 が現れません
- 解決先はプランに依存します（Max / Team Premium / Enterprise 従量課金 / API では Opus 5。Pro・Team Standard の既定は Sonnet 5 のまま）
- エイリアスの解決先は**プロバイダによっても異なります**。Bedrock / Google Cloud 経由では別バージョンに解決されることがあります

4.8 に固定したい場合は、フルのモデル名 `claude-opus-4-8` を明示するか、`ANTHROPIC_DEFAULT_OPUS_MODEL` を設定してください。

:::message
プラン別・プロバイダ別のエイリアス解決先は二次情報を含みます。実際の解決先は `/model` または `claude --model` の表示で確認してください（※2026年7月時点）。
:::

---

## 破壊的変更①：thinking がデフォルトONになった

**Opus 4.8 では、`thinking` を省略したリクエストは「思考なし」で走っていました。Opus 5 では同じリクエストが「思考あり」で走ります。**

ワイヤ上の値は変わっていません。`thinking: {"type": "adaptive"}` は引き続き有効で、デフォルト挙動と等価です。変わったのは**デフォルト**だけ。

### なぜこれが静かな事故になるのか

`max_tokens` は **思考トークンと応答テキストの合計**に対するハード上限です。

```python
# Opus 4.8 では thinking なしで走っていたコード
response = client.messages.create(
    model="claude-opus-5",   # ← ID を差し替えただけ
    max_tokens=1024,         # 応答の長さに合わせてカツカツに設定していた
    messages=[...],
)
# Opus 5 では thinking が max_tokens を消費 → 応答が途中で切れる
```

エラーにはなりません。`stop_reason: "max_tokens"` で、それらしい途中の文章が返ってきます。**バッチ処理や非対話パイプラインでは気づきにくい**のが厄介なところです。

### 対処

`thinking` を一度も設定していなかった全経路について、次のどちらかを選びます。

```python
# 案A（推奨）: thinking を活かし、max_tokens に余裕を持たせる
client.messages.create(
    model="claude-opus-5",
    max_tokens=16000,
    output_config={"effort": "low"},   # コストは effort で絞る
    messages=[...],
)

# 案B: 明示的に無効化して旧挙動を保つ（effort は high 以下に限る）
client.messages.create(
    model="claude-opus-5",
    max_tokens=1024,
    thinking={"type": "disabled"},
    output_config={"effort": "high"},
    messages=[...],
)
```

公式は案Aを推しています。理由は次節。

---

## 破壊的変更②：thinking の無効化は effort `high` 以下に限られる

`thinking: {"type": "disabled"}` は **effort が `high` 以下のときのみ**受け付けられます。`xhigh` または `max` と併用すると **400 エラー**です。

```python
# ❌ Opus 5 では 400。Opus 4.8 では通っていた組み合わせ
client.messages.create(
    model="claude-opus-5",
    max_tokens=4096,
    thinking={"type": "disabled"},
    output_config={"effort": "xhigh"},
    messages=[...],
)
```

:::message alert
**検証はリクエスト単位で走ります。** 同じ会話の前半が `high` で通っていても、後から `xhigh` に上げた1回だけが弾かれます。「最初は動いていたのに途中で落ちる」タイプの障害になるので、**全コールサイトを監査**してください。
:::

### thinking を切ったときに起きる2つの故障モード

ここが本記事で最も見落とされやすいポイントです。thinking を無効化すると、Opus 5 は稀に次の2つを起こします。

#### 1. ツール呼び出しが「ただのテキスト」として出力される

構造化された `tool_use` ブロックを出さず、ツール呼び出しを**ユーザー向けテキストに書いてしまう**ことがあります。

- ターンは正常終了する（`stop_reason` は `end_turn`）
- **ツールは実行されない**
- エラーも警告も出ない
- エージェンティックループでは、その偽テキストが会話履歴に残り**後続ターンまで汚染する**

検索など、ツール多用のワークロードで起きやすいとされています。ハーネス側から見ると「成功したのに何もしていないターン」になるため、監視で捕まえにくい類のバグです。

#### 2. `<thinking>` タグが可視レスポンスに漏れる

内部 XML タグが表に出てきます。ここで**直感に反する対処法**が2つあります。

- **「思考するな」「推論するな」系の指示があるなら削除する。** その種のルールはタグ漏れを**増やします**。
- **タグ名を名指ししない。** 「`<thinking>` を出すな」より、一般形のほうが効きます。

公式が示す、両方を同時に緩和する統合指示がこちらです。

```text
When you use a tool, you may say a brief sentence first. If no tool can express
what the user asked for, say so instead of guessing. Do not include internal or
system XML tags in your response.
```

> 主要な緩和策は、両方とも「thinking を有効のままにして、コストは低い effort で制御すること」です。ほとんどのタスクで、**thinking 有効 + `low` effort のほうが、同程度のコストで thinking 無効より良い結果**になります。
>
> — [Prompting Claude Opus 5 / Running with thinking disabled](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)

---

## [★] Opus 5 で「消すべき」プロンプト5選

Opus 5 移行の本質は、**プロンプトを足すことではなく削ることにあります**。4.8 以前で有効だったテクニックの一部が、Opus 5 では逆効果に転じます。

### 1. 「最後に検証ステップを入れよ」

Opus 5 は**言われなくても自己検証します**。この指示が残っていると過剰検証を起こし、トークンを浪費します。削除しても品質は落ちません。

```diff
- 非自明なタスクでは必ず最終検証ステップを含めること。
```

### 2. 「サブエージェントで検証させよ」

同上。しかも Opus 5 はサブエージェント委譲に積極的なので、二重に効いてコストが跳ねます。

### 3. 「ダブルチェックしてから答えよ」「再確認せよ」

プロンプト単位の再チェック指示も同じ罠です。**「AI には自己検証させろ」という一般的なベストプラクティスが、このモデルでは反転している**点に注意してください。プロンプトライブラリを横断適用している場合は、Opus 5 だけ例外扱いが必要です。

### 4. 「もっと積極的に委譲せよ」（Opus 4.8 向けに書いた指示）

Opus 4.8 はサブエージェントへの委譲に**消極的**だったため、多くの人が「委譲しろ」と書き足しました。Opus 5 は逆に**積極的すぎる**ので、この指示は削除した上で上限を設けます。

```text
Delegate to a subagent only for large tasks that are genuinely independent and
parallelizable, such as a wide multi-file investigation. Do not delegate work you
can finish yourself in a handful of tool calls, and do not use subagents to verify
or double-check your own work. If one subagent can complete the task, use one
rather than several, and keep spawn counts low.
```

### 5. 「思考するな」「推論を出力するな」

前述のとおり、thinking 無効時のタグ漏れを**悪化させます**。削除してください。

---

## [★] 公式ドキュメントが示すベストプラクティス

### 推奨1: 冗長さは effort ではなくプロンプトで制御する

> effort パラメータは、モデルが**どれだけ言うか**ではなく**どれだけ考えるか**を制御します。effort を下げても思考量が減るだけで、可視レスポンスが確実に短くなるわけではありません。応答長を制御したいなら、明示的にプロンプトで指示してください。
>
> — [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)

```text
Keep responses focused, brief, and concise. Keep disclaimers and caveats short,
and spend most of the response on the main answer. When asked to explain something,
give a high-level summary unless an in-depth explanation is specifically requested.
```

長いシステムプロンプトでは、末尾にリマインダを添えると効きます。

```text
<tone_preference>
Keep outputs reasonably concise.
</tone_preference>
```

### 推奨2: effort は前モデルの設定を引き継がず、必ず振り直す

> デフォルト（`high`）から始めて、自前の eval に基づいて上下に調整してください。品質が保てるところでは `low` と `medium` を**惜しみなく**使い、トークンコストと応答時間の主要な制御手段としてください。前モデルから effort のデフォルトを引き継いでいるなら、自分の eval で effort スイープをやり直してください。

Opus 5 は `low`/`medium` が実用水準に達したのが大きな変化です。「とりあえず `xhigh`」は Opus 5 では最適解ではありません。

### 推奨3: コードレビューでは「絞れ」と言わない

> レビュープロンプトに「重大な問題だけ報告せよ」「保守的に」と書いてあると、モデルはそれを**文字通りに**守って報告を減らします。すべて報告させ、フィルタは別パスで行ってください。

Opus 5 はバグ検出の精度・再現率がともに高いのに、絞り込み指示のせいで**実測 recall が下がって見える**という現象が起きます。これはモデルの退行ではなくハーネスの問題です。

### 推奨4: スコープを明示的に縛る

Opus 5 は頼まれていない手順を足したり、タスクの定義そのものを自己判断で広げることがあります。

```text
Deliver what was asked, at the scope intended. Make routine judgment calls yourself,
and check in only when different readings of the request would lead to materially
different work. If the request seems mistaken or a better approach exists, say so in
a sentence and continue with the task as asked rather than quietly narrowing, widening,
or transforming it. Finish the whole task, and stop short of actions that are clearly
beyond what was asked.
```

---

## [★] やりがちなアンチパターン 7選

### 1. モデルIDだけ差し替えて `max_tokens` を放置

:::message alert
最頻の事故。thinking がデフォルトONになったため、応答が静かに途中で切れます。**`thinking` を一度も設定していなかった全経路**を洗い出してください。
:::

### 2. `thinking: disabled` を `xhigh`/`max` と併用したまま移行

400 エラー。しかもリクエスト単位検証なので、effort を動的に変えるコードでは断続的に落ちます。

### 3. thinking 無効化でコストを削ろうとする

thinking 無効化は**最も高くつくレバー**です。前述の2つの故障モードを誘発します。コスト削減は `effort: low`/`medium` で行ってください。

### 4. Opus 4.8 用の検証指示・委譲指示を残す

過剰検証と過剰委譲でトークンが倍々に増えます。Opus 5 移行は「消す」作業だと理解しないと、コストが下がるどころか上がります。

### 5. レートリミット枠を引き継げると思い込む

Opus 5 は Opus 4.x（4.8/4.7/4.6/4.5）の合算枠とは**別バケット**です。トラフィックを移しても旧枠が空くわけでも、旧枠を引き継げるわけでもありません。**移行前に自分のティアの Opus 5 上限を確認**してください。

### 6. Bedrock / Google Cloud / Foundry で Fast mode を書く

Fast mode（`speed: "fast"`、$10/$50）は **Claude API 限定のリサーチプレビュー**です。サードパーティ経路のコードから `speed` は落としてください。

もう1つ見落としやすい制約として、**Fast mode は Batch API と併用できません**。バッチ処理でコストを半分にしつつ Fast mode で速くする、という組み合わせは成立しないので注意してください。なお Fast mode は標準の Opus 枠とは**別のレートリミット**を持ちます。

### 7. 拒否（refusal）を握り潰す

Opus 5 も安全性分類器がリクエストを断ることがあります。返るのは **HTTP 200 + `stop_reason: "refusal"`** で、例外は飛びません。

```python
response = client.messages.create(model="claude-opus-5", max_tokens=4096, messages=[...])

if response.stop_reason == "refusal":
    handle_refusal(response.stop_details)   # content は空 or 部分出力
else:
    print(response.content[0].text)
```

`response.content[0]` を無条件で読むコードは、拒否時に落ちます。新機能の `fallbacks: "default"`（ベータヘッダ `server-side-fallback-2026-07-01`）を使えば、拒否カテゴリに応じて Anthropic 推奨のフォールバック先へサーバ側で自動的に回してくれます。

---

## effort の最適値 早見表

Opus 5 は「追加の effort を確実に結果の改善に変換する」度合いが歴代 Opus で最も高く、その分 **effort の選択が結果を大きく左右します**。デフォルトは `high`。

| effort | 向く用途 | メモ |
|--------|---------|------|
| `max` | 最難関の推論。コストと待ち時間を問わない場合 | 単純タスクでは考えすぎる傾向。要 eval |
| `xhigh` | 難度の高いコーディング / エージェンティック作業 | `max_tokens` は 64K 以上を推奨 |
| `high` | **既定値。** まずここから始める | 知能とコストのバランス点 |
| `medium` | 定常業務のコスト削減 | Opus 5 では実用水準 |
| `low` | 短くスコープの定まったタスク、レイテンシ重視 | thinking 有効の `low` は thinking 無効より良い場合が多い |

```python
# xhigh / max では max_tokens に十分な余裕を持たせ、ストリーミングする
with client.messages.stream(
    model="claude-opus-5",
    max_tokens=64000,
    output_config={"effort": "max"},
    messages=[{"role": "user", "content": "..."}],
) as stream:
    response = stream.get_final_message()
```

:::message
`max_tokens` が 16,000 を超える非ストリーミングリクエストは、SDK の HTTP タイムアウトに当たることがあります。公式サンプルも 64K の例ではストリーミングを使っています。`xhigh`/`max` を使うなら**ストリーミング前提**で設計してください。
:::

---

## モデル比較表

| | Opus 5 | Opus 4.8 | Fable 5 | Sonnet 5 |
|---|---|---|---|---|
| モデルID | `claude-opus-5` | `claude-opus-4-8` | `claude-fable-5` | `claude-sonnet-5` |
| 価格 in/out | $5 / $25 | $5 / $25 | $10 / $50 | $2 / $10 ※ |
| コンテキスト | 1M | 1M | 1M | 1M |
| thinking 既定 | **ON** | OFF | 常時ON | ON |
| thinking 無効化 | `high`以下のみ | 可 | 不可（400） | 可 |
| effort | low〜max | low〜max | low〜max | low〜max |
| キャッシュ最小 | **512** | 1,024 | 512 | 1,024 |
| Fast mode | ○（API限定） | ○（API限定） | × | × |
| 会話途中のツール変更 | ○（beta） | × | × | × |
| 向いている人 | 日常のエージェント運用全般 | 移行を急がない既存ユーザー | 長時間自律・最難関タスク | コスト重視の高速運用 |

※ Sonnet 5 は **2026年8月31日まで導入価格 $2/$10**。2026年9月1日以降は $3/$15 になります（※2026年7月時点）。

---

## 実践チェックリスト

### 移行前

- [ ] `thinking` を設定していないコールサイトを全部洗い出したか
- [ ] `thinking: disabled` × `effort: xhigh`/`max` の組み合わせがないか grep したか
- [ ] `max_tokens` を応答長ぴったりに設定している箇所がないか
- [ ] 自分のティアの **Opus 5 レートリミット**（Opus 4.x とは別枠）を確認したか
- [ ] Bedrock / Google Cloud / Foundry 経路に `speed: "fast"` が残っていないか

### プロンプト整理（「消す」作業）

- [ ] 「最終検証ステップを入れよ」系の指示を削除したか
- [ ] 「サブエージェントで検証せよ」を削除したか
- [ ] 「ダブルチェックせよ」「再確認せよ」を削除したか
- [ ] Opus 4.8 向けに書いた「もっと委譲せよ」を削除し、上限指示に置き換えたか
- [ ] 「思考するな」系のルールを削除したか
- [ ] 代わりに、簡潔さ指示・スコープ指示を追加したか

### 移行後

- [ ] `effort` スイープを自分の eval で回し直したか（前モデルの設定を引き継がない）
- [ ] `stop_reason == "refusal"` のハンドリングを入れたか
- [ ] キャッシュ最小長 512 化により、新たにキャッシュ対象になるプロンプトがないか見直したか
- [ ] 生成ドキュメントが長くなっていないか（長さ指示の追加を検討）

---

## まとめ

- **「5」は世代であって序列ではない。** Opus / Fable / Mythos は並列の3ライン。Opus 5 は Fable 5 の半額で、多くのベンチで同等以上。Fable 5 が明確に優位なのは長時間自律エージェントと最難関ソフトウェアタスクに絞られる。
- **価格据え置き＝無風、ではない。** thinking のデフォルトON と、`thinking: disabled` × `xhigh`/`max` の 400 という2つの破壊的変更がある。前者は**エラーにならず静かに応答を切る**ので特に危険。
- **thinking 無効化は最も高くつくレバー。** ツール呼び出しがテキスト化して黙って実行されない、内部タグが漏れる、という2つの故障モードを誘発する。コスト削減は `effort: low`/`medium` で行う。
- **移行作業の本質は「消すこと」。** 検証指示・再チェック指示・委譲促進指示は、Opus 5 では逆効果になる。「AI には自己検証させろ」という一般的ベストプラクティスがこのモデルでは反転している。
- **effort は必ず振り直す。** `low`/`medium` が実用水準に達したのが Opus 5 最大の実務的変化。「とりあえず `xhigh`」は最適解ではない。

価格が変わらないアップデートほど、差分の確認が後回しになります。Opus 5 はまさにそのパターンで、**モデルIDを1行変えるだけで済むように見えて、静かに壊れる箇所が2つある**。移行前にチェックリストだけでも通しておくと、後で原因不明の途切れを追う時間を丸ごと節約できます。

---

## 参考リンク

- [Introducing Claude Opus 5 — Anthropic](https://www.anthropic.com/news/claude-opus-5)
- [What's new in Claude Opus 5 — Claude Platform Docs](https://platform.claude.com/docs/en/about-claude/models/whats-new-opus-5)
- [Prompting Claude Opus 5 — Claude Platform Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
- [Migration guide — Claude Platform Docs](https://platform.claude.com/docs/en/about-claude/models/migration-guide)
- [Effort — Claude Platform Docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- [Pricing — Claude Platform Docs](https://platform.claude.com/docs/en/about-claude/pricing)
- [Rate limits — Claude Platform Docs](https://platform.claude.com/docs/en/api/rate-limits)（Opus 5 が Opus 4.x 合算バケットに含まれない旨の出典）
- [Refusals and fallback — Claude Platform Docs](https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback)（`stop_reason: "refusal"` と `fallbacks` の出典）
- [Fast mode — Claude Platform Docs](https://platform.claude.com/docs/en/build-with-claude/fast-mode)
- [Claude Opus 5 vs Claude Fable 5 — llm-stats](https://llm-stats.com/blog/research/claude-opus-5-vs-claude-fable-5)（ベンチマーク比較の第三者集計）

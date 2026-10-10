---
title: "EmbeddingGemma 2と初代の使い分け — 日本語検索はほぼ互角、Ollamaはタグで差が出る"
emoji: "🧭"
type: "tech"
topics: ["Embedding", "RAG", "Ollama", "Gemma", "ローカルLLM"]
published: true
---

## この記事で分かること

「EmbeddingGemma 2 が出たけど、手元の初代から乗り換えるべきか」。10月6日に Google が公開した EmbeddingGemma 2 は、画像・音声・動画も同じ検索空間に入れられる埋め込みモデルです。日本語のノート検索に使っている人なら、まず気になるのはテキストの精度とメモリでしょう。

自分の Obsidian の356ノートで「タイトルから本文を当てる」検索をさせました。主な結果はこれです。

| 動かし方 | モデル（タグ） | 1位正解率 | メモリ |
|---|---|---:|---:|
| Ollama | 初代 `embeddinggemma`（既定・BF16） | **87.1%** | 679 MB |
| Ollama | 2 `embeddinggemma-2`（既定＝740m・4bit） | 83.1% | 1.3 GB |
| Ollama | 2 `embeddinggemma-2:270m-bf16-text` | 85.4% | 542 MB |
| sentence-transformers | 初代（BF16） | **88.5%** | 0.62 GB |
| sentence-transformers | 2（BF16・テキスト専用） | 87.6% | 0.54 GB |

日本語の文章どうしなら、2 は初代と**ほぼ互角で、上回りはしません**（BF16 どうしで0.9〜1.7ポイント差）。そして Ollama では、`ollama pull embeddinggemma-2` で入る既定のタグが「画像・音声込みの740m・4bit」です。これを選ぶと、精度は4ポイント落ち、メモリは倍になります。

この記事では、メモリの数字が媒体ごとにばらばらな理由と、タグ別の実測、乗り換えの判断基準を整理します。

:::message
**対象読者**: 初代 EmbeddingGemma でローカル RAG やノート検索を組んでいて、2 への乗り換えを考えている人
**検証環境**: Apple M5 / 16GB / macOS 26.7.1。Ollama v0.40.2、sentence-transformers 6.1.0（transformers 5.19.0・torch 2.14.1・MPS）。※2026年10月10日時点
:::

---

## 「0.5GB」「191MB」「1.3GB」— メモリの数字を整理する

発表直後、メモリの数字がいくつも出回りました。どれも間違いではなく、条件が違います。

| 数字 | 出どころ | 条件 |
|------|---------|------|
| 約191 MB | [Google 公式ブログ](https://blog.google/innovation-and-ai/technology/developers-tools/embeddinggemma-2) | Pixel 11 Pro・量子化・テキスト専用の重みだけ |
| 約567 MB | 同上 | Pixel 11 Pro・量子化・画像と音声を含む全体 |
| 0.5 GB | Unsloth の告知（X） | GGUF 配布の告知。測定条件の記載なし |
| 378 MB / 574 MB | [Ollama のタグ一覧](https://ollama.com/library/embeddinggemma-2/tags) | テキスト専用 `270m` の4bit / BF16（配布サイズ） |
| 1.3 GB | 同上 | 既定タグ `latest`＝`740m-nvfp4`（全部入り・4bit） |
| 0.54 GB | 本記事の実測 | sentence-transformers・BF16・テキスト専用で読み込み |

ポイントは「**どの部品を、どの量子化で載せるか**」です。2 は部品ごとに分かれていて、Ollama にもテキスト専用（`270m`）、テキスト＋画像（`440m`）、テキスト＋音声（`570m`）、全部入り（`740m`）のタグがあり、それぞれに BF16・mxfp8・nvfp4 の版があります。

:::message alert
`ollama pull embeddinggemma-2` で入るのは `740m-nvfp4`（全部入り・4bit）です。テキストしか使わないなら、タグを指定しないと不要な部品まで載せることになります。
:::

---

## なぜこうなったのか — 2 が「部品式」になった経緯

Google は 2 を Gemma 4 の構造の上に作り直し、テキスト・画像・音声を別々の部品に分けました。

| 論点 | Google の説明 | 出典 |
|------|-------------|------|
| 部品ごとに分ける | テキスト 270M ＋ 画像 170M ＋ 音声 300M。必要な部品だけ読める（テキスト＋画像 440M、テキスト＋音声 570M） | [Hugging Face モデルカード](https://huggingface.co/google/embeddinggemma-2) / [公式ブログ](https://blog.google/innovation-and-ai/technology/developers-tools/embeddinggemma-2) |
| テキスト部を小さく | 初代の 300M から 270M に縮めた | [公式ドキュメント](https://ai.google.dev/gemma/docs/embeddinggemma) |
| 1つの空間にまとめる | テキスト・画像・音声・動画を同じ768次元の空間に置き、種類をまたいで検索できる | 公式ブログ |
| 次元を切れる | Matryoshka 表現学習で 768 → 512 / 256 / 128 次元に切り詰められる（保存容量は最大6分の1） | 公式ドキュメント |

モデルカードの比較では、多言語の検索ベンチマーク（MTEB Multilingual v2）は初代 61.15 に対して 2 が 61.36 で、ほぼ横ばいです。大きく伸びたのはコード検索（NDCG@10 で 68.76 → 78.68）でした。

:::message
この経緯を知っていると、2 の改善点は「**テキストの精度**」ではなく「**種類をまたいだ検索とコード検索**」だと読めます。日本語の文章だけなら、向上は最初から期待しないほうがいい。今回の実測もその通りでした。
:::

---

## 前提：初代との違い

| 項目 | EmbeddingGemma（初代） | EmbeddingGemma 2 |
|------|----------------------|------------------|
| パラメータ | 308M | 744M（テキストだけなら 271M） |
| 入力 | テキスト | テキスト・画像・音声・動画 |
| 文脈長（公式） | 2,048 トークン | 8,192 トークン |
| 出力次元 | 768（Matryoshka 対応） | 768（Matryoshka 対応） |
| 検索用の接頭辞 | `task: search result \| query:` / `title: none \| text:` | **同じ** |
| Ollama の既定タグ | `300m`（BF16・配布622MB） | `740m-nvfp4`（4bit・配布1.3GB・MLX で動く） |

接頭辞は2でも同じです。初代のコードは、モデル名を変えるだけで動きます。

---

## セットアップ（検証済みの手順）

### Ollama で使う

テキストだけなら、タグを指定します。

```bash
ollama pull embeddinggemma-2:270m-bf16-text     # テキスト専用・BF16（574MB）
curl -s localhost:11434/api/embed -d '{
  "model": "embeddinggemma-2:270m-bf16-text",
  "input": ["task: search result | query: 予知保全の始め方"]
}'
```

手元の Ollama 0.35.1 では、pull が次のエラーで止まりました。

```text
Error: pull model manifest: 412: The model you are attempting to pull requires a newer version of Ollama.
```

`ollama show` の表示は「requires 0.36.0」ですが、公開されている版は 0.35.1 の次が 0.40.0 です。2 への対応は [v0.40.0 のリリースノート](https://github.com/ollama/ollama/releases/tag/v0.40.0)に書かれているので、**実質 0.40.0 以上**が必要です。普段使いの Ollama アプリを更新したくなかったので、今回は v0.40.2 を別フォルダに置き、別ポートで起動しました。

```bash
mkdir -p ollama && curl -sL https://github.com/ollama/ollama/releases/download/v0.40.2/ollama-darwin.tgz | tar xz -C ollama
OLLAMA_HOST=127.0.0.1:11500 OLLAMA_MODELS=$PWD/models ./ollama/ollama serve &
OLLAMA_HOST=127.0.0.1:11500 ./ollama/ollama pull embeddinggemma-2:270m-bf16-text
```

### 公式の sentence-transformers で使う（テキスト専用）

```bash
uv add sentence-transformers torch pillow torchvision
```

```python
import torch
from sentence_transformers import SentenceTransformer

model = SentenceTransformer(
    "google/embeddinggemma-2", device="mps",
    model_kwargs={"dtype": torch.bfloat16},                        # float16 は使わない
    config_kwargs={"vision_config": None, "audio_config": None},   # 画像・音声を読まない
)
q = model.encode_query(["予知保全の始め方"])                  # 検索用の接頭辞が自動で付く
d = model.encode_document(["振動センサーの値から異常の兆候をつかむ"])
print(q @ d.T)   # 手元では 0.646
```

`encode_query` / `encode_document` を使うと、公式の接頭辞（`task: search result | query:` / `title: none | text:`）が自動で付きます。

:::message alert
手元の環境では、テキストしか使わない場合でも `pillow` と `torchvision` が無いと読み込みで止まりました（`EmbeddingGemma2Processor requires the PIL library` → `No module named 'torchvision'`）。公式ガイドのインストール例は `sentence-transformers transformers pillow soundfile torchcodec` です。画像・音声まで使うなら、こちらに従います。
:::

モデルカードには「**float16 は使わない**」とあります。活性化の値が float16 の範囲を超え、エラーを出さずに埋め込みが壊れる（NaN や品質低下）ためです。BF16 か float32 を使います。

---

## 実測：日本語ノート356件の検索

### 測り方

- データ: 自分の Obsidian の `04_Memory`（長期保存用フォルダ）から、2KB 以上で見出しのあるノート356件
- クエリ: 各ノートの見出し（H1 タイトル）
- 文書: タイトル行を除いた本文の先頭1,500字
- 指標: 正解のノートが1位に来た割合（top1）、5位以内に来た割合（top5）
- 接頭辞: `task: search result | query:` と `title: none | text:`（初代・2 とも公式推奨）

タイトルと本文の対応が正解なので、人手のラベル付けが要りません。計測の中身は「埋め込む → コサイン類似度で並べる → 正解の順位を数える」だけです。

```python
import json, math, urllib.request

def embed(texts, model, host="http://127.0.0.1:11434"):
    req = urllib.request.Request(host + "/api/embed",
        json.dumps({"model": model, "input": texts, "truncate": True}).encode(),
        {"Content-Type": "application/json"})
    vs = json.load(urllib.request.urlopen(req))["embeddings"]
    return [[x / math.sqrt(sum(y * y for y in v)) for x in v] for v in vs]

# notes = [(タイトル, 本文), ...]
D = embed(["title: none | text: " + b for _, b in notes], MODEL)
Q = embed(["task: search result | query: " + t for t, _ in notes], MODEL)
top1 = sum(max(range(len(D)), key=lambda j: sum(a * b for a, b in zip(q, D[j]))) == i
           for i, q in enumerate(Q)) / len(notes)
```

（実際には16件ずつまとめて送っています。標準ライブラリだけで動きます）

### 結果

| 動かし方 | モデル（タグ） | 量子化 | top1 | top5 | メモリ | 文書/秒 |
|---|---|---|---:|---:|---:|---:|
| Ollama | 初代 `300m`（既定） | BF16 | **87.1%** | 97.5% | 679 MB | 17.0〜22.2 |
| Ollama | 初代 `300m-qat-q4_0` | 4bit（QAT） | 86.2% | 97.5% | 295 MB | 21.2 |
| Ollama | 2 `270m-bf16-text` | BF16 | 85.4% | 96.9% | 542 MB | 21.7 |
| Ollama | 2 `740m-bf16` | BF16 | 85.4% | 96.9% | 1.5 GB | 21.5 |
| Ollama | 2 `270m-nvfp4-text` | 4bit | 83.1% | 97.5% | 346 MB | 18.5 |
| Ollama | 2 `740m-nvfp4`（既定） | 4bit | 83.1% | 97.5% | 1.3 GB | 17.9〜18.4 |
| sentence-transformers | 初代 | BF16 | **88.5%** | 97.5% | 0.62 GB | 10.9〜11.5 |
| sentence-transformers | 2（テキスト専用） | BF16 | 87.6% | 97.2% | 0.54 GB | 7.8〜7.9 |
| sentence-transformers | 2（全体） | BF16 | 87.6% | 97.2% | 1.49 GB | 7.3〜7.6 |

（メモリは Ollama が `ollama ps` の実行時の値、sentence-transformers が MPS 上の重み。初代 `300m` の配布サイズは622MB）

読み取れることは4つです。

1. **日本語の文章では、2 は初代を上回らない**。BF16 どうしで、Ollama では1.7ポイント、sentence-transformers では0.9ポイント初代が上でした。356件中3〜6件の差で、ほぼ互角と言える範囲です。モデルカードの MTEB Multilingual（61.15 → 61.36）とも合います
2. **2 は4bitにすると落ち幅が大きい**。2 は BF16 → nvfp4 で2.3ポイント下がりました。初代は QAT（量子化を前提に学習した版）の4bit で0.9ポイントの低下にとどまります
3. **テキスト専用でも精度は変わらない**。`270m` と `740m` は、同じ量子化なら top1 が完全に一致しました。テキストだけなら、メモリは3分の1で済みます
4. **同じモデルでも、Ollama と sentence-transformers で1〜2ポイント違う**。初代は87.1%と88.5%、2 は85.4%と87.6%でした。実装の違いがこの程度の差を生むので、1ポイント前後の差でモデルの優劣は決められません

top5 はどの組み合わせでも97%前後でした。差が出るのは、正解を最上位に置けるかどうか。そこだけです。

:::message
**統計の注意**: 356件・1回の計測です。埋め込みは同じ入力なら同じ値になるので、繰り返しても数字は変わりません。ただし、データを変えれば1ポイント程度は簡単に入れ替わります。結論は「2 は日本語の文章で初代を明確には上回らない」までにとどめます。
:::

---

## 16GB Macではまる5つのポイント

### 1. 既定タグは「全部入り・4bit」

`ollama pull embeddinggemma-2` は `740m-nvfp4`（1.3GB）です。テキストだけなら `270m-bf16-text`（実行時542MB）を指定すると、精度は上がりメモリは半分以下になります。16GB 機で LLM と並べるなら、この差は効きます。

### 2. Ollama が古いと pull できない

0.40.0 未満では 412 エラーになります。`ollama --version` を先に確かめます。

### 3. Ollama 版の「256K」は公式の文脈長ではない

Ollama のタグ一覧は「256K context window」と表示しますが、公式の文脈長は 8,192 トークンです。`ollama ps` の表示は 4096 でした。長い文書を1チャンクで埋め込むなら、Ollama 側の実効値を確かめてから使います。

### 4. sentence-transformers では 2 のほうが遅い

テキスト専用でも、2 は初代より約3割遅く出ました（7.8 対 11.2 文書/秒）。Ollama ではほぼ同じ速さでした。

### 5. 推論中の MPS 確保量は数GBまで膨らむ

sentence-transformers でバッチ16・1,500字の文書を埋め込んでいる間、MPS が確保したメモリはキャッシュ込みで6.8〜7.8GB に達しました。重みは0.5GB 台でも、LLM と並べて動かすなら `batch_size` を下げます。

---

## やりがちなアンチパターン7選

| # | アンチパターン | 代わりにやること |
|---|--------------|----------------|
| 1 | `ollama pull embeddinggemma-2` をそのまま使う | テキストだけなら `270m-bf16-text` を指定する |
| 2 | Ollama 既定タグどうしで比べて「2 は精度が落ちた」と結論する | 量子化を揃えて比べる（既定は初代が BF16、2 が4bit） |
| 3 | 「191MB で動く」をそのまま自分の Mac に当てはめる | Pixel・量子化・テキスト専用という条件を確かめる |
| 4 | float16 で動かす | BF16 か float32 を使う（エラーにならずに壊れる） |
| 5 | 検索用の接頭辞を外して使う | 2 も同じ接頭辞が推奨。外すと手元では初代が約3ポイント（87.1→84.3%）、2 が約4ポイント（83.1→79.2%）落ちた |
| 6 | 1ポイント前後の差でモデルを選ぶ | 実装が変わるだけで1〜2ポイント動く。自分のデータで測る |
| 7 | 日本語の文章だけで 2 の価値を判断する | 画像・音声・コードの検索で比べる |

アンチパターン5の数値は、Ollama の既定タグで測ったものです。

---

## 乗り換えの判断表

| 使い方 | おすすめ | 理由 |
|-------|---------|------|
| 日本語の文章だけを Ollama で検索 | **初代のまま**（軽さ優先なら `300m-qat-q4_0`） | 2 の最良タグ（`270m-bf16-text`）でも初代を1.7ポイント下回る。初代の4bit QAT 版は295MBで86.2% |
| 日本語の文章だけを Python で検索 | どちらでも | 精度はほぼ互角。2 のテキスト専用は少し軽く、約3割遅い |
| コードを検索する | **2** | 公式のコード検索で NDCG@10 が約10ポイント上 |
| 図・写真もまとめて検索 | **2** | 初代はテキストしか扱えない |
| 長い文書（2,000トークン超）を1チャンクで埋め込む | **2**（sentence-transformers 推奨） | 公式の文脈長が 8,192 トークン。Ollama の実効値は要確認 |

:::message alert
**測っていない条件**: 画像・音声・動画の埋め込み、コード検索、Matryoshka で次元を切ったときの精度、GGUF 版や mlx-community 版。本記事の結論は「日本語の文章どうしの検索」に限ります。なお Ollama のタグ一覧では、`740m` の入力欄に表示されるのは Text と Image だけで、Ollama から音声を埋め込めるかは確かめていません。
:::

---

## 実践チェックリスト

- [ ] Ollama のタグを指定した（テキストだけなら `270m-bf16-text`）
- [ ] 比べる2つのモデルの量子化を揃えた
- [ ] float16 を使っていない
- [ ] 検索用の接頭辞を付けた（sentence-transformers なら `encode_query` / `encode_document`）
- [ ] 自分のデータ（タイトル→本文など）で top1 / top5 を測った
- [ ] Ollama で使うなら 0.40.0 以上か確かめた

---

## まとめ

自分の日本語ノート356件で測ると、EmbeddingGemma 2 は初代とほぼ互角で、上回りはしませんでした（BF16 どうしで0.9〜1.7ポイント差）。Ollama の既定タグは全部入りの4bit で、そのまま使うと精度は4ポイント落ち、メモリは倍になります。テキストだけならタグを指定するのが先です。

自分は、Ollama で回しているノート検索は初代のまま残します。2 は、Vault の図解画像も同じ検索に入れるときに使うつもりです。次はそこを試します。

## 参考リンク

- [EmbeddingGemma 2 公式ブログ（Google・2026-10-06）](https://blog.google/innovation-and-ai/technology/developers-tools/embeddinggemma-2)
- [google/embeddinggemma-2（Hugging Face モデルカード）](https://huggingface.co/google/embeddinggemma-2)
- [EmbeddingGemma ドキュメント（Google AI for Developers）](https://ai.google.dev/gemma/docs/embeddinggemma)
- [sentence-transformers での使い方（公式ガイド）](https://ai.google.dev/gemma/docs/embeddinggemma/inference-embeddinggemma-with-sentence-transformers)
- [embeddinggemma-2 のタグ一覧（Ollama）](https://ollama.com/library/embeddinggemma-2/tags)
- [Ollama v0.40.0 リリースノート](https://github.com/ollama/ollama/releases/tag/v0.40.0)

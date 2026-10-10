---
title: "Uzuの「llama.cpp比4倍」を整理する — 投機的デコードを外すと27 tok/s"
emoji: "🌀"
type: "tech"
topics: ["LLM", "ローカルLLM", "llamacpp", "AppleSilicon", "MLX"]
published: true
---

## この記事で分かること

「16GBのMacで llama.cpp の4倍、なら乗り換えたほうがいいのか」。10月9日、Apple Silicon 専用の推論エンジン Uzu を 16GB の M5 で測った投稿（llama.cpp 22.0 / MLX 25.1 / Uzu 92.1 tok/s）が広まりました。

同じ M5 16GB で測り直した結果がこれです。

| エンジン | Pythonコード | 日本語の説明文 | メモリ |
|---|---:|---:|---:|
| **Uzu 0.6.2（初期状態）** | **85.9〜88.1 tok/s** | 63.4〜66.7 tok/s | 6.22 GB |
| Uzu 0.6.2（投機的デコードを外す） | 26.9 tok/s | 27.0 tok/s | 5.32 GB |
| MLX（mlx-lm 0.32.0） | 26.0〜26.6 tok/s | 26.1〜26.2 tok/s | — |
| llama.cpp b11539 | 21.3〜21.8 tok/s | 21.2〜21.5 tok/s | — |

4倍は再現しました。Uzu に同梱されている下書きモデル（投機的デコード）を外すと、Uzu は MLX とほぼ同じ速さになります。**4倍のほとんどはエンジンではなく、投機的デコードが出しています**。

この記事では、投機的デコードの有無を分けて測る方法と、その結果、使う前に知っておきたい挙動を整理します。

:::message
**対象読者**: 16GB前後のMacでローカルLLMを動かしていて、Uzu に乗り換えるか迷っている人
**検証環境**: Apple M5 / 16GB / macOS 26.7.1 / 電源接続。uzu 0.6.2（PyPI・Python 3.12 以上／macOS 26 以上）、llama.cpp b11539（GitHub Releases の Pre-release・commit 10a60cf）、mlx-lm 0.32.0。macOS 27 では未検証。モデルはすべて Qwen3.5-9B の4bit級。※2026年10月10日時点
:::

---

## 「4倍」の中身は2つある — まず整理しよう

推論エンジンの速さは、ふつう2つの要素が重なって決まります。

| 要素 | 何が速くなるか | Uzu の場合 |
|------|--------------|-----------|
| エンジン本体 | 1回の推論（forward pass）にかかる時間 | 27 tok/s。MLX（26）とほぼ同じ |
| 投機的デコード | 1回の推論で進むトークン数 | 1回あたり5.0〜6.4トークン。初期状態でオン |

投機的デコードは、小さな下書きモデルが先の数トークンを予想し、本体モデルがまとめて検証する方式です。当たれば1回で数トークン進みます。Uzu のモデルフォルダを開くと、`speculator/` に 755MB の下書きモデルと、チップ別の設定ファイル `shapes.json` が入っています。

```text
speculator/
├── config.json        # "type": "DFlashSpeculatorConfig"
├── model.safetensors  # 755,228,072 バイト
└── shapes.json        # "Apple M5": {"tree_budget": 16, ...}
```

`shapes.json` には Apple M5 / M5 Pro / M5 Max / M6 の項目があり（このモデルでは4つとも同じ値）、M5 で動かすと何もしなくても投機的デコードが有効になります。

元の投稿の比較は、**投機的デコードありの Uzu と、投機的デコードなしの llama.cpp・MLX** を並べたものです。エンジンの速さを比べた数字ではありません。

:::message alert
「Uzu は llama.cpp の4倍速い」は、投機的デコード込みの数字です。llama.cpp や MLX にも投機的デコードを足せば差は縮みます。乗り換えを決める前に、比べたいのが「エンジン」なのか「投機的デコード込みの体感速度」なのかを決めておきます。
:::

---

## なぜこうなったのか — Uzu が投機的デコードを標準にした経緯

Mirai は 2026年9月3日の公式ブログ「[Speculative decoding in uzu](https://trymirai.com/blog/speculative-decoding-in-uzu)」で、投機的デコードの実装を公開しました。自社の比較は「M5 系チップで MTPLX（MLX＋投機的デコード）のほぼ2倍、同程度の量子化の llama.cpp の3倍以上」です。ただし公称値は Qwen3.6 27B・M5 Max・1,355トークンのプロンプトという条件で、今回（Qwen3.5-9B・M5・短いプロンプト）とは直接比べられません。3〜4倍という向きが同じ、というところまでです。

採用した方式と、ブログが比較に挙げた方式は次のとおりです（「採らなかった代替案」の列は、ブログの記述をもとにした筆者の整理です）。

| 論点 | Mirai の説明 | 採らなかった代替案 | 出典 |
|------|------------|------------------|------|
| 下書きの作り方 | DFlash（ブロック拡散モデルで複数トークンを1回で並列に下書き）。本体モデルの中間層の特徴を条件に使う | 自己回帰の下書きモデル（1トークンずつ順に作るので遅い） | [DFlash 論文（ICML 2026）](https://arxiv.org/abs/2602.06036) |
| 下書きを木にする | 一直線の下書きは長くなるほど当たる確率が指数的に落ちるので、Weaver（56.7M の小さな Transformer）で候補を木に組む | 一直線の下書き | [公式ブログ](https://trymirai.com/blog/speculative-decoding-in-uzu) / [Trees from Marginals（arXiv 2607.06763）](https://arxiv.org/abs/2607.06763) |
| 下書きの長さ | 1回 16〜32 トークンの「極端に攻めた」予算で GPU を使い切る | モデル内蔵の MTP（一度に3〜4トークンの短い下書き） | 同上 |
| チップ別の設定ファイル | 木の大きさを `shapes.json` にチップ名ごとに持つ。ただしこのモデルでは M5〜M6 の4項目とも同じ値（tree_budget 16 など） | （記載なし） | 同梱の `shapes.json` |

設定ファイルを見ると、DFlash の下書きモデルは本体の32層のうち 1, 5, 9, …, 29 層目の特徴を読む作りです（`target_layer_ids`）。本体と一緒に設計されているので、下書きモデルだけ別のモデルに付け替えることはできません。

:::message
この経緯を知っていると、Uzu の速さは「エンジン」より「**本体モデルごとに用意された下書きモデルの当たり具合**」で決まる、と読めます。下書きモデルが用意されていないモデルでは、4倍は出ません。
:::

---

## 前提：Uzu とは何か

Uzu は Mirai（trymirai）の Apple Silicon 専用推論エンジンです（Rust製・MIT）。Python・Swift・TypeScript・Rust から同じ API で呼べます。モデルは Mirai が独自に量子化したものを、公式のモデル一覧（レジストリ）から取ります。今回使ったのは `alibaba:qwen3.5:9b:mirai:mirai-m:4`（Qwen3.5-9B の4bit量子化・本体5.19GB）です。

---

## セットアップ（検証済みの手順）

モデルカード（Hugging Face の `trymirai/Qwen3.5-9B-M`）のおすすめは `brew install mirai` ですが、手元では Xcode のライセンスに同意していなかったため途中で止まりました（`sudo xcodebuild -license accept` が必要）。本記事は Python SDK で進めています。

```bash
mkdir uzu-bench && cd uzu-bench
uv init --bare && uv add uzu==0.6.2
```

モデルの一覧から Qwen3.5 系の ID を確認します。

```python
import asyncio
from uzu import Engine, EngineConfig

async def main():
    engine = await Engine.create(EngineConfig.create())
    for m in await engine.models():
        if "qwen3.5" in m.identifier:
            print(m.identifier)   # alibaba:qwen3.5:9b:mirai:mirai-m:4 など

asyncio.run(main())
```

:::message alert
SDK の `engine.download()` は、手元では進捗0%のまま「完了」を返し、重み（`model.safetensors`）が落ちていませんでした。その場合は Hugging Face の `trymirai/Qwen3.5-9B-M` から落として、`~/.cache/mirai/models/mirai/alibaba-qwen3.5-9b-mirai-mirai-m-4/<ハッシュ>/` に置くと読み込めます。
:::

```bash
uvx --from huggingface_hub hf download trymirai/Qwen3.5-9B-M --local-dir ./uzu-model
# model.safetensors / tokenizer.json / speculator/ を上記のキャッシュフォルダへ移す
```

---

## 実測：投機的デコードのオン・オフを分けて測る

### 測り方

- モデル: すべて Qwen3.5-9B の4bit級。Uzu は Mirai-M 4bit（5.19GB）、llama.cpp は `unsloth/Qwen3.5-9B-GGUF` の Q4_K_M（5.68GB）、MLX は `mlx-community/Qwen3.5-9B-MLX-4bit`（5.95GB）
- 設定: greedy（temperature 0）・出力256トークン・warmup 1回
- プロンプト: 日本語の説明文 / Pythonコード / 英語の推論説明 の3種 × 3回の中央値
- decode 速度 = (出力トークン数 − 1) ÷ (最初のトークンから最後のトークンまでの時間)
- 順番: Uzu（投機あり）→ Uzu（投機なし）→ llama.cpp → MLX を2周。電源接続・空きメモリ約8.3GB

llama.cpp と MLX は前回の記事の HTTP 計測スクリプトで測りました。mlx-lm 0.32 のサーバーは思考部分を `reasoning` という項目名で返すので、それも数えるよう1行足しています。Uzu は同じ指標を SDK から測るスクリプトで計測しました（API は [Python バインディングの型定義](https://github.com/trymirai/uzu/blob/main/crates/legacy/uzu/bindings/python/uzu/__init__.pyi) で確認）。Uzu の核になる部分はこれです。

```python
async def run(engine, model, prompt):
    session = await engine.chat(model, ChatConfig.create())   # 毎回新規（前回の状態を使わない）
    cfg = (ChatReplyConfig.create().with_token_limit(256)
           .with_sampling_method(SamplingMethod.Greedy()))
    t0 = time.perf_counter(); first = last = None; prev = 0
    stream = await session.reply_with_stream([ChatMessage.user().with_text(prompt)], cfg)
    async for chunk in stream:
        if isinstance(chunk, ChatSessionStreamChunk.Replies) and chunk.replies:
            reply = chunk.replies[0]
            n = reply.stats.tokens_count_output or 0
            if n > prev:
                now = time.perf_counter(); first = first or now; last = now; prev = n
    sp = reply.stats.speculator_stats          # 投機的デコードの統計
    return {"tps": (prev - 1) / (last - first),
            "tok_per_pass": sp.tokens_per_forward_pass if sp else None}
```

`speculator_stats.tokens_per_forward_pass` が1回の推論で進んだトークン数です。投機的デコードが効いているかどうかは、この値で確かめられます。

### 投機的デコードを外す方法

ここが一番手間取りました。最初は `speculator/` フォルダの名前を変えたり、`shapes.json` から M5 の項目を消したりしましたが、どちらも読み込みに失敗します。

```text
RuntimeError: Backend error: I/O error: No such file or directory (os error 2)
```

Uzu はキャッシュ内のファイルを公式のハッシュと照合していて、書き換えた `shapes.json` は**削除されていました**。キャッシュ内のファイルは触らないのが正解です。

最終的に、speculator を含まないフォルダを別に作り、パス指定で読み込みました。ただしパス指定だけでは `Unable to load model: can not get encoding config` で止まります。チャット用の設定はモデルフォルダではなく公式レジストリ側にあるので、そこだけ移します。

```python
rm = await engine.model("alibaba:qwen3.5:9b:mirai:mirai-m:4")     # レジストリ版
pm = await engine.model_by_path("/path/to/uzu-nospec")            # speculator なしのフォルダ
model = Model(pm.identifier, pm.registry, pm.backends, pm.family, pm.properties,
              pm.quantization, pm.specializations, pm.accessibility,
              rm.encoding)                                          # エンコーディングだけ移植
```

`uzu-nospec` には `config.json`・`model.safetensors`・`tokenizer.json` へのシンボリックリンクだけを置いています。これで `tokens_per_forward_pass` が 1.0 になり、投機的デコードなしで動きます。

### 結果

| エンジン | 日本語の説明文 | Pythonコード | 英語の推論説明 | 1回で進むトークン数 | 最初のトークンまで |
|---|---:|---:|---:|---:|---:|
| Uzu（投機あり） | 63.4 / 66.7 | **85.9 / 88.1** | 71.4 / 69.6 | 5.0〜6.4 | 0.21〜0.24秒 |
| Uzu（投機なし） | 27.0 / 27.0 | 26.9 / 26.9 | 26.9 / 26.9 | 1.0 | 0.18〜0.19秒 |
| MLX | 26.1 / 26.2 | 26.0 / 26.6 | 26.1 / 26.5 | — | 0.08秒 |
| llama.cpp | 21.2 / 21.5 | 21.3 / 21.8 | 21.4 / 22.9 | — | 0.08〜0.10秒 |

（単位は tok/s、「1周目 / 2周目」。どれも256トークンを最後まで出力）

1回で進むトークン数の内訳は、日本語の説明文 5.1〜5.2、Pythonコード 5.9〜6.4、英語の推論説明 5.0〜5.4 でした。

読み取れることは3つです。

1. **エンジン本体の差は小さい**。投機なしの Uzu は MLX より約3%、llama.cpp より17〜27%速い。4倍との差のほとんどは投機的デコードの分です。M5 のメモリ帯域（153GB/s）と重み5.19GB から見た理論上限は約29 tok/s で、投機なしの27 tok/s はその9割強。投機なしでは、どのエンジンもこの天井の近くにいます
2. **投機的デコードの効きは内容で変わる**。コードが最も効き（1回あたり5.9〜6.4トークン、llama.cpp の4.0倍）、日本語の説明文が最も効かない（5.1〜5.2トークン、3.0倍）。続きが予想しやすい出力ほど当たります
3. **投機の代償はメモリ +0.9GB**。最初のトークンまでの時間は、投機ありで0.21〜0.24秒、投機なしで0.18〜0.19秒でした（投機の上乗せは0.02〜0.06秒）。llama.cpp・MLX（0.08〜0.10秒）との差は、投機より計測経路の違い（下記）による部分が大きいとみています

測る前は、エンジン本体にも何か仕掛けがあると思っていました。投機を外した Uzu が MLX と1 tok/s以内に並んだのを見て、差はほぼ下書きモデルの分だと感じた、というのが正直なところです。

なお、Uzu は SDK から、llama.cpp と MLX は HTTP サーバー経由で測っています。最初のトークンまでの時間は計測経路の違いも含むので、参考値として見てください。

---

## 投機ありは「同じ入力でも毎回出力が変わる」

速さとは別に、気になる挙動がありました。greedy（毎回いちばん確率の高いトークンを選ぶ設定）なのに、投機ありの Uzu は同じプロンプトを2回流すと出力が変わります。

（日本語の説明文と Pythonコードの2プロンプトで確認）

| 条件 | 同じ入力を2回流したとき |
|------|----------------------|
| Uzu（投機あり） | 2プロンプトとも**一致しない** |
| Uzu（投機なし） | 2プロンプトとも完全一致 |

投機ありと投機なしの出力は、200〜300文字目で分かれました。

```text
投機あり: *   **Length:** Approximately 400 Japanese characters (400 字程度).
投機なし: *   **Length:** Around 400 Japanese characters (400 字程度).
```

DFlash の論文がうたう「lossless」は、本体モデルの出力の確率分布を変えないという意味で、毎回ビット単位で同じ出力になる保証ではありません。Mirai のブログは、検証の手順や木の枝刈り、活性化の8bit量子化（「virtually lossless」）にも触れています。手元では毎回同じ出力にはなりませんでしたが、原因は特定できていません。品質の比較もしていないので、劣化したかどうかは分かりません。

:::message alert
テストの期待値と照合する、ログを比べて差分を見る、といった「同じ入力なら同じ出力」が前提の使い方では、投機ありの Uzu は避けたほうが安全です。
:::

---

## 16GB Macではまる5つのポイント

### 1. ダウンロードが「完了」でも重みが無いことがある

`~/.cache/mirai/models/` の容量が5GB台になっているか確かめます。

### 2. キャッシュのファイルを書き換えると消される

設定を変えたいときは、キャッシュの外に別フォルダを作ります。

### 3. フォルダのパス指定だけでは読み込めない

パス指定のモデルには、レジストリ版の `encoding` を移します。

### 4. 起動時に外のクラウドにも問い合わせる

手元の環境では、SDK が起動時に、環境変数にある API キー（OpenAI・xAI・OpenRouter など）でクラウドのモデル一覧も取りに行っていました（`~/.cache/mirai/mirai.log` に別サービスのクレジット切れエラーが残っていた）。公式ドキュメントのクラウド例はキーを明示的に渡す書き方で、環境変数から自動で読む仕様の記述は見つかりませんでした。ローカル専用のつもりで入れるなら、ログを一度見ておきます。

### 5. 投機ありはメモリを 0.9GB 多く使う

下書きモデルの分、投機なし（5.32GB）より 0.9GB 多い 6.22GB でした。16GB機で Claude Code などと並べて使うなら、この差は効きます。

---

## やりがちなアンチパターン7選

| # | アンチパターン | 代わりにやること |
|---|--------------|----------------|
| 1 | 「4倍」をエンジンの速さだと思う | `tokens_per_forward_pass` を見て、投機的デコードの寄与を分ける |
| 2 | 投機ありの Uzu と、投機なしの llama.cpp を並べて結論を出す | 両方を投機なしに揃えるか、両方に投機的デコードを入れる（llama.cpp は `--spec-type draft-dflash`） |
| 3 | コードだけで測る | 日本語の説明文も測る。手元では3.0倍まで下がった |
| 4 | キャッシュ内の設定ファイルを直接いじる | キャッシュの外に別フォルダを作り、パス指定で読む |
| 5 | ダウンロード完了の表示を信じる | キャッシュの容量でモデル本体があるか確かめる |
| 6 | 投機ありの出力でテストの期待値を作る | 再現性が要る用途は投機なしで動かす |
| 7 | バッテリー駆動のまま測る | 電源につなぎ、エンジンを交互に測る（前回の記事で約7%落ちた） |

---

## 推論エンジン比較（16GB M5・Qwen3.5-9B 4bit級）

| エンジン | decode | 投機的デコード | メモ |
|---------|------:|:---:|------|
| Uzu 0.6.2（初期状態） | 63.4〜88.1 tok/s | あり（DFlash・自動） | 内容で差が大きい。出力が毎回変わる |
| Uzu 0.6.2（投機なし） | 26.9〜27.0 tok/s | なし | 本記事の手順で外した |
| MLX（mlx-lm 0.32.0） | 26.0〜26.6 tok/s | なし | `mlx_lm.server` |
| llama.cpp b11539 | 21.2〜22.9 tok/s | なし | `llama-server -ngl 99 -c 4096` |

前回の [Magnitude の記事](https://zenn.dev/amu_lab/articles/magnitude-vs-llamacpp-16gb-mac-benchmark) では、投機的デコード（DSpark）を外せませんでした。Uzu は外せたので、今回は内訳まで出せています。量子化の方式は3者で違い、同じファイルどうしの比較ではありません。

:::message alert
**測っていない条件**: 長いコンテキスト（Mirai の公称値はプロンプト1,355トークン）、27B 級のモデル、そして **llama.cpp・MLX 側に投機的デコードを入れた場合**。llama.cpp は `--spec-type draft-dflash` で DFlash に対応していて、Qwen3.5-9B 用の下書きモデル（`z-lab/Qwen3.5-9B-DFlash`）もあります（[llama.cpp docs/speculative.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md)）。MLX にも `mlx_lm.server --draft-model` や dflash-mlx があります。本記事の比較は「投機ありの Uzu 対 投機なしの llama.cpp・MLX」で、投機どうしの公平な比較ではありません。
:::

---

## 実践チェックリスト

- [ ] モデルフォルダに `speculator/` や下書きモデルがあるか確かめた
- [ ] `tokens_per_forward_pass`（または同等の統計）で、1回の推論で何トークン進んでいるかを見た
- [ ] 投機あり／なしの両方を、同じプロンプト・greedy・同じ出力長で測った
- [ ] コードだけでなく、日本語の文章でも測った
- [ ] 電源につなぎ、エンジンを交互に2周測った
- [ ] 再現性が要る用途なら、同じ入力を2回流して出力が一致するか確かめた

---

## まとめ

16GBのM5で Qwen3.5-9B を測ると、Uzu は初期状態で 63〜88 tok/s、llama.cpp は 21〜23 tok/s でした。元の投稿の4倍は、コード生成ならそのまま再現します。ただ、同梱の下書きモデルを外した Uzu は 27 tok/s で、MLX の 26 tok/s とほとんど変わりません。速さの正体は、エンジンより投機的デコードです。

自分は、コードを書かせる用途なら Uzu を使い、出力を比べたい検証作業には投機なしのエンジンを使うことにします。次は llama.cpp の `draft-dflash` と MLX 側にも投機的デコードを入れて、投機どうしで並べ直します。

## 参考リンク

- [trymirai/uzu（GitHub）](https://github.com/trymirai/uzu)
- [Speculative decoding in uzu（Mirai 公式ブログ・2026-09-03）](https://trymirai.com/blog/speculative-decoding-in-uzu)
- [DFlash: Block Diffusion for Flash Speculative Decoding（arXiv 2602.06036）](https://arxiv.org/abs/2602.06036)
- [Trees from Marginals: Autoregressive drafting with factorized priors（arXiv 2607.06763・Weaver の論文）](https://arxiv.org/abs/2607.06763)
- [trymirai/sglang（DFlash-TfM の再現用リポジトリ）](https://github.com/trymirai/sglang)
- [trymirai/Qwen3.5-9B-M（Hugging Face）](https://huggingface.co/trymirai/Qwen3.5-9B-M)
- [前回: Magnitudeの「llama.cpp比2倍」を整理する](https://zenn.dev/amu_lab/articles/magnitude-vs-llamacpp-16gb-mac-benchmark)

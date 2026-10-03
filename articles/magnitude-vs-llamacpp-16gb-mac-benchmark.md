---
title: "Magnitudeの「llama.cpp比2倍」を整理する — 16GB Macでは逆だった"
emoji: "🧪"
type: "tech"
topics: ["LLM", "ローカルLLM", "llamacpp", "AppleSilicon", "Magnitude"]
published: true
---

## この記事で分かること

「llama.cpp より最大2倍速い、なら乗り換えたほうがいいのか」。9月30日に公開された推論エンジン Magnitude を見て、そう思った人は多いはずです。

結論から書きます。**16GBのM5 Macで同じGGUFを動かしたら、llama.cpp のほうが速かった**。

| | Magnitude 0.2.4 | llama.cpp b8680 | llama.cpp 最新（b11370） |
|---|---:|---:|---:|
| decode（3種のプロンプトの中央値） | 88.9〜97.0 tok/s | 102.4〜104.7 tok/s | 103.7〜105.1 tok/s |
| 最初のトークンまで | 0.13秒 | 0.10秒 | 0.04秒 |
| Claude Code を開いたまま読み込めるか | **断られた** | 動いた | 動いた |

公称の数字が嘘だったわけではありません。測っている条件がまったく違います。この記事では、公称値がどの条件の数字なのかを一次情報で確かめたうえで、16GB機での実測と、使うときにはまる箇所を整理します。

:::message
**対象読者**: 16GB前後のMacでローカルLLMを動かしていて、Magnitude に乗り換えるか迷っている人
**検証環境**: Apple M5 / 16GB / macOS 26.7 / Magnitude 0.2.4 / llama.cpp b8680（Homebrew）と b11370（公式リリース・2026-10-03ビルド）。電源接続時に計測。※2026年10月3日時点
:::

---

## 「2倍速い」には条件が2つある — まず整理しよう

Magnitude の README には「Up to 2x faster than llama.cpp: 92% faster decode on Metal, 19% on CUDA」とあります。ただ、README にはどの条件で測ったかが書かれていません。

条件は、開発者が Hacker News のローンチ投稿で書いています。

> Benchmarked against llama.cpp with Qwen 3.6 35B A3B (4 bit), 64k context, no speculative decoding
> — anerli（Magnitude 開発者）, [Launch HN: Magnitude (YC S25)](https://news.ycombinator.com/item?id=49911995)

これを、16GB機の普段の使い方と並べるとこうなります。

| 項目 | 公称値の条件 | 16GB Macの普段の条件（本記事） |
|------|------------|------------------------------|
| モデル | Qwen 3.6 35B-A3B（4bit） | LFM2.5 8B-A1B（Q4_K_M） |
| コンテキスト | 64k | 短い（プロンプト数十トークン） |
| 投機的デコード | なし | **DSpark が自動でオン**（切れない） |
| マシン | M4 Pro 48GB で 30→57 tok/s（[GIGAZINE](https://gigazine.net/gsc_news/en/20261001-magnitude/)） | M5 16GB |
| 16GBで動くか | 35B-A3B の4bitは載らない | 載る |

つまり公称値は「**16GB機では動かせないモデルを、長いコンテキストで回したとき**」の数字です。16GB機の利用者が普段使う条件とは、ほぼ重なりません。

:::message alert
「Magnitude は llama.cpp の2倍速い」は条件抜きでは言えません。自分の機種・自分のモデル・自分のコンテキスト長で測るまで、乗り換えの判断材料にしないほうが安全です。
:::

---

## なぜこうなったのか — 設計の経緯

Magnitude の速さの源は「カーネルを手元のチップで調整すること」です。README はこう説明しています。

> They ship kernels precompiled for broad classes of hardware. Magnitude compiles and tunes its kernels on your actual device before a model runs, so they fit your exact chip.

llama.cpp や Ollama は「どの機種でもそこそこ速い」汎用カーネルを配っています。Magnitude は、モデルを入れたときに手元のチップ向けに調整し直す方式を選びました。

| 論点 | 開発者の説明 | 16GB M5で見えたこと | 出典 |
|------|------------|-------------------|------|
| カーネルを実機で調整する | 汎用カーネルでは機種ごとの性能の天井に届かない | 調整は16%時点から46秒で終わった | [README](https://github.com/magnitudedev/magnitude) / HN |
| 調整は1回だけ | 「新しいモデルを入れるたびに約1分。それ以上回しても伸びない」 | 公称どおり1分以内 | [HN](https://news.ycombinator.com/item?id=49911995) |
| M5 世代への対応 | 「M5+ の新しい行列演算をまだ使い切れていない可能性がある。カーネルに取り込んで M5 で測る」 | **M5 で llama.cpp に負けた理由の最有力候補** | [HN](https://news.ycombinator.com/item?id=49911995) |
| 投機的デコード | カタログのモデルごとに方式を決めて自動で有効化する。利用者は選ばない | DSpark を切って比べることができない | 同梱 `magnitude docs speculative-methods` |
| システム用のメモリ予約 | 理由を説明した一次情報は見つからなかった | 2GiB を必ず残し、足りなければ読み込まない | 実機のエラーメッセージ |

M5 世代への最適化が追いついていないことは、開発者自身が HN で認めています。今回の結果は、その告白とつじつまが合います。

:::message
この経緯を知っていると、**Magnitude の数字は「機種」と「バージョン」をセットで読む**、という判断ができます。M5 向けの最適化が入ったら、測り直す価値があります。
:::

---

## 前提：Magnitude とは何か

Magnitude は YC S25 のチームが作った、エージェント向けのローカル推論エンジンです（Apache 2.0、Rust製、2026年9月30日公開）。Metal・NVIDIA・AMD・CPU で動き、OpenAI 互換と Anthropic 互換の API で Claude Code などにつなげます。デスクトップアプリのカタログは、**この機種で動くモデルだけ**を予測速度つきで出します。

---

## セットアップ（検証済みコマンド）

### インストール

[magnitude.dev](https://magnitude.dev) からデスクトップ版の dmg（`magnitude-desktop-darwin-arm64.dmg`、204MB）を落として、Applications に入れます。

CLI はアプリに同梱されていますが、**PATH には入りません**。

```bash
M=/Applications/Magnitude.app/Contents/Resources/magnitude
$M --version      # 0.2.4
$M hardware       # Apple M5 / 16 GB unified memory · Metal GPU acceleration
```

### モデルを入れて読み込む

カタログには、この機種と互換のモデルだけが出ます（M5 16GBでは20モデル）。

```bash
$M catalog list                               # 互換モデルと予測速度
$M catalog pull lfm2.5-8b-a1b:gguf:q4         # ダウンロード → Optimizing（実機での調整）
$M models status lfm2.5-8b-a1b:gguf:q4        # Installed になるまで待つ
$M models load lfm2.5-8b-a1b:gguf:q4          # 読み込み（3秒だった）
```

API は 10100番ポートです。

```bash
curl -s 127.0.0.1:10100/inference/v1/models   # OpenAI互換
# Anthropic互換は http://127.0.0.1:10100/inference/anthropic
```

`catalog pull` で入るのは、Hugging Face の標準 GGUF（`LiquidAI/LFM2.5-8B-A1B-GGUF` の `Q4_K_M`）と、DSpark 用の下書きモデル（`LFM2.5-8B-A1B-DSpark-Q8_0.gguf`）の2つです。本体は標準 GGUF なので、**llama.cpp でも同じファイルをそのまま読めます**。今回の比較はこれを利用しました。

### Claude Code につなぐ

Claude Code・Codex・OpenCode などへの接続は `connections` で行います。

```bash
$M connections list                                              # 対応ハーネスと接続状態
$M connections add claude-code --set-model lfm2.5-8b-a1b:gguf:q4   # 接続＋モデル選択
```

:::message
接続コマンドは `--help` と `connections list` で確かめただけで、本記事では実行していません。Claude Code の設定を書き換えるコマンドなので、試すなら設定のバックアップを取ってからにしてください。
:::

---

## 実測：同じGGUFで比べた

### 測り方

両方のエンジンに、同じスクリプトで OpenAI 互換 API を叩きました。

- モデル: 同一ファイル `LFM2.5-8B-A1B-Q4_K_M.gguf`
- llama.cpp: `llama-server -m <同じファイル> -ngl 99 -c 4096`
- 設定: stream・temperature 0・出力256トークン・warmup 1回
- プロンプト: 日本語の説明文 / Pythonコード / 英語の推論説明 の3種 × 3回の中央値
- decode 速度 = (出力トークン数 − 1) ÷ (最初のトークンから最後のトークンまでの時間)

計測スクリプトは標準ライブラリだけで書いています。

```python
#!/usr/bin/env python3
"""usage: bench.py BASE_URL MODEL LABEL"""
import json, sys, time, urllib.request, statistics

BASE, MODEL, LABEL = sys.argv[1:4]
PROMPTS = {
    "ja_prose": "工場の設備保全担当者向けに、予知保全とは何かを、具体例を交えて400字程度で説明してください。",
    "code": "Write a Python function that parses a CSV of sensor readings (timestamp,value) and returns hourly averages. Include docstring and type hints.",
    "en_reason": "Explain step by step why a mixture-of-experts model with 1.5B active parameters can decode faster than a dense 8B model on the same laptop.",
}
REPS, MAX_TOKENS = 3, 256

def run(prompt):
    body = json.dumps({"model": MODEL, "messages": [{"role": "user", "content": prompt}],
                       "max_tokens": MAX_TOKENS, "temperature": 0, "stream": True,
                       "stream_options": {"include_usage": True}}).encode()
    req = urllib.request.Request(BASE + "/chat/completions", body,
                                 {"Content-Type": "application/json", "Authorization": "Bearer x"})
    t0 = time.perf_counter(); first = last = None; chunks = 0; usage = None
    with urllib.request.urlopen(req, timeout=600) as r:
        for line in r:
            line = line.decode().strip()
            if not line.startswith("data:") or line == "data: [DONE]":
                continue
            d = json.loads(line[5:])
            usage = d.get("usage") or usage
            for c in d.get("choices", []):
                delta = c.get("delta", {})
                if delta.get("content") or delta.get("reasoning_content"):
                    now = time.perf_counter(); first = first or now; last = now; chunks += 1
    n = (usage or {}).get("completion_tokens") or chunks
    return {"ttft": first - t0, "n": n, "tps": (n - 1) / (last - first)}

run("hi")  # warmup
for name, p in PROMPTS.items():
    rs = [run(p) for _ in range(REPS)]
    print(LABEL, name, round(statistics.median(r["tps"] for r in rs), 1), "tok/s",
          "ttft", round(statistics.median(r["ttft"] for r in rs), 3), "s")
```

```bash
python3 bench.py http://127.0.0.1:10100/inference/v1 lfm2.5-8b-a1b:gguf:q4 magnitude
python3 bench.py http://127.0.0.1:8099/v1 lfm llamacpp
```

### 結果

計測は3回に分けて行いました。①Magnitude と llama.cpp b8680 を続けて測る ②再起動直後に順番を逆にする ③電源につないで、Magnitude・最新版・旧版を交互に2周する、の3回です。

| プロンプト | Magnitude 0.2.4（①） | b8680（①） | b8680（②） | b8680（③×2周） | b11370（③×2周） |
|---|---:|---:|---:|---:|---:|
| 日本語の説明文 | 91.8 | 102.7 | 104.7 | 103.3 / 103.9 | 105.1 / 104.7 |
| Pythonコード | 97.0 | 102.8 | 104.7 | 102.7 / 103.2 | 105.1 / 104.2 |
| 英語の推論説明 | 88.9 | 102.7 | 104.7 | 102.4 / 103.0 | 105.0 / 103.7 |
| 最初のトークンまで | 0.13秒 | 0.10秒 | 0.10秒 | 0.10秒 | 0.04秒 |

（単位は tok/s。どれも256トークンを最後まで出力）

llama.cpp b8680 は、3回のセッションを通して 102.4〜104.7 tok/s に収まりました。ぶれは約2%で、Magnitude との差（6〜13%）よりずっと小さい。**順番や時間帯のせいで逆転した、ということはありません**。

最新版 b11370 は decode がほぼ同じ（+1〜2%）で、最初のトークンまでの時間が半分以下（0.10秒→0.04秒）になりました。

Magnitude ではコードがいちばん速く出ました。投機的デコードは次のトークンを当てやすい出力ほど効くので、DSpark が効いている兆候だと読んでいます。それでも llama.cpp には届きませんでした。

:::message
Magnitude のカタログが出していたこの機種の予測は「~61–81 tok/s」でした。実測はそれより速く、予測は控えめに出る傾向があるようです。
:::

### Magnitude が1回しか測れなかった理由

②と③では、Magnitude を測れませんでした。読み込みを断られたからです。

```text
Runtime  Failed - not enough memory available: model requires 5395527424 bytes
plus 2147483648 bytes reserved for the system; 5729337344 bytes are available
(1813673729 bytes short)
```

②は再起動から5分後、③は Chrome を閉じて電源につないだ状態で、開いていたのはターミナルと Claude Code くらいでした。2回のセッションで合わせて36回試し、全部同じエラーです。**同じ状態で、llama.cpp は同じファイルを103〜105 tok/s で動かしていました**。①で読み込めたのは、ほかのアプリをすべて閉じて空きが約8.3GBあったときです。

---

:::message alert
**測っていない条件**: 公称値の条件である「64kの長いコンテキスト」では測っていません。開発者は KV キャッシュの量子化など長いコンテキスト向けの工夫を挙げているので、長い入力では差が縮むか逆転する可能性があります。本記事の結論は「短いプロンプトでの会話・コード生成」に限ります。
:::

## 16GB Macではまる5つのポイント

### 1. 入れただけでログイン時に常駐する

`magnitude status` を見ると `Starts at login: Yes` が初期値です。管理サービスと推論サーバーが常にポートを開いています。使わない日はアプリの設定で切っておきます。

### 2. CLIはサービスを起動しない

メモリを空けようとアプリを閉じたら、ダウンロードが1.7GBで止まりました。CLI は `No Magnitude service is running.` と返すだけです。同梱ドキュメントにも「setup commands require an existing service; they do not start one」とあります。**デスクトップアプリを開いたまま**作業します。`catalog pull` をやり直せば、途中から再開されました。

### 3. メモリが足りないと「読み込まない」

Magnitude は、モデル本体に加えてシステム用に **2GiB（2,147,483,648バイト）を必ず残し**、足りなければ読み込みを拒否します。llama.cpp は足りなくてもとりあえず動かすので、ここが一番大きな体感差でした。16GB機で Claude Code を開いたままだと、5GB級のモデルでも通らないことがあります。

### 4. DSparkを切れない

投機的デコードの方式はカタログ側で決まっていて、利用者は選べません。そのため「カーネル調整の効果」と「投機的デコードの効果」を分けて測れません。今回の数字も、両方込みの結果です。



### 5. バッテリー駆動で測ると1割近く落ちる

一度、バッテリー駆動のまま測ってしまいました。同じ b8680 が 93.3〜97.4 tok/s で、電源接続時（102〜105）より約7%低く出ています。この落ち幅は、Magnitude との差とほぼ同じ大きさです。**比較は必ず電源につないで、同じ時間帯に交互に測ります**。
---

## 開発者と独立検証者が言っていること

HN のローンチスレッドには、16GB機の判断に効く発言が並んでいます。

| 発言者 | 内容 | 本記事との関係 |
|-------|------|--------------|
| anerli（開発者） | 公称値は Qwen 3.6 35B-A3B 4bit・64k・投機的デコードなし | 条件が16GB機と重ならない |
| anerli（開発者） | M5+ の新しい行列演算を使い切れていない可能性 | M5での逆転の最有力候補 |
| anerli（開発者） | KV キャッシュを8bitキー・4bit値に量子化し、使用量を半分以下に | 長いコンテキストでは効く可能性 |
| kmike84（M5 Max） | アプリが表示する予測速度は、128K未満では手元の mtplx の実測の約半分 | 予測が控えめに出る点は本記事と一致 |
| herf（RTX 5070 Ti） | llama.cpp のほうが decode で20〜30%速い | NVIDIAでも同じ向き |
| bythreads（M5 Max） | Magnitude 161 tok/s、MLX系 175 tok/s | 差は小さいが MLX が上 |

NVIDIA と M5 Max の報告は、どちらも「llama.cpp や MLX のほうが速い」向きです。自分の結果（M5・短いコンテキストで llama.cpp が約1割上）も同じ向きでした。

---

## やりがちなアンチパターン7選

| # | アンチパターン | 代わりにやること |
|---|--------------|----------------|
| 1 | README の「2x」だけ見て乗り換える | HN の条件（35B-A3B・64k・投機的デコードなし）と自分の条件を並べる |
| 2 | Magnitude の予測速度を実測扱いする | 同じGGUFで llama.cpp と並べて測る |
| 3 | 違うGGUFどうしで比べる | `catalog pull` で入った標準GGUFを llama.cpp にも読ませる |
| 4 | 1回だけ測って結論を出す | 3種×3回の中央値、順番を入れ替えてもう1回。使わない日はログイン時の自動起動も切る |
| 5 | メモリを空けようとしてアプリごと閉じる | Magnitude は残し、ほかのアプリを閉じる |
| 6 | 読み込み失敗を「モデルが重い」で片づける | エラーのバイト数で、何GB足りないかを確かめる |
| 7 | バッテリー駆動のまま測る | 電源につなぎ、エンジンを交互に測る |

---

## 16GB機で読み込めるかの目安

Magnitude が読み込むのに必要なメモリは、エラーメッセージから次の式で読めます。

```text
必要量 = モデル本体 + 2GiB（システム予約）
```

| 項目 | 値 |
|------|---:|
| LFM2.5 8B-A1B Q4 本体 | 5.40GB |
| システム予約 | 2.15GB |
| 必要量 | **7.54GB** |
| Magnitude が数えた空き（再起動直後・Claude Code起動中） | 5.73〜6.41GB |
| 読み込めたとき（ほかのアプリを全部閉じた状態） | 空き約8.3GB |

16GB機で Claude Code と並べて使うなら、**本体が4GB前後までのモデル**（カタログでは Gemma 4 E2B・LFM2.5 2.6B・MiniCPM5 1B など）が現実的なラインです。※この目安は今回の数字からの見立てで、各モデルを読み込んで確かめたわけではありません。

---

## 推論エンジン比較（16GB M5・LFM2.5 8B-A1B）

| エンジン | decode | 測定日 | メモ |
|---------|------:|-------|------|
| llama.cpp b11370 | 103.7〜105.1 tok/s | 2026-10-03 | 公式リリース・同一GGUF・`-ngl 99` |
| llama.cpp b8680 | 102.4〜104.7 tok/s | 2026-10-03 | Homebrew・同一GGUF |
| Magnitude 0.2.4 | 88.9〜97.0 tok/s | 2026-10-03 | DSpark 自動・2GiB予約 |
| Ollama（Q4） | 84.3 tok/s | 2026-06-01 | 別バージョン・参考値 |
| MLX（8bit） | 58.3 tok/s | 2026-06-01 | 量子化が違う・参考値 |

同じ条件で比べたのは上の2行だけで、Ollama と MLX は4か月前の参考値です。

---

## 実践チェックリスト

- [ ] 公称値の条件（モデル・コンテキスト長・投機的デコード）を確かめた
- [ ] 自分のマシンでカタログが出す予測速度を見た
- [ ] `catalog pull` で入った標準GGUFを、llama.cpp にも読ませた
- [ ] 同じプロンプト・temperature 0・同じ出力長で、両方を3回ずつ測った
- [ ] 電源につなぎ、測る順番を入れ替えて、もう1回測った
- [ ] 読み込みを断られたら、エラーのバイト数で不足量を確かめた
- [ ] 使わない日はログイン時の自動起動を切った

---

## まとめ

16GBのM5 Macで、同じGGUFを使って測った結果は、llama.cpp が103〜105 tok/s、Magnitude が89〜97 tok/s でした。公称の「Metalで+92%」は、35B-A3B・64kコンテキスト・投機的デコードなしという、16GB機では再現できない条件の数字です。

自分は、しばらく llama.cpp のままでいきます。速さで負けたことより、Claude Code を開いたままだと読み込みを断られることのほうが、普段使いでは効きました。開発者は M5 世代の行列演算への対応を予告しています。それが入ったら、このスクリプトでもう一度測ります。

## 参考リンク

- [magnitudedev/magnitude（GitHub）](https://github.com/magnitudedev/magnitude)
- [Launch HN: Magnitude (YC S25)](https://news.ycombinator.com/item?id=49911995)
- [Issue #160: M1 Max での読み込み失敗（Docker VM が27GBを保持して not enough memory になった事例を含む）](https://github.com/magnitudedev/magnitude/issues/160)
- [LiquidAI/LFM2.5-8B-A1B-DSpark-GGUF](https://huggingface.co/LiquidAI/LFM2.5-8B-A1B-DSpark-GGUF)
- [GIGAZINE: Magnitude 紹介記事](https://gigazine.net/gsc_news/en/20261001-magnitude/)

---
title: "【2026年最新】iPhoneで動くBonsai 27B完全ガイド — 「Bonsai」と「Ternary-Bonsai」の違いからモデル選択まで"
emoji: "🌳"
type: "tech"
topics: ["LLM", "mlx", "llamacpp", "AI", "iOS"]
published: true
---

:::message
本記事は **2026年7月16日時点** の情報に基づきます。Bonsai 27Bは2026年7月14日リリースの新しいモデルで、HuggingFace上のバリアント構成やベンチマークは今後更新される可能性があります。数値は各モデルカード・公式発表を主に、実測値との差がある箇所は併記しています。
:::

## この記事で分かること

「27BクラスのモデルがiPhoneで動く」というニュースを見て、いざ試そうとHuggingFaceを開くと、こんな壁にぶつかります。

- `Bonsai-27B` と `Ternary-Bonsai-27B` の**2系統**があって、どっちを使えばいいのか分からない
- さらに `-gguf` `-mlx-1bit` `-mlx-2bit` `-AWQ-4bit` と派生が多く、**どれが自分のデバイス向けか**判断できない
- 「3.9GB」「5.9GB」「7.17GB」とサイズの表記がソースごとに違って**混乱する**

この記事は、PrismMLが2026年7月14日に公開した **Bonsai 27B** ファミリーについて、**「命名の軸」と「バリアントの選び方」を最初に整理**します。そのうえで llama.cpp / MLX / iPhone それぞれでの導入手順、メモリ設計、ベンチマークの読み方までを一気通貫でまとめます。

:::message
**対象読者**: ローカルLLMをMac・iPhone・NVIDIA GPUで動かしたい中級者。量子化の細かい理論よりも「結局どれを入れて、どう動かすか」を知りたい人。
:::

---

## 「Bonsai 27B」は2つある — まず命名を整理しよう

最初につまずくのがここです。**`Bonsai-27B` と `Ternary-Bonsai-27B` はサイズ違いでもバージョン違いでもなく、「重みの量子化方式」の違い**を指します。

| 系列 | 重みの表現 | effective bits/weight | 理論サイズ | 性能維持率（FP16比） | 立ち位置 |
|------|-----------|----------------------|-----------|----------------------|----------|
| **Ternary-Bonsai-27B** | 三値 `{-1, 0, +1}` + 128重みごとにFP16スケール共有 | 約1.71 bit | 5.9GB | **94.6%** | 精度重視・ラップトップ向け |
| **Bonsai-27B**（=1-bit版） | 二値 `{-1, +1}` + 同グループ単位スケール | 約1.125 bit | 3.9GB | **89.5%** | 軽さ重視・スマホ向け |

出典: [PrismML公式](https://prismml.com/news/bonsai-27b) / [MarkTechPost](https://www.marktechpost.com/2026/07/14/prismml-releases-bonsai-27b-1-bit-and-ternary-builds-of-qwen3-6-27b-that-run-on-laptops-and-phones/)

つまり覚えるべきは1点だけです。

> **`Ternary-`が付く＝三値量子化＝精度優先（少し重い）。付かない`Bonsai-27B`＝1-bit＝最軽量（少し精度が落ちる）。**

### なぜ「Bonsai（盆栽）」なのか

どちらも元は **Qwen3.6-27B**（27B級パラメータのマルチモーダルモデル）です。これを新規に学習し直したのではなく、**後量子化（post-training quantization）で極限まで小さくした派生**です。大きな木（27B）を鉢に収まるサイズへ剪定する、という比喩が名前の由来です。

:::message alert
**サイズ表記の混乱に注意**: 「5.9GB / 3.9GB」は**理論上のfootprint**です。実際にHuggingFaceで配布されているファイルは、Ternary gguf が約 **7.17GB**、mlx-1bit のLM部が **3.9GB**（on-diskパックは約5.13GB）と、フォーマットによって差があります。ダウンロード前に必ずモデルカードの実ファイルサイズを確認してください。
:::

:::message
一部の公式ページのみ Ternary を「1.58-bit」と表記していますが、他の全ソースは「1.71-bit」です。1.58は三値の情報理論値（log₂3 ≈ 1.585）で、実際のデプロイ実効値は1.71〜2.125です。本記事では実効値の **1.71 bit** を採用します（※2026年7月時点）。
:::

---

## 前提知識：なぜ超低ビット量子化が必要か

27Bのモデルは、16-bit精度（FP16）だと **約54GB** のメモリを食います。4-bitに量子化しても **約18GB** で、これはハイエンドGPUでも厳しく、スマホでは論外です。

Bonsai 27Bが狙ったのは、この壁を「重み1つあたり1〜2bit」まで削り込むことです。

- **1-bit版**: 3.9GB → iPhone 17 Proのアプリ利用可能メモリ枠（約6GB）に**KVキャッシュやactivationを含めても収まる、初の27B級モデル**
- **Ternary版**: 5.9GB → ラップトップ（統合メモリ潤沢なMac等）で精度を保ちつつ動く

素朴に「2-bitに潰す」だけでは、平均スコアは保てても**難しいタスク（数学・コーディング）で選択的に崩壊**します。Bonsaiはこの崩壊を避ける三値/1-bit設計を主張しており、そこが「ただの小型量子化モデル」との差別化点です（詳細は後述のベンチマーク節）。

---

## セットアップと基本の使い方

### 導入方法は3経路

| 経路 | 対象 | 使うフォーマット |
|------|------|-----------------|
| **llama.cpp（fork）** | NVIDIA GPU / Linux / Metal | gguf |
| **MLX** | Apple Silicon（Mac / iPhone / iPad） | mlx |
| **Bonsai-demo** | まず動かしたい人（統合スクリプト） | 自動選択 |

:::message alert
llama.cppは**PrismML専用fork**を使います。本家 llama.cpp での動作可否は未確認です（三値/1-bitの独自量子化フォーマットに対応が必要なため、fork前提で進めてください）。
:::

### 経路1: llama.cpp（gguf）

```bash
# モデルのダウンロード
hf download prism-ml/Ternary-Bonsai-27B-gguf Ternary-Bonsai-27B-Q2_0.gguf --local-dir .

# 専用forkをビルド（CUDA）
git clone https://github.com/PrismML-Eng/llama.cpp
cd llama.cpp && cmake -B build -DGGML_CUDA=ON && cmake --build build -j
# macOS / Metal の場合は -DGGML_CUDA=ON を外す

# 実行
./build/bin/llama-cli -m Ternary-Bonsai-27B-Q2_0.gguf -p "量子コンピュータを説明して" \
  -n 256 --temp 0.7 --top-p 0.95 --top-k 20 -ngl 99

# OpenAI互換サーバとして起動
./build/bin/llama-server -m Ternary-Bonsai-27B-Q2_0.gguf --host 0.0.0.0 --port 8080 -ngl 99
```

推奨サンプリングは **temp 0.7 / top-p 0.95 / top-k 20**（[gguf model card](https://huggingface.co/prism-ml/Ternary-Bonsai-27B-gguf)）。

### 経路2: MLX（Apple Silicon）

```bash
pip install --upgrade mlx-lm

# 対話モード
mlx_lm.chat --model "prism-ml/Bonsai-27B-mlx-1bit"

# OpenAI互換サーバ
mlx_lm.server --model "prism-ml/Bonsai-27B-mlx-1bit"
```

Pythonから使う場合:

```python
from mlx_lm import load, generate

model, tokenizer = load("prism-ml/Bonsai-27B-mlx-1bit")
messages = [{"role": "user", "content": "アインシュタインについての物語を書いて"}]
prompt = tokenizer.apply_chat_template(messages, add_generation_prompt=True)
text = generate(model, tokenizer, prompt=prompt, verbose=True)
```

### 経路3: Bonsai-demo（最短で動かす）

とりあえず動かしたいなら、公式の統合デモが一番速いです。

```bash
git clone https://github.com/PrismML-Eng/Bonsai-demo.git
cd Bonsai-demo
./setup.sh                          # 依存導入・モデルDL・バイナリ取得・MLXビルド・Open WebUI

./scripts/start_llama_server.sh     # Chat UI → http://localhost:8080

# 単発推論
./scripts/run_llama.sh -p "フランスの首都は?"

# モデルサイズを変えて実行
BONSAI_MODEL=4B ./scripts/run_llama.sh -p "盆栽についての俳句を詠んで"

# MLX経由
source .venv/bin/activate && ./scripts/run_mlx.sh -p "Your prompt"
```

Windowsは `setup.ps1` / `start_llama_server.ps1` を使います。依存は Python 3.10+, uv, cmake, ninja, huggingface-cli（任意でCUDA toolkit / Vulkan SDK）です（[Bonsai-demo README](https://github.com/PrismML-Eng/Bonsai-demo)）。

:::message
27BリポジトリのダウンロードにはHFのreadトークン（環境変数 `BONSAI_TOKEN`）が暫定的に必要な場合があります。403で落ちたらトークンを設定してください。
:::

---

## 5つのバリアント選択パターン — デバイス別チートシート

Bonsai 27Bで最も迷うのが「結局どれを入れるか」です。デバイスと目的から逆引きできるよう、5パターンに整理しました。

### パターン1: iPhoneで動かしたい → `Bonsai-27B-mlx-1bit` 一択

iPhone 17 Pro / Pro Max（RAM 12GB、アプリ利用枠約6GB）で唯一メモリに収まるのが **1-bitのMLX版**です。

- 手軽な経路: iOSアプリ **「Locally AI」** でBonsai 27Bを選択（複数メディアが紹介、[9to5Mac](https://9to5mac.com/2026/07/14/prismml-releases-bonsai-27b-claiming-first-major-ai-model-of-its-size-fit-for-iphone/)）
- 自前ビルド: PrismMLの **mlx-swift fork** で mlx-1bit をオンデバイス実行

:::message alert
「**Bonsai Studio by PrismML**」というApp Storeアプリは**画像生成アプリ**であり、27B LLMを動かすアプリではありません。名前が紛らわしいので混同しないでください。
:::

### パターン2: Mac（統合メモリ潤沢）で精度優先 → `Ternary-Bonsai-27B-mlx-2bit`

M5 Pro / Max クラスなら三値版が余裕で動きます。精度維持率94.6%を活かせます。

### パターン3: NVIDIA GPU / Linux → `Ternary-Bonsai-27B-gguf`

CUDAビルドのllama.cpp forkで動かす王道構成。RTX 5090で三値134 tok/s（後述）。

### パターン4: GPUサーバ・vLLM系 → `*-AWQ-4bit`

`prism-ml/Ternary-Bonsai-27B-AWQ-4bit` / `Bonsai-27B-AWQ-4bit` はサーバ推論向け。低ビットにこだわらずスループットを取りたい場合。

### パターン5: 再量子化・研究用途 → `*-unpacked`

`*-unpacked` は展開版で、自分で再量子化したり内部を調べたい研究者向けです。

:::message
同ファミリーには 27B以外に **8B / 4B / 1.7B / Bonsai-Image-4B** も存在し、各サイズに 1-bit・ternary があります（[公式docs](https://docs.prismml.com/get-started/introduction)）。まず軽く試すなら 4B や 8B から入るのも手です。
:::

---

## 公式ベンチマークから読むベストプラクティス

PrismMLは15ベンチマークスイート（6ドメイン）でFP16ベースラインとの対比を公開しています。ここを読むと「どのバリアントをどこまで信頼していいか」が見えます。

> Ternaryは FP16 の **94.6%**、1-bitは **89.5%** を維持する。
>
> — [MarkTechPost](https://www.marktechpost.com/2026/07/14/prismml-releases-bonsai-27b-1-bit-and-ternary-builds-of-qwen3-6-27b-that-run-on-laptops-and-phones/)

### ドメイン別スコア（FP16基準との対比）

| ドメイン | Ternary | 1-bit | FP16基準 |
|----------|---------|-------|----------|
| Math | 93.40 | 91.66 | 95.33 |
| Coding | 85.96 | 81.88 | 88.74 |
| Knowledge/reasoning | 76.96 | 73.39 | 83.15 |
| Agentic/tool calling | 74.01 | 66.03 | 80.00 |
| Instruction following | 71.77 | 65.74 | 78.47 |
| Vision | 65.19 | 59.57 | 72.61 |

### 推奨1: 精度が要るタスクは Ternary、軽さ最優先だけ 1-bit

上表の通り、**1-bitは Agentic/tool calling で 66.03（FP16=80）と落差が大きい**です。ツール呼び出しやエージェント用途で使うなら、迷わずTernaryを選んでください。1-bitは「スマホで動くこと自体に価値がある」用途に限定するのが安全です。

### 推奨2: 「平均スコア」に騙されない

素朴な2-bit量子化（`IQ2_XXS`など）は、MMLU-Reduxのような知識ベンチでは88.93と高いままなのに、**AIME26=57.5 / LiveCodeBench=56.4 と難タスクで崩壊**します。Bonsaiの三値/1-bitはこの選択的崩壊を避ける設計が売りです。量子化モデルを評価するときは、平均ではなく**難しいベンチ（数学・コーディング）を見る**のが鉄則です。

### 推奨3: マルチモーダルも使える

vision tower（0.46B）を **4-bit（HQQ）** で同梱しており、画像入力に対応します。demoのチャットUIに画像をアップロードすれば自動でロードされます。コンテキストは最大262Kです。

---

## やりがちなアンチパターン7選

### 1. iPhoneに mlx-2bit（7.2GB）を入れようとする

:::message alert
iPhoneのアプリメモリ枠（約6GB）を超えるため**必ず失敗**します。iPhoneは **mlx-1bit のみ**。ここが最頻出のハマりどころです。
:::

### 2. 本家 llama.cpp で gguf を動かそうとする

三値/1-bitの独自フォーマットに未対応の可能性が高く、**PrismML fork必須**です。本家でビルドして「読み込めない」と悩むケースが多発します。

### 3. 長コンテキストで KVキャッシュ圧縮を使わない

100Kトークンを扱うと、Ternaryでもピーク**14.7GB級**まで膨らみます。`BONSAI_KV4=1`（4-bit KVキャッシュ）を付けるだけで大幅に削減できます（後述）。

### 4. Agentic用途に 1-bit を選ぶ

ベンチ通り1-bitはツール呼び出しが弱いです。精度が要る用途で「軽いから」と1-bitを選ぶと、エージェントが壊れます。

### 5. 「5.9GB / 3.9GB」を実ファイルサイズだと思い込む

理論footprintと実配布ファイルは別物です。ディスク・帯域の見積もりは**モデルカードの実数**（gguf 7.17GB等）で行ってください。

### 6. 「Bonsai Studio」アプリをLLM実行環境だと思う

前述の通り画像生成アプリです。LLM実行は「Locally AI」や自前MLXビルドを使います。

### 7. Ollamaで動くと断定して手順を探し回る

:::message alert
**Ollama対応は報道ベースで、公式手順は未確認**です。公式ドキュメントが明記するのは llama.cpp / MLX / OpenAI互換サーバ / Open WebUI のみ。Ollamaで動かすにはggufを自前でModelfile化する必要がある可能性があり、公式にサポートされた `ollama run` コマンドは現時点で存在しません（※2026年7月時点）。
:::

---

## メモリ設計の最適値 — コンテキスト長別

モデル本体のサイズだけでなく、**コンテキスト長に応じたKVキャッシュ**がメモリを圧迫します。

### Ternary-Bonsai-27B（footprint ~7.2GB）

| コンテキスト | ピークメモリ |
|-------------|-------------|
| 4K | 8.4GB |
| 10K | 8.7GB |
| 100K | 14.7GB |
| 262K + 4-bit KV | 約12.8GB |

### Bonsai-27B 1-bit（footprint ~3.9GB）

| コンテキスト | ピークメモリ |
|-------------|-------------|
| 4K | 5.2GB |
| 100K | 11.6〜12.2GB |

:::message
`BONSAI_KV4=1`（4-bit KVキャッシュ）を有効にすると、100Kコンテキストで Ternary が 13.7 → **約9.2GiB** まで下がります（demo実測値）。長コンテキストを扱うなら常時付けておくのが実用上のデフォルトです。モデルカードとdemoで数値に数GBの幅があるため、上表はモデルカード値を主としています（※2026年7月時点）。
:::

### 推論速度（tok/s）

| デバイス | 1-bit | Ternary |
|----------|-------|---------|
| NVIDIA RTX 5090 | 163 | 134 |
| Apple M5 Max | 87 | 58 |
| Apple M5 Pro（laptop） | 約44 | 約26 |
| iPhone 17 Pro Max | 約11 | （非対応） |

iPhoneでは「電池1%あたり約672トークン」、16-bit比で**4〜5倍のエネルギー効率**という数値も公開されています（[公式](https://prismml.com/news/bonsai-27b)）。

### 高速化オプション

`BONSAI_SPECULATIVE=1`（DSpark drafterを併用した投機デコード）で、CUDA環境のdecodeが約1.8〜2倍高速化します。

---

## 関連モデル・フォーマット比較

| 選択肢 | 強み | 弱み | 向いている人 |
|--------|------|------|-------------|
| **Ternary-Bonsai-27B** | 精度94.6%維持・エージェント可 | 5.9GB〜と1-bitより重い | Mac/GPUで実用したい人 |
| **Bonsai-27B（1-bit）** | 3.9GB・iPhoneで動く唯一の27B | Agentic/vision弱め | スマホでオンデバイス推論したい人 |
| **通常の4-bit量子化（27B）** | ツール成熟・本家対応 | 約18GBでスマホ不可 | GPUメモリに余裕がある人 |
| **AWQ-4bit版** | vLLMでスループット高 | 低ビットの軽さは無い | GPUサーバ運用者 |
| **8B / 4B Bonsai** | さらに軽く速い | 27Bより賢さは落ちる | まず試したい・低スペック環境 |

---

## 実践チェックリスト

### モデル選定時
- [ ] デバイスを確認した（iPhone → mlx-1bit 一択）
- [ ] 用途を確認した（エージェント/ツール呼び出し → Ternary）
- [ ] ダウンロード前にモデルカードの**実ファイルサイズ**を確認した
- [ ] gguf なら PrismML fork を使う前提を理解した

### セットアップ時
- [ ] llama.cpp は `github.com/PrismML-Eng/llama.cpp`（fork）をクローンした
- [ ] MLXは `pip install --upgrade mlx-lm` を実行した
- [ ] 27BリポDLで403が出たら `BONSAI_TOKEN`（HFトークン）を設定した

### 運用時
- [ ] 長コンテキストを扱うなら `BONSAI_KV4=1` を付けた
- [ ] サンプリングは temp 0.7 / top-p 0.95 / top-k 20 を基準にした
- [ ] エージェント用途で1-bitを使っていないか見直した

---

## まとめ

- **要点1**: `Ternary-Bonsai-27B`＝三値・精度優先（94.6%維持）、`Bonsai-27B`＝1-bit・最軽量（89.5%）。命名の軸は「量子化方式」。
- **要点2**: iPhoneで動くのは **mlx-1bit のみ**。mlx-2bitはメモリ枠超過で入らない。
- **要点3**: エージェント/ツール呼び出しなど精度が要る用途は必ず **Ternary**。1-bitは「軽さが正義」の用途に限定。
- **要点4**: 「5.9GB/3.9GB」は理論値、実ファイルは 7.17GB 等。長コンテキストは `BONSAI_KV4=1` でメモリを抑える。
- **要点5**: Ollama対応は公式未確認。導入は llama.cpp（fork）/ MLX / Bonsai-demo が正道。

27B級がスマホのポケットに入る時代が、2026年7月に現実になりました。バリアントの多さに戸惑ったら、この記事の「デバイス別チートシート」に戻ってきてください。

---

## 参考リンク

- [PrismML公式 — Bonsai 27B発表](https://prismml.com/news/bonsai-27b)
- [PrismML docs — Introduction](https://docs.prismml.com/get-started/introduction)
- [HuggingFace — prism-ml org](https://huggingface.co/prism-ml)
- [Ternary-Bonsai-27B-gguf](https://huggingface.co/prism-ml/Ternary-Bonsai-27B-gguf) / [Bonsai-27B-mlx-1bit](https://huggingface.co/prism-ml/Bonsai-27B-mlx-1bit)
- [GitHub — Bonsai-demo](https://github.com/PrismML-Eng/Bonsai-demo)
- [MarkTechPost 解説](https://www.marktechpost.com/2026/07/14/prismml-releases-bonsai-27b-1-bit-and-ternary-builds-of-qwen3-6-27b-that-run-on-laptops-and-phones/) / [9to5Mac](https://9to5mac.com/2026/07/14/prismml-releases-bonsai-27b-claiming-first-major-ai-model-of-its-size-fit-for-iphone/)

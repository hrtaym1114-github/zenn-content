---
title: "LFM2.5-Audio-1.5B×llama.cppを整理する — ASRは動くがTTSが本家に無い理由"
emoji: "🔊"
type: "tech"
topics: ["LLM", "llamacpp", "音声認識", "ローカルLLM", "LiquidAI"]
published: true
---

<!--
## メタデータ（Obsidian管理用・Zenn側には公開されない）
- **ステータス**: 下書き
- **スラッグ**: lfm25-audio-llamacpp-transcription-guide
- **ファクトチェック**: 済（2026-09-11 手動 / GitHub API・HuggingFaceで一次情報を直接検証。PR#18641/Discussion#16384の日付はcurl+GitHub APIで実証済み）
- **鮮度レビュー**: 済（2026-09-11 as-of 2026-09-11 / Outdated: 0件）
- **網羅性レビュー**: 済（2026-09-11 セルフ / Missing: 0件）
- **尋問・引き算**: 済（2026-09-11 / 設計理由: Discussion#16384・PR#18641で一次情報付き記載 / 削減: 旧7490字→新6827字 -8.9% / 体験証拠: あり（実機2回実行・タイミング実測））
- **Spiral適用**: 未（リード・所感・まとめへの適用は未実施。公開判断前に検討）
-->

## この記事で分かること

「llama.cppが音声モデルに対応した」というポストを見て「もう `llama-server` で動くのか」と思ったなら、それは半分だけ正解です。

- **LFM2.5-Audio-1.5B** は音声認識（ASR）なら実機で動きます。ただし**本家 llama.cpp ではなく、Liquid AI が配布する専用ビルド**が必要です
- テキスト読み上げ（TTS）は本家 llama.cpp にまだ統合されていません。理由は「対応が遅れている」ではなく、**llama.cpp側に音声出力の統一的な抽象化層が無い**という構造的な問題です
- 名前が似たモデルが3つあり（LFM2-Audio / LFM2.5-Audio-1.5B / LFM2.5-Audio-1.5B-JP）、どれが今回のCLIで動くかは公式ドキュメントだけでは判別しにくい

この記事を読むと、①3つのモデルを迷わず区別でき、②TTSだけ止まっている技術的な理由が分かり、③実際にMac(Apple M5)で動かした処理速度と文字起こしの精度が分かります。

:::message
**対象読者**: ローカルLLM・音声認識に関心がある中級エンジニア。llama.cppの基本（GGUF・量子化）は知っている前提
:::

---

## 「LFM2-Audio」系の名前は3つある — まず整理しよう

検索して最初にぶつかる壁がこれです。似た名前のモデルが3世代あり、**動かし方も対応状況もそれぞれ違います**。

| モデル | リリース系統 | llama.cpp対応 | 必要なランタイム |
|---|---|---|---|
| LFM2-Audio-1.5B（無印・旧世代） | 2025年 | ASRのみ実験的にマージ済み | 本家 llama.cpp（ASR限定） |
| **LFM2.5-Audio-1.5B（本記事）** | LFM2.5世代・英語 | 本家未統合。**Liquid配布の専用ビルドが必要** | `llama-liquid-audio-cli` / `-server`（Liquid独自） |
| LFM2.5-Audio-1.5B-JP | LFM2.5世代・日本語特化 | llama.cppのcookbook CLIとは**別物** | Pythonパッケージ `liquid-audio` |

:::message alert
LFM2.5-Audio-1.5B-JPは「JPの文字が付いているだけで同じCLIで動く」ように見えますが、モデルカードにllama.cppやこのCLIへの言及は一切なく、別パッケージ`liquid-audio`が前提です。今回検証したcookbookのCLIでは動きません。
:::

「llama.cpp対応」という一言は、上の3行のどれを指しているか明示されないまま流通しています。

---

## なぜASRだけ動いてTTSが無いのか — 設計経緯

「何が違うか」は公式ドキュメントで分かります。「なぜそうなったか」は GitHub の Discussion と PR にしかありません。

議論は [Discussion #16384](https://github.com/ggml-org/llama.cpp/discussions/16384)（2025年10月開始）に遡ります。

- **ASR（音声→テキスト）**: 音声入力を multi-modal projector（mtmd）で埋め込みに変換し、既存のテキスト生成パスに渡すだけで済む。既存アーキテクチャの延長線上のため実験的マージまで到達した
- **TTS（テキスト→音声）**: 出力に音声コーデック生成が必要。LFM2.5系は独自の軽量デトークナイザ、他モデルはSNACやDACなど**コーデックがモデルごとに違う**。llama.cpp/llama-serverには音声出力の統一抽象化層が無く、`mtmd` APIとサーバ本体の改修が要る

これを引き継ぐ [PR #18641](https://github.com/ggml-org/llama.cpp/pull/18641)（`[Do Not Merge] model: LFM2.5-Audio-1.5B`）は、GitHub API確認で作成日**2026-01-06**・**Draft**・直近更新**2026-09-01**（約8ヶ月ドラフトのまま）。本家`llama-server`改修ではなく`llama-liquid-audio-cli`/`-server`という**別バイナリ**で切り出す方針です。周辺PR（#18607、#18601、#18645など）は段階的にマージが進みますが、音声出力の統合自体はまだです。

Liquid AIは「本家マージを待つ」代わりに**専用ビルドを先に配布**しました。cookbookのCLIは実行時にプラットフォームを検出し、4本のGGUF（メインモデル・`mmproj`・`vocoder`・`tokenizer`）と対応バイナリを自動DLします。

:::message
この経緯を知っていると、「llama.cppが音声対応した」という投稿を見た時に、それがASR止まりか、TTSまで含むかを一次情報で見分けられます。
:::

---

## 前提知識：なぜローカルで音声処理をしたいのか

クラウドAPIに送らず端末内で処理する動機は、レイテンシ（往復通信が無い）とプライバシー（音声データが外に出ない）の2点です。llama.cppはC++実装の軽量推論エンジンで、PyTorchやtransformersを介さず動くため、スマートフォンや車載機器のような制約環境でも動作します。今回のCLIも「入力音声も出力テキストもどこにも送信しない」とREADMEに明記されています。

---

## セットアップと使い方

### インストールから実行まで

必要なのは`uv`だけです。以下を順に実行します。

```bash
git clone https://github.com/Liquid4All/cookbook.git
cd cookbook/examples/audio-transcription-cli

# uv未インストールの場合
curl -LsSf https://astral.sh/uv/install.sh | sh

# サンプル音声を取得
uv run download_audio_samples.py

# 転写を実行（モデルは初回実行時に自動ダウンロード）
uv run transcribe --audio './audio-samples/barackobamafederalplaza.mp3' --play-audio
```

量子化はサイズと速度のトレードオフで選べます。

| 量子化 | ディスク容量 |
|---|---|
| `Q4_0` | 約1.1GB |
| `Q8_0`（デフォルト） | 約1.8GB |
| `F16` | 約3.3GB |

対応プラットフォームは `android-arm64` / `macos-arm64` / `ubuntu-arm64` / `ubuntu-x64` の4つのみです。Windows・Intel Macは非対応です（2026-09時点）。

### 実行結果（実機検証）

:::message
本記事のコマンドは MacBook Pro（Apple M5 / 16GB）/ macOS 26.6.2 / uv 0.11.7 で実行して確認しています（2026-09-11時点）。
:::

初回実行時は21ファイル（GGUF重み4本＋プラットフォーム別バイナリ）のダウンロードが走り、実測で約3分41秒かかりました。ダウンロード直後、以下の警告が出ます。

```
⚠️  Model warm-up failed: [Errno 2] No such file or directory: '.../llama-liquid-audio-cli' (transcription will still work)
```

これはウォームアップ処理がバイナリの展開完了より先に走ってしまうタイミングの問題で、実際には転写は問題なく動きます（メッセージにもその旨明記されています）。

2回目以降（モデルキャッシュ済み）は次の速度でした。

```
📊 Duration: 12.9s | Chunk size: 2.0s
✅ Complete transcription (12.7s)
```

12.9秒の音声を12.7秒で完了（CPU使用率35%）。**ほぼリアルタイム（約0.98倍速）**でした。

文字起こし結果は次の通りでした（オバマ元大統領のスピーチ音源）。

```
I don't oppose war, In all circumstances, and when I look
When I look out over this crowd today, Today, I know there is no short.
No shortage of patriots. Or patriotism. What I do oppose. Pose is a dumb war. More.
```

正解のスピーチは "I don't oppose all wars... What I oppose is a dumb war" です。「look」「Today」がチャンク境界で重複し、「oppose」が「oppose.」「Pose is」に分断されました。README記載の既知の制約（2秒チャンクをまたぐ文が不完全になる）と一致し、2回実行して同じ壊れ方が再現しました。

---

## 3つの使い方パターン

`examples.sh` には、同じバイナリで3用途を切り替える例があります。

**1. ASR（音声→テキスト、今回のCLIの中身）**
```bash
./llama-liquid-audio-cli \
    -m $CKPT/LFM2.5-Audio-1.5B-Q8_0.gguf \
    -mm $CKPT/mmproj-LFM2.5-Audio-1.5B-Q8_0.gguf \
    -mv $CKPT/vocoder-LFM2.5-Audio-1.5B-Q8_0.gguf \
    --tts-speaker-file $CKPT/tokenizer-LFM2.5-Audio-1.5B-Q8_0.gguf \
    -sys "Perform ASR." --audio $INPUT_WAV
```

**2. TTS（テキスト→音声、デフォルト声）**
```bash
./llama-liquid-audio-cli \
    -m $CKPT/LFM2.5-Audio-1.5B-Q8_0.gguf \
    -mm $CKPT/mmproj-LFM2.5-Audio-1.5B-Q8_0.gguf \
    -mv $CKPT/vocoder-LFM2.5-Audio-1.5B-Q8_0.gguf \
    --tts-speaker-file $CKPT/tokenizer-LFM2.5-Audio-1.5B-Q8_0.gguf \
    -sys "Perform TTS. Use the US male voice." \
    -p "My name is Pau Labarta Bajo and I love AI" --output $OUTPUT_WAV
```

**3. TTS（声を選ぶ）**

対応する声は `US male` / `UK male` / `US female` / `UK female` の4種類。`-sys` の指示文を変えるだけで切り替わります。

---

## 公式が明言するベストプラクティス

> Audio support in llama.cpp is still quite experimental, and not fully integrated on the main branch of the llama.cpp project. Because of this, the Liquid AI team has released specialized llama.cpp builds that support the LFM2.5-Audio-1.5B model.
>
> — [Liquid4All/cookbook README](https://github.com/Liquid4All/cookbook/blob/main/examples/audio-transcription-cli/README.md)

Liquid AI自身が「実験的で本家未統合」と明記しています。READMEはさらに、転写精度を上げる方法として「LFM2.5-Audio-1.5Bで音声→テキスト抽出し、テキスト整形専用の小型モデル `LFM2.5-350M` で文章を整える2段構成」を挙げています。今回確認したチャンク境界の乱れは、この2段構成で緩和できる可能性があります（未検証）。

---

## やりがちなアンチパターン7選

1. **Homebrewの`llama-server`で試す** — 動きません。Liquid配布の専用バイナリ`llama-liquid-audio-cli`が必須です
2. **LFM2-Audio（無印・旧世代）の情報をLFM2.5-Audio用に流用する** — ASRの対応状況が世代で異なります
3. **LFM2.5-Audio-1.5B-JPを今回のCLIで動かそうとする** — 別パッケージ`liquid-audio`が必要で動きません
4. **`Model warm-up failed`をエラーと誤認して中断する** — 転写自体は正常に動作します
5. **文字起こし結果を整形なしで使う** — チャンク境界の重複・分断はREADMEも認める既知の制約です
6. **Windows・Intel Macで動かそうとする** — 対応は`android-arm64`/`macos-arm64`/`ubuntu-arm64`/`ubuntu-x64`のみです
7. **用途を考えずF16量子化を選ぶ** — 精度は上がるが3.3GBと最大サイズ。エッジ用途はQ4_0/Q8_0から検討すべきです

---

## 実測データ：処理速度と量子化のトレードオフ

| 条件 | 実測値 | 補足 |
|---|---|---|
| 初回実行（モデルDL含む） | 4分07秒 | 21ファイルDL＋展開込み |
| 2回目実行（キャッシュ済み） | 12.7秒 / 12.9秒音声 | ほぼリアルタイム（M5・CPU35%） |
| Q8_0（デフォルト）ディスク容量 | 約1.8GB | 精度と速度のバランス型 |
| 配布バイナリのCPUカーネル | m1 / m2_m3 / m4 の3種 | **M5専用カーネルは未同梱**（2026-09-11時点。動作はするが最適化対象外の可能性） |

---

## 関連ツール比較

| ツール | 強み | 弱み | 向いている人 |
|---|---|---|---|
| LFM2.5-Audio-1.5B（本記事） | ASR/TTS一体・1.5Bで軽量・エッジ向け | 本家未統合・チャンク境界が荒い | ローカル完結の音声対話を試したい人 |
| Whisper large-v3 | 精度が高く実績豊富 | 大きく低速（別記事実測: 11秒級音声で11秒超） | 精度優先・GPU環境がある人 |
| Moonshine v2 | 低レイテンシ特化 | 英語中心 | リアルタイム字幕など速度優先用途 |
| LFM2-Audio（無印・旧世代） | 本家llama.cppにASRが実験的マージ済み | TTSなし・LFM2.5より精度が低い | 本家ビルドだけで完結させたい人 |

Whisper・Moonshineの実測比較は別記事（[Moonshine Voice vs Whisper](https://zenn.dev/amu_lab/articles/moonshine-vs-whisper-benchmark-2026)）にまとめています。

---

## 実践チェックリスト

### セットアップ時
- [ ] `uname -m` でarm64であることを確認したか（Intel Macは非対応）
- [ ] `uv`がインストール済みか
- [ ] 対応プラットフォーム（android-arm64/macos-arm64/ubuntu-arm64/ubuntu-x64）に該当するか

### 実行時
- [ ] 初回実行の`Model warm-up failed`警告で慌てて中断していないか
- [ ] 使いたいのがLFM2.5-Audio-1.5B（英語・本記事）かLFM2.5-Audio-1.5B-JP（日本語・別パッケージ）かを確認したか
- [ ] 量子化（Q4_0/Q8_0/F16）を用途に応じて選んだか

### 出力の扱い
- [ ] チャンク境界の重複・分断を前提に、後処理（テキスト整形）を組んでいるか

---

## まとめ

- LFM2-Audio・LFM2.5-Audio-1.5B・LFM2.5-Audio-1.5B-JPは名前が似ているが対応状況もランタイムも別物
- ASRだけ動くのは後回しではなく、TTSに音声コーデックの統一抽象化層が無いという構造的な壁があるから（[#16384](https://github.com/ggml-org/llama.cpp/discussions/16384)・[#18641](https://github.com/ggml-org/llama.cpp/pull/18641)）
- 動かすには本家llama.cppではなくLiquid配布の専用ビルドが必要
- Apple M5・16GBの実測はキャッシュ済みでほぼリアルタイム。チャンク境界の精度は荒く後処理前提
- 「llama.cppが音声対応した」を見たら、ASR/TTSどちらの話かをまず確認する

---

## 参考リンク

- [Liquid4All/cookbook — audio-transcription-cli](https://github.com/Liquid4All/cookbook/tree/main/examples/audio-transcription-cli)
- [LiquidAI/LFM2.5-Audio-1.5B（Hugging Face）](https://huggingface.co/LiquidAI/LFM2.5-Audio-1.5B)
- [LiquidAI/LFM2.5-Audio-1.5B-JP（Hugging Face）](https://huggingface.co/LiquidAI/LFM2.5-Audio-1.5B-JP)
- [Discussion #16384 — Support for LFM2-Audio-1.5B](https://github.com/ggml-org/llama.cpp/discussions/16384)
- [PR #18641 — [Do Not Merge] model: LFM2.5-Audio-1.5B](https://github.com/ggml-org/llama.cpp/pull/18641)
- 元ネタ: [@helloiamleonieのポスト](https://x.com/helloiamleonie/status/2096980561046724649)

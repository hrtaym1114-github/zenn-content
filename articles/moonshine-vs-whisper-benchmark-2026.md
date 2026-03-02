---
title: "【実測検証】Moonshine Voice vs Whisper — RTX 2000 Adaで全モデル比較ベンチマーク"
emoji: "🎤"
type: "tech"
topics: ["whisper", "moonshine", "音声認識", "ベンチマーク", "Python"]
published: false
---

## この記事で分かること

- Moonshine Voice v2（2026年2月リリース）の実力を **RTX 2000 Ada 16GB** で実測
- Whisper / Faster-Whisper / Moonshine の **11モデルを横断比較**
- レイテンシ・精度（WER）・メモリ使用量の3軸で評価
- **再現可能なベンチマークコード**付き（uv + Python）
- 「どのモデルを選ぶべきか」の判断フローチャート

## Moonshine Voice v2 とは

2026年2月にUseful Sensors社（共同創業者: Pete Warden = 元Google TensorFlow Lite開発者）がリリースしたオープンソース音声認識ツールキット。

**公式ベンチマーク（MacBook Pro）:**

| 指標 | Moonshine Medium | Whisper Large v3 |
|------|-----------------|------------------|
| レイテンシ | 107ms | 11,286ms |
| WER | 6.65% | 7.44% |
| モデルサイズ | 245MB | 3.1GB |

この「100倍速い」は本当なのか？自分の環境で検証してみた。

## 検証環境

| 項目 | スペック |
|------|---------|
| OS | Windows 10 (22631) |
| CPU | Intel Core i7-13700 |
| GPU | NVIDIA RTX 2000 Ada (VRAM 16GB) |
| RAM | 32GB |
| Python | 3.11.6 |
| PyTorch | 2.5.1+cu121 |

:::message
Moonshine Voice はCPU専用（C++コアエンジン）。Whisperは **CUDA GPU** で動作。
公平な比較というより「各ツールの最適環境での実力」を測る意図です。
:::

## ベンチマーク手法

### テスト音声

| ファイル | 内容 | 時間 |
|---------|------|------|
| beckett_10s.wav | サミュエル・ベケット引用（6短文） | 10秒 |
| two_cities_44s.wav | ディケンズ「二都物語」冒頭 | 44秒 |

### 比較対象（11モデル）

**Moonshine Voice (CPU):**
- moonshine-base (58MB)
- moonshine-medium-streaming (245MB)

**OpenAI Whisper (GPU/CUDA):**
- whisper-tiny (75MB) / base (142MB) / small (466MB) / large-v3 (3.1GB)

**Faster-Whisper (GPU/CTranslate2):**
- faster-whisper-tiny (40MB) / base (75MB) / small (250MB) / medium (800MB) / large-v3 (1.6GB)

### 計測方法

```python
# 各モデル3回実行の平均値（ウォームアップ1回）
latency = measure_latency(
    runner.transcribe, args=(audio,),
    num_runs=3, warmup_runs=1,
)
```

WER（Word Error Rate）は `jiwer` ライブラリで計算。参照テキストは原文から作成。

## 結果1: レイテンシ比較（44秒音声）

| モデル | デバイス | レイテンシ | RTF | サイズ |
|--------|---------|-----------|-----|--------|
| faster-whisper-tiny | CUDA | **507ms** | 0.011 | 40MB |
| faster-whisper-base | CUDA | 690ms | 0.016 | 75MB |
| faster-whisper-small | CUDA | 978ms | 0.022 | 250MB |
| whisper-tiny | CUDA | 980ms | 0.022 | 75MB |
| whisper-base | CUDA | 1,213ms | 0.027 | 142MB |
| faster-whisper-medium | CUDA | 1,905ms | 0.043 | 800MB |
| whisper-small | CUDA | 2,331ms | 0.053 | 466MB |
| faster-whisper-large-v3 | CUDA | 3,004ms | 0.068 | 1.6GB |
| whisper-large-v3 | CUDA | 5,510ms | 0.124 | 3.1GB |
| moonshine-medium | CPU | 89,512ms | 2.016 | 245MB |
| moonshine-base | CPU | 115,201ms | 2.596 | 58MB |

:::message alert
**重要: Moonshineのレイテンシが大きい理由**
Moonshine Voiceはストリーミング処理を前提とした設計。音声を100msチャンクずつリアルタイムで処理するため、44秒の音声をバッチ処理すると実時間以上かかる（RTF > 1.0）。

公式の「107ms」は**ストリーミングレイテンシ**（最後のチャンクからテキスト出力までの遅延）であり、ファイル全体の処理時間ではない。
:::

### RTF（Real-Time Factor）の読み方

- **RTF < 1.0**: リアルタイムより速い（バッチ処理向き）
- **RTF ≈ 1.0**: リアルタイムと同速（ストリーミング向き）
- **RTF > 1.0**: リアルタイムより遅い

Faster-Whisper-tiny は RTF = 0.011、つまり **リアルタイムの90倍速** でバッチ処理可能。

## 結果2: 精度比較（WER — 44秒音声）

| モデル | WER | 備考 |
|--------|-----|------|
| faster-whisper-large-v3 | **0.00%** | 完全一致 |
| whisper-large-v3 | 0.84% | ほぼ完璧 |
| whisper-tiny | 1.68% | tinyでこの精度は驚異 |
| faster-whisper-tiny | 1.68% | 同上 |
| whisper-small | 2.52% | 安定 |
| faster-whisper-small | 2.52% | 安定 |
| faster-whisper-medium | 3.36% | 良好 |
| whisper-base | 5.88% | 許容範囲 |
| faster-whisper-base | 12.61% | やや劣化 |
| moonshine-medium | 13.45% | ストリーミング音声用 |
| moonshine-base | 13.45% | ストリーミング音声用 |

:::message
**Moonshineの精度について:**
Moonshine Voice v2の公式WER 6.65%はLibriSpeech test-cleanでの計測値。我々のテスト音声（オーディオブック）はLibriSpeechとは異なる録音条件のため、直接比較は参考値。
:::

## 結果3: メモリ使用量

| モデル | モデルサイズ | ロード時RAM増分 |
|--------|------------|----------------|
| faster-whisper-tiny | 40MB | +48MB |
| moonshine-base | 58MB | +605MB |
| faster-whisper-base | 75MB | +24MB |
| whisper-tiny | 75MB | +220MB |
| whisper-base | 142MB | +280MB |
| moonshine-medium | 245MB | +586MB |
| faster-whisper-small | 250MB | +6MB |
| whisper-small | 466MB | +658MB |
| faster-whisper-medium | 800MB | +31MB |
| faster-whisper-large-v3 | 1.6GB | +7MB |
| whisper-large-v3 | 3.1GB | +3,934MB |

Faster-WhisperはCTranslate2の最適化によりRAM使用量が非常に少ない。
Moonshineは統合C++ライブラリのため、モデルサイズに比べてRAM消費が大きめ。

## 設計思想の違い — なぜ数字だけで比較できないのか

この検証で最も重要な発見は、**MoonshineとWhisperは設計思想が根本的に異なる**ということ。

### Whisper: バッチ処理の王者

```
[録音完了] → [30秒ウィンドウで一括処理] → [テキスト出力]
                    ↑ここがGPUで高速
```

- 録音済みファイルの文字起こしに最適
- GPU必須で最大パフォーマンス
- 短い発話でも30秒ウィンドウ分の計算が走る（ただしtinyは非常に高速）

### Moonshine: リアルタイムストリーミングの革命児

```
[マイク入力中] → [100msチャンクずつ逐次処理] → [リアルタイムテキスト出力]
                    ↑ここがCPUで動く
```

- **ストリーミングレイテンシ実測 ≈ 0ms**（音声送信完了時にはテキスト完成済み）
- GPU不要、CPU のみ、インターネット不要
- VAD（音声検出）+ 話者識別 + インテント認識 が統合
- Raspberry Piでも動作

## 使い分けガイド

### Faster-Whisper を選ぶべき場合

- 録音済みファイルの文字起こし
- GPU（CUDA）が使える環境
- バッチ処理の高速性が最優先
- 最高精度が必要（large-v3: WER 0%）

### Moonshine Voice を選ぶべき場合

- マイク入力のリアルタイム文字起こし
- エッジデバイス（Raspberry Pi等）での音声認識
- GPU/インターネット不要の環境
- 音声コマンド（インテント認識）の実装
- プライバシー重視（完全オンデバイス処理）

### コスパ最強の選択肢

| ユースケース | 推奨 | 理由 |
|------------|------|------|
| ファイル文字起こし（GPU有） | faster-whisper-small | 978ms/44s, WER 2.52%, 250MB |
| ファイル文字起こし（高精度） | faster-whisper-large-v3 | WER 0.00%, 3秒/44s |
| リアルタイム音声入力 | moonshine-medium | ストリーミングレイテンシ0ms |
| エッジデバイス | moonshine-base | 58MB, CPU専用 |
| 日本語文字起こし | whisper-large-v3 | 日本語WER最良（Moonshine日本語は非商用） |

## 再現手順

### 1. プロジェクトクローン

```bash
git clone https://github.com/your-repo/moonshine-whisper-benchmark.git
cd moonshine-whisper-benchmark
```

### 2. 環境構築（GPU Windows）

```bash
uv sync
uv pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu121
uv pip install openai-whisper faster-whisper
uv sync --extra moonshine
```

### 3. テスト音声準備

```bash
# Moonshine同梱の音声をコピー
uv run python scripts/download_test_audio.py
# または手動で test_audio/en/ に .wav + .txt を配置
```

### 4. ベンチマーク実行

```bash
# 全モデル
uv run python scripts/run_benchmark.py

# クイックテスト（2回、ウォームアップなし）
uv run python scripts/run_benchmark.py --quick

# 特定モデルのみ
uv run python scripts/run_benchmark.py --models whisper-tiny faster-whisper-tiny
```

### 5. グラフ生成

```bash
uv run python scripts/generate_charts.py --markdown
```

## ライセンスに関する注意

| 項目 | ライセンス |
|------|-----------|
| Moonshine Voice（英語モデル） | MIT |
| Moonshine Voice（日本語等） | Moonshine Community License（非商用） |
| OpenAI Whisper | MIT |
| Faster-Whisper | MIT |

**日本語でMoonshineを商用利用する場合は要注意。** 英語モデルはMIT、多言語モデルは非商用ライセンス。

## まとめ

| 観点 | Whisper / Faster-Whisper | Moonshine Voice |
|------|------------------------|-----------------|
| 処理方式 | バッチ | ストリーミング |
| 最適環境 | GPU (CUDA) | CPU |
| バッチ速度 | 507ms〜5.5s/44s音声 | 89s/44s音声 |
| ストリーミングレイテンシ | N/A | ≈ 0ms |
| 最高WER | 0.00% (large-v3) | 6.65% (公式) |
| 統合機能 | STTのみ | STT + VAD + 話者識別 + インテント |
| エッジ対応 | 困難 | Raspberry Pi OK |
| 日本語 | 商用利用OK | 非商用のみ |

**結論:** 「100倍速い」は**ストリーミングレイテンシ**の話。バッチ処理ではWhisper（特にFaster-Whisper）がGPU活用で圧倒的に高速。しかしMoonshineは「リアルタイム音声アプリ」「エッジデバイス」「統合ツールキット」という独自の領域で唯一無二の存在。

**適材適所で選ぶことが最重要。**

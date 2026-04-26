---
title: "【2026年最新】Apple M5でOllamaがSIGABRTクラッシュする問題を整理 — mlx_lm 代替手段"
emoji: "💥"
type: "tech"
topics: ["Ollama", "MLX", "AppleSilicon", "LLM", "macOS"]
published: true
---

<!--
ファクトチェック: 済（2026-04-26 Genspark Agentic Cross-Check）
レポート: 03_Input/Fact-Check/20260426_zenn-apple-m5-ollama-sigabrt-mlx-lm-guide-2026-factcheck.md
ファクトチェック修正: 済（2026-04-26 高優先度5件すべて反映）
- ✅ Issue #15448 環境記述を「同じmacOS 26.3.x環境（メモリ・バージョン異なる）」に修正
- ✅ Ollamaブログ引用を直接引用ではなく間接記述に変更（「Please make sure...」を併記）
- ✅ TTFT 4倍の出典を Apple機械学習研究ブログ（M4比、Qwen3-14B-MLX-4bit 4.06倍）に修正
- ✅ Ollama 0.19 速度向上を「Ollama 0.18比、Qwen3.5-35B-A3B モデル比較」と前提明記
- ✅ Issue #15748 タイトルに「to initialize Metal」を追加

未対応（中優先度）:
- Contra Collective「15-30%、メモリ10%少」の数値を独立検証
- mlx-vlm 開発者「Prince Canuma 氏」の出典追加
- mlx_lm Qwen3-4B 48.75 tok/s と公式 BENCHMARKS の桁差の考察
-->


## この記事で分かること

新しい M5 Mac を買った瞬間、こんな経験はないだろうか。

```bash
$ ollama run qwen3:1.7b "こんにちは"
Error: 500 Internal Server Error: model failed to load,
this may be due to resource limitations or an internal error
```

メモリは 16GB あるはず。ディスクも空いている。Ollama も最新版。なのに **1.4GB の小型モデルすら動かない**。これが私が 2026 年 4 月 26 日、MacBook Pro M5 16GB（macOS 26.3）で遭遇した現実だった。

調べた結果、これは私だけの問題ではなかった。**Ollama 0.13.x 以降は M5 chip + macOS 26 系で広範に動作不能**になっており、GitHub Issue が9件以上立っている既知の重大バグだった。

この記事では以下を整理する:

- 🚨 **何が起きているのか**: Metal cooperative tensor の bfloat / half 型不一致による SIGABRT
- 🔧 **なぜ起きるのか**: M5 chip = `MTLGPUFamilyApple10` という新 GPU ファミリーへの未対応
- 🛠️ **どう回避するのか**: 5つの実践的選択肢（ダウングレード / mlx_lm / llama.cpp / LM Studio / 様子見）
- 📊 **mlx_lm 経由の M5 16GB 実機ベンチマーク**: Qwen3 1.7B / 4B / 14B の生成速度

:::message
**対象読者**:
- M5 / M5 Pro / M5 Max の Mac でローカル LLM を動かしたい方
- Ollama が突然動かなくなって困っている方
- mlx_lm / mlx-vlm / llama.cpp との違いがいまいち分からない方
:::

---

## Ollama / mlx_lm / mlx-vlm / llama.cpp は何が違うのか — まず整理しよう

M5 でローカル LLM を動かそうとすると、4つのツール名が頻出する。これらの関係が不明瞭なまま検索すると確実に迷子になるので、最初に整理する。

### 4ツールの位置関係

```
┌─────────────────────────────────────────────────────┐
│  ユーザー向けラッパー層                               │
│  ├─ Ollama（CLI / HTTP API・最も人気）                │
│  └─ LM Studio（GUI）                                  │
├─────────────────────────────────────────────────────┤
│  推論エンジン層                                       │
│  ├─ llama.cpp + ggml（C++ / 多プラットフォーム）      │
│  └─ Apple MLX（Apple Silicon専用）                    │
│      ├─ mlx-lm（テキスト LLM 用）                     │
│      └─ mlx-vlm（Vision LLM 用）                      │
└─────────────────────────────────────────────────────┘
```

### 比較表

| ツール | レイヤー | バックエンド | 開発元 | 強み |
|---|---|---|---|---|
| **Ollama** | ラッパー（CLI/API） | llama.cpp + ggml（既定）/ MLX（0.19+, 32GB+のみ） | Ollama, Inc. | DX が最強、`ollama run` の1コマンドで完結 |
| **mlx-lm** | エンジン直接 | Apple MLX | Apple ML研究 | Apple Silicon ネイティブ最適化、メモリ効率最良 |
| **mlx-vlm** | エンジン直接 | Apple MLX | Prince Canuma氏（OSS） | mlx-lm の Vision 版 |
| **llama.cpp** | エンジン | ggml | Georgi Gerganov氏 | ポータビリティ最強、量子化制御細かい |
| **LM Studio** | ラッパー（GUI） | llama.cpp / MLX 両対応 | LM Studio AI | GUI で直感的、モデル管理が楽 |

### 性能の傾向（Apple Silicon 上）

[Contra Collective の比較記事](https://contracollective.com/blog/llama-cpp-vs-mlx-ollama-vllm-apple-silicon-2026)によると、**Apple Silicon 上では MLX が Ollama / llama.cpp より 15-30% 速く、メモリも約 10% 少ない**。ただし 27B 以上の大型モデルではメモリ帯域がサチって差が縮まる。

### 公式: Ollama も MLX 統合へ動いている

2026年3月、[Ollama 公式ブログ](https://ollama.com/blog/mlx)が発表したとおり、Ollama 0.19 以降では **MLX バックエンド（実験的）** が追加された。プリフィル 1.6 倍、生成 2 倍の高速化を謳っている（[MacRumors 報道](https://www.macrumors.com/2026/03/31/ollama-now-runs-faster-apple-silicon-macs/)）。

ただし **MLX バックエンドは 32GB 以上のメモリが必須**。M5 16GB では従来の llama.cpp + ggml バックエンドのまま動く。これが今回のクラッシュの伏線になる。

:::message alert
**重要な区別**: 「Ollama」「MLX」「mlx_lm」は別物。

- **Ollama 0.19+** が MLX **バックエンド** を内蔵 ≠ ユーザーが mlx_lm を直接使うこと
- **mlx_lm** は Python パッケージ（CLI ツール `mlx_lm.generate`）として独立して使える
- 16GB Mac では Ollama は MLX を使わず、llama.cpp 経由で動く（→ 今回のバグに直撃）
:::

---

## 前提知識: M5 chip と macOS 26.3 で何が変わったのか

M5 のクラッシュ問題を理解するために、ハードウェアとOSの変化を押さえておく。

### M5 chip = MTLGPUFamilyApple10

Apple の Metal API は GPU ファミリーごとに能力を区分している:

| GPU ファミリー | 対応チップ |
|---|---|
| Apple7 | M1 |
| Apple8 | M2 |
| Apple9 | M3, M4 |
| **Apple10** | **M5（新規）** |

M5 で導入された `MTLGPUFamilyApple10` は **GPU 内 Neural Accelerator** を新搭載しており、[Apple 機械学習研究ブログ](https://machinelearning.apple.com/) によれば **M4 比で TTFT 最大 4 倍**（Qwen3-14B-MLX-4bit 検証で 4.06 倍）の高速化を実現する。bfloat16 への性能最適化も入っている。

### Metal cooperative tensor operations の bfloat / half 型

M5 の Neural Accelerator を活かすには、Metal のシェーダで `cooperative tensor` 操作を bfloat16（16ビット浮動小数点・指数部 8 ビット）で扱う必要がある。

ここで問題が起きた。

[Issue #15541](https://github.com/ollama/ollama/issues/15541)、[#15594](https://github.com/ollama/ollama/issues/15594) によると:

> The static_assert failure indicating a mismatch between **bfloat and half types** in the Metal cooperative tensor operations.
> 「Metal の cooperative tensor 操作で bfloat 型と half 型（fp16）の型不一致による static_assert 失敗」

Ollama に同梱されている事前コンパイル済みの Metal ライブラリは **half（fp16）前提で書かれていた**。M5 はこれを bfloat16 として扱おうとして型 assertion に失敗 → SIGABRT で abort、というのがクラッシュの正体だ。

---

## 私の検証環境と再現手順

最小再現を示す。同じ環境を持っているなら、そのまま再現するはずだ。

### 環境

| 項目 | 値 |
|---|---|
| マシン | MacBook Pro `Mac17,2` |
| チップ | Apple M5（10コア = 4P + 6E） |
| GPU | Apple M5（10コア・Metal 4） |
| メモリ | 16 GB ユニファイド |
| macOS | 26.3 (Build 25D125, "Tahoe") |
| Ollama | 0.21.2（クラッシュ） |
| mlx_lm | 0.31.2（動作） |

### 再現コマンド

```bash
# 任意のモデルをpullして実行するだけで再現する
ollama pull qwen3:1.7b
ollama run qwen3:1.7b "こんにちは"
```

期待される（壊れた）出力:

```
Error: 500 Internal Server Error: model failed to load,
this may be due to resource limitations or an internal error,
check ollama server logs for details
```

### サーバーログの確認

`~/.ollama/logs/server.log` を見ると、決定的な行が見つかる:

```
3   ollama   ...  _cgo_c81fd19bee02_Cfunc_ggml_backend_get_default_buffer_type + 36
4   ollama   ...  ollama + 509612
SIGABRT: abort

time=2026-04-26T20:39:14 level=ERROR
  msg="llama runner terminated" error="exit status 2"
```

`ggml_backend_get_default_buffer_type` の呼び出し直後に SIGABRT。これが既報の Metal 初期化失敗である。

---

## 同じ問題を踏んでいる人は世界中にいる

調べると、これは個別の運用ミスではなく **広範な互換性問題**だと分かった。Ollama 公式リポジトリだけで以下の Issue が立っている（2026年4月時点）:

| Issue | タイトル | 関連 |
|---|---|---|
| [#15448](https://github.com/ollama/ollama/issues/15448) | Apple M5 + macOS 26.3.1: 500 Internal Server Error | **同じ macOS 26.3.x 環境**（メモリ・Ollamaバージョンは異なる） |
| [#15748](https://github.com/ollama/ollama/issues/15748) | Ollama 0.21.0 fails to initialize Metal on Apple M5 / macOS 26.2 while 0.18.0 works | **バージョン回帰の証拠** |
| [#15594](https://github.com/ollama/ollama/issues/15594) | Metal compilation error on M5 / macOS Tahoe 26.3.1 - static_assert failed | 根本原因 |
| [#15541](https://github.com/ollama/ollama/issues/15541) | Metal backend crash on Apple M5: bfloat/half mismatch | 型不一致詳細 |
| [#15500](https://github.com/ollama/ollama/issues/15500) | "model failed to load" on Mac M5 | エラー本文 |
| [#15548](https://github.com/ollama/ollama/issues/15548) | Gemma 4 E2B fails to load on Apple M5 | 特定モデル |
| [#15496](https://github.com/ollama/ollama/issues/15496) | Ollama 0.20.5 crashes on Apple M5 (MacBook Air 16GB) | **同じ16GB報告** |
| [#14432](https://github.com/ollama/ollama/issues/14432) | Apple M5 / macOS 15: Metal backend fails - static_assert type mismatch | 古いmacOSでも発生 |
| [#13867](https://github.com/ollama/ollama/issues/13867) | GGML_ASSERT crash on Apple M5 - regression in 0.13.x+ | **回帰のバージョン特定** |

これらをまとめると、ハッキリと言える事実は次のとおり:

- **Ollama 0.13.x 以降で回帰**（0.12.4 までは動く）
- **0.18.0 では動作報告あり**（[#15748](https://github.com/ollama/ollama/issues/15748)）
- **0.19/0.20/0.21 系で広範に再発**（M5 + macOS 26.x）
- **モデルサイズや量子化に依存しない**（小型モデルでも発生）
- **メモリ容量とは無関係**（16GB / 32GB / 64GB すべて報告あり）

---

## M5 でローカル LLM を動かす5つの実践パターン

クラッシュを受けて、私は次のいずれかを選ぶ必要があった。実際に検証した結果を含めて整理する。

### パターン1: Ollama 0.12.4 にダウングレード（クラッシュ回避・既存運用維持）

```bash
# 既存Ollamaを削除
brew uninstall --cask ollama

# 旧バージョンを取得（0.12.4が最後の動作確認バージョン）
curl -L https://github.com/ollama/ollama/releases/download/v0.12.4/Ollama-darwin.zip -o /tmp/ollama-0.12.4.zip

# 解凍してアプリケーションに配置
unzip /tmp/ollama-0.12.4.zip -d /Applications/
```

:::message
**メリット**: 既存の `ollama run` ワークフローがそのまま使える。
**デメリット**: 0.13 以降の機能（MLX バックエンド、新モデル対応）が使えない。新規モデルが pull できない可能性もあり。
:::

### パターン2: mlx_lm に乗り換え（推奨・本記事の主役）

私が選んだのはこれ。Apple 純正の MLX フレームワークを直接呼ぶ Python CLI。

```bash
# uv（高速Pythonパッケージマネージャ）でインストール
brew install uv
uv pip install mlx-lm

# 即実行
mlx_lm.generate \
  --model mlx-community/Qwen3-1.7B-4bit \
  --prompt "日本の四季について200文字で説明してください。" \
  --max-tokens 256
```

初回はモデルを HuggingFace `mlx-community` リポジトリからダウンロードする。

:::message
**メリット**: M5 ネイティブ最適化、メモリ効率最良、bfloat16 対応済み。
**デメリット**: Ollama API（OpenAI互換）との互換性なし。HTTP サーバ機能は別途用意が必要。
:::

### パターン3: llama.cpp バイナリを直接使う（ポータビリティ重視）

```bash
brew install llama.cpp

# Hugging Face から GGUF モデルをダウンロード
llama-cli --model ~/path/to/model.gguf --prompt "Hello"
```

:::message
**メリット**: 量子化形式（GGUF）の選択肢が豊富、HTTP サーバ（`llama-server`）も同梱。
**デメリット**: M5 互換性は ggml 側の対応次第（Ollama と同じ ggml を使うため、影響を受ける可能性）。
:::

### パターン4: LM Studio に移行（GUI 派）

[LM Studio](https://lmstudio.ai) は llama.cpp と MLX の両バックエンドを GUI で切り替えられる。M5 でも MLX バックエンドを選べば動作する報告が多い。

:::message
**メリット**: GUI で直感的、モデル管理が楽、MLX を簡単に有効化できる。
**デメリット**: クローズドソース、CLI / スクリプト統合がやや弱い。
:::

### パターン5: 様子見（修正パッチを待つ）

Ollama 側で修正 PR が動いている可能性は高い。Issue にはメンテナのレスポンスもあり、優先度は高そうだ。

実装上、修正は Metal シェーダ側で `cooperative_matrix` の `bf16` 対応分岐を追加すれば済むはずなので、そう遠くないうちにパッチが出ると予想する。

:::message
**メリット**: 何もしなくていい。
**デメリット**: 修正がいつ来るか不明。M5 を買った今すぐ動かしたい人には不適。
:::

### 5パターン比較表

| パターン | 難易度 | 互換性 | 速度 | M5最適化 | 推奨度 |
|---|---|---|---|---|---|
| 1. Ollama 0.12.4 ダウングレード | 中 | ◎（既存ワークフロー維持） | △ | ✗ | △ |
| 2. **mlx_lm 直接** | 中 | △ | ◎ | ◎ | **◎** |
| 3. llama.cpp 直接 | 高 | ◎（GGUF） | ○ | △ | ○ |
| 4. LM Studio | 低 | ◎ | ○ | ○ | ○ |
| 5. 様子見 | — | — | — | — | △ |

---

## Ollama 公式の M5 / MLX 対応状況

事実関係を権威ソースで補強しておく。

### 公式: M5 で何が高速化されるはずだったのか

[Ollama 公式 MLX 発表](https://ollama.com/blog/mlx) より引用:

> On Apple's M5, M5 Pro and M5 Max chips, Ollama leverages the new GPU Neural Accelerators to accelerate both time to first token (TTFT) and generation speed (tokens per second).
>
> 「M5 / M5 Pro / M5 Max では、Ollama は新 GPU Neural Accelerator を活用し、TTFT と生成速度を加速する」

[MacRumors（2026年3月31日）](https://www.macrumors.com/2026/03/31/ollama-now-runs-faster-apple-silicon-macs/) によれば、Ollama 0.19 で MLX 統合により以下の高速化が公式に謳われている（**Ollama 0.18 比、Qwen3.5-35B-A3B(NVFP4) vs Q4_K_M モデル比較**）:

- プリフィル速度: **1.6倍**
- 生成速度: **約2倍（93%向上）**

比較条件はメジャーバージョン全体ではなく、特定モデル・量子化形式同士の比較である点に注意したい。

### しかし: MLX バックエンドは 32GB+ 限定

[Ollama 公式ブログ](https://ollama.com/blog/mlx) によれば、MLX バックエンドの利用には **32GB 以上のユニファイドメモリ** が必要とされている（公式表現は「Please make sure you have a Mac with more than 32GB of unified memory.」）。

つまり **16GB Mac では Ollama は引き続き llama.cpp + ggml を使う**。これが今回のバグ直撃の理由だ。32GB 以上を持っていれば MLX バックエンドが優先され、ggml の bfloat / half 問題を回避できる可能性がある。

### 修正状況（2026年4月26日時点）

GitHub Issue を眺める限り、

- 公式メンテナの認識あり
- 一部 PR が動いている形跡あり
- ただしマージ済みの修正版リリースはまだ出ていない

---

## M5 でローカル LLM を動かす際のアンチパターン7選

ここまでで得た知見を、踏むべきでない地雷の形で残しておく。

### 1. 「メモリ不足だろう」と決めつけて 16GB を疑う

エラーメッセージは `model failed to load, this may be due to resource limitations` と書かれている。読むと「メモリ足りないんだな」と思いがちだ。

**しかし違う**。1.4GB の `qwen3:1.7b` ですら同じエラーで落ちる。**メモリ容量はこの問題と無関係**。サーバログ（`~/.ollama/logs/server.log`）の SIGABRT を確認しなければ原因にたどり着けない。

### 2. Ollama を最新版にアップデートして解決を狙う

直感的には「最新版にすれば直っているはず」と考える。しかし [#15748](https://github.com/ollama/ollama/issues/15748) が示すとおり、**0.18.0 では動いていたものが 0.21 で壊れている**。アップデートはむしろ逆効果になりうる。

### 3. ベンチマークで Ollama 経由の M2 と mlx_lm 経由の M5 を直接比較する

これは私が記事を書く中で気づいた罠だ。

- M2 8GB（Ollama）: Qwen3-4B デコード 25 tok/s
- M5 16GB（mlx_lm）: Qwen3-4B 生成 49 tok/s

「**約2倍速い！**」と書きたくなる。しかし **Ollama (llama.cpp) と mlx_lm はバックエンドが違う**。同 Apple Silicon でも MLX が 15-30% 速いと報告されている以上、純粋なハードウェア性能差は約 1.5-1.8 倍程度に過ぎない可能性がある。

比較するなら同じバックエンドで揃える、または「フレームワーク差を含む数値」と明記する。

### 4. ggml と GGUF を混同する

- **ggml**: 推論ライブラリ（C++）。llama.cpp の中核。Metal バックエンドを含む。
- **GGUF**: モデルファイル形式（バイナリフォーマット）。

「ggml フォーマット」という言い方は古く、現在は **GGUF が正式**。ggml 自体は形式名ではない。

### 5. mlx_lm のモデル名を Ollama のと同じだと思い込む

- Ollama: `qwen3:1.7b`
- mlx_lm: `mlx-community/Qwen3-1.7B-4bit`

**形式も違うし、量子化方式も違う**。mlx_lm は HuggingFace の `mlx-community` で配布されている MLX ネイティブ量子化版を使う。Ollama 用モデル（GGUF）は mlx_lm では動かない。

### 6. M5 16GB で Ollama の MLX バックエンドが効くと期待する

公式が「Ollama 0.19 で MLX 対応」と発表しているので 16GB でも MLX が効くと思いがちだ。**32GB 以上が必要**で、16GB ユーザーは引き続き ggml バックエンド経由で動く。

### 7. 「Ollama 経由でしか LLM を動かせない」と思い込む

Ollama は便利だが、Apple Silicon ではむしろ **mlx_lm の方がネイティブ最適化が効いていて速い**。Ollama を完全に捨てる必要はないが、選択肢として mlx_lm を持っておくと M5 で詰みにくい。

---

## mlx_lm 経由の M5 16GB 実機ベンチマーク

代替手段としての mlx_lm の実力を、過去 M2 8GB（Ollama 経由）の数値と並べて示す。

### 検証条件

- マシン: MacBook Pro M5 16GB
- フレームワーク: mlx_lm 0.31.2
- 統一プロンプト: `日本の四季について200文字で説明してください。`
- max-tokens: 256
- 各モデル 1 回実行（複数回計測の中央値ではない、参考値）

### 結果

| モデル | プロンプト処理 (tok/s) | 生成速度 (tok/s) | ピークメモリ (GB) | 動作判定 |
|---|---|---|---|---|
| `mlx-community/Qwen3-1.7B-4bit` | 35.99 | **111.11** | 1.07 | ◎ 余裕 |
| `mlx-community/Qwen3-4B-4bit` | 75.36 | **48.75** | 2.38 | ◎ 快適 |
| `mlx-community/Qwen3-14B-4bit` | 4.40 | **14.69** | 8.42 | ○ 実用 |

### M2 8GB（Ollama 経由）との対比（参考）

| モデル | M2 8GB (Ollama) 生成 | M5 16GB (mlx_lm) 生成 | 参考倍率 |
|---|---|---|---|
| Qwen3 1.7B | 54.0 tok/s | 111.1 tok/s | 約2.06x |
| Qwen3 4B | 25.3 tok/s | 48.8 tok/s | 約1.93x |
| **Qwen3 14B** | **実行不可** | 14.7 tok/s | **新規実用域** |

:::message alert
**注意**: フレームワークが異なる（Ollama=llama.cpp系 vs mlx_lm=Apple純正MLX）ため、この倍率は純粋なハードウェア差ではない。MLX 自体が同 Apple Silicon 上で約 15-30% 速いと報告されているため、純ハード差は約 1.5-1.8 倍程度と推定される。
:::

### Qwen3-14B-4bit の意味

M2 8GB では絶対に動かなかった 14B 級モデルが、M5 16GB では **生成 14.7 tok/s（≒人間の朗読より速い）、ピークメモリ 8.4 GB（16GB の 53%）**で実用域に入る。

これは「メモリの壁」が 8GB → 16GB で1段階動いた事実の証拠だ。買い替え判断の指針になる。

---

## 関連ツール比較表（最終版）

| ツール | バージョン | M5 動作 | 主な用途 | 推奨度（M5 16GB） |
|---|---|---|---|---|
| **Ollama** | 0.21.2 | **❌ クラッシュ** | LLM サーバ運用 | 暫定 ✗（修正待ち） |
| **Ollama** | 0.12.4 | ✅（既知の動作版） | 同上 | △（旧機能のみ） |
| **mlx-lm** | 0.31.2 | ✅ | テキスト LLM | **◎** |
| **mlx-vlm** | 0.4.3 | ✅（要検証） | Vision LLM | ◎（Vision 用途） |
| **llama.cpp** | 最新 | △（ggml側次第） | GGUF モデル | ○ |
| **LM Studio** | 最新 | ✅（MLX backend） | GUI 派 | ◎ |

---

## M5 で詰まないための実践チェックリスト

新しい M5 Mac でローカル LLM を動かすときに、私自身が次回繰り返したいリスト。

- [ ] **`ollama run` がいきなり動くと期待しない**。事前に `~/.ollama/logs/server.log` の場所を覚えておく
- [ ] **Ollama がクラッシュしたら 0.12.4 ダウングレード or mlx_lm 切替を即決断する**（時間を溶かさない）
- [ ] **mlx_lm を最初からインストールしておく**: `brew install uv && uv pip install mlx-lm`
- [ ] **モデル名は HuggingFace `mlx-community/*` を使う**（Ollama名とは別物）
- [ ] **16GB なら Ollama MLX backend は効かないと知っておく**（32GB+ 限定）
- [ ] **エラーメッセージの「resource limitations」は鵜呑みにしない**。実態は Metal シェーダ問題
- [ ] **GitHub Issue [#15448](https://github.com/ollama/ollama/issues/15448) や [#15748](https://github.com/ollama/ollama/issues/15748) を Watch して修正リリースを待つ**

---

## まとめ

要点を整理する:

1. **M5 + macOS 26.3 + Ollama 0.13.x 以降は SIGABRT クラッシュする**。これは個別環境ではなく既知バグ
2. **原因は Metal cooperative tensor の bfloat / half 型不一致**。M5 = `MTLGPUFamilyApple10` への ggml 側未対応
3. **回避策は5つあるが、16GB Mac では mlx_lm 直接実行が現実解**
4. **Ollama の MLX バックエンド統合は素晴らしいが、32GB 以上限定**。16GB ユーザーは恩恵を受けられない
5. **mlx_lm 経由なら M5 16GB は Qwen3-14B まで実用域**。M2 8GB 時代では不可能だった大型モデルが動く

私はこの記事を書きながら、改めて思った。新しいハードウェアを買ったときは、「動かない」のは自分の環境のせいではなく、**ツール側の対応待ち**である可能性を疑うべきだ。サーバログを読み、GitHub Issue を漁る習慣が、M5 のような最先端環境では時間節約に直結する。

この記事が、同じクラッシュで詰まった方の数時間を節約できれば嬉しい。

---

## 参考リンク

### Ollama 関連 GitHub Issues

- [#15448 - Apple M5 + macOS 26.3.1 500 Error](https://github.com/ollama/ollama/issues/15448)
- [#15748 - 0.21.0 fails to initialize Metal on M5 / 0.18.0 works](https://github.com/ollama/ollama/issues/15748)
- [#15594 - Metal compilation static_assert](https://github.com/ollama/ollama/issues/15594)
- [#15541 - Metal bfloat/half mismatch](https://github.com/ollama/ollama/issues/15541)
- [#15500 - "model failed to load" on M5](https://github.com/ollama/ollama/issues/15500)
- [#15548 - Gemma 4 E2B fails on M5](https://github.com/ollama/ollama/issues/15548)
- [#15496 - 0.20.5 crashes on M5 16GB](https://github.com/ollama/ollama/issues/15496)
- [#13867 - GGML_ASSERT regression in 0.13.x+](https://github.com/ollama/ollama/issues/13867)

### Ollama / MLX 公式

- [Ollama is now powered by MLX on Apple Silicon (Ollama Blog)](https://ollama.com/blog/mlx)
- [Apple MLX (公式リポジトリ)](https://github.com/ml-explore/mlx)
- [mlx-lm (公式)](https://github.com/ml-explore/mlx-lm)

### 比較記事・解説

- [llama.cpp vs MLX vs Ollama vs vLLM: Local AI Inference for Apple Silicon in 2026 (Contra Collective)](https://contracollective.com/blog/llama-cpp-vs-mlx-ollama-vllm-apple-silicon-2026)
- [Ollama Now Runs Faster on Macs Thanks to Apple's MLX Framework (MacRumors)](https://www.macrumors.com/2026/03/31/ollama-now-runs-faster-apple-silicon-macs/)
- [Ollama adopts MLX for faster AI performance on Apple silicon (9to5Mac)](https://9to5mac.com/2026/03/31/ollama-adopts-mlx-for-faster-ai-performance-on-apple-silicon-macs/)

---

:::message
この記事は MacBook Pro M5 16GB（macOS 26.3）の実機で再現確認した内容を元にしている。記事執筆時点（2026年4月26日）の情報であり、Ollama 側の修正リリースが出れば状況が変わる可能性がある。最新のリリース状況は [Ollama GitHub Releases](https://github.com/ollama/ollama/releases) を確認してほしい。
:::

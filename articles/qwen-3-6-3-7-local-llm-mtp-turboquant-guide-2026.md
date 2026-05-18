---
title: "【2026年最新】Qwen 3.6/3.7 ローカル運用完全ガイド ― 27B/35B-A3B 選定とMTP・TurboQuant攻略"
emoji: "🦅"
type: "tech"
topics: ["LLM", "Qwen", "llamacpp", "ローカルLLM", "AI"]
published: true
---

:::message
**本記事の前提**: 2026年5月19日時点の情報。Qwen 3.7 は Qwen Chat 上に出現していますが、本記事執筆時点で **オープンウェイトは未公開** です（後述）。本記事は公開情報・公式ドキュメント・主要ベンチマークブログの一次/二次情報を元に整理しています。ベンチマーク値は出典元の測定値であり、筆者環境での実測ではありません。
:::

## この記事で分かること

ローカル LLM 界隈で連日トレンド入りしている **Qwen 3.6/3.7** について、こんな悩みはありませんか？

- 「Qwen 3.7 がリリースされたらしいけど、HuggingFace に見当たらない」
- 「27B と 35B-A3B、結局どっちを入れればいいの？」
- 「llama.cpp、ik_llama.cpp、vLLM、Ollama、LM Studio… バックエンドが多すぎる」
- 「MTP って何？ TurboQuant って何？ なんで KV キャッシュを量子化するの？」
- 「24GB VRAM で本当にコンテキスト 262K 入るの？」

本記事ではこれら **「Qwen ローカル運用で誰もが最初にぶつかる5つの混乱」を整理** し、2026年5月時点で「今すぐ手を動かせる」セットアップ手順とアンチパターンまでをまとめます。

:::message
**対象読者**: ローカル LLM を 1 回以上触ったことがある中級者。VRAM 16〜48GB のコンシューマ GPU を持っている人。
:::

---

## ⭐ Qwen 3.6/3.7 のラインナップを整理する

ここが本記事の最重要セクションです。Reddit r/LocalLLaMA の議論を追っていても、用語が氾濫していて何がどう違うのか分かりにくい状態です。まず全体像を表で押さえます。

### モデル一覧（2026年5月時点）

| モデル | パラメータ | アーキ | 重み公開 | コンテキスト | 想定 VRAM (Q4) |
|--------|-----------|--------|---------|------------|-------------|
| **Qwen3.5-27B** | 27B dense | Transformer | ✅ 公開済 | 262K | 16〜18GB |
| **Qwen3.5-35B-A3B** | 35B total / 3B active | MoE | ✅ 公開済 | 262K | 18〜22GB |
| **Qwen3.6-27B** | 27B dense | Gated DeltaNet + Gated Attention | ✅ 公開済 | **262K** | 16〜18GB |
| **Qwen3.6-35B-A3B** | 35B total / 3B active | MoE + DeltaNet/Attention | ✅ 公開済 | **262K** | 18〜22GB |
| **Qwen3.6-Plus** | クラウド限定 | プロプラ | ❌ Cloud のみ | 262K | — |
| **Qwen 3.7** | 不明 | 不明 | ❌ **未公開** | 不明 | 不明 |

:::message
**コンテキスト長について**: Qwen3.5 系も Qwen3.6 系も、HuggingFace 公式モデルカードでは **262,144 トークン（≒262K）ネイティブ対応** と明記されています（拡張で最大 1,010,000 トークンまで対応）。Qwen3.6 の差別化要素はコンテキスト長ではなく、**Gated DeltaNet/Attention ハイブリッドによる長文時の品質維持** と **MTP ネイティブ統合による高速化** です。
:::

### ⚠️ Qwen 3.7 はまだ "動かせない"

[Startup Fortune の報道](https://startupfortune.com/alibabas-qwen-team-pushes-forward-with-qwen-37-release-amid-export-control-headwinds/) によれば、Qwen 3.7 は 2026-05-18 に Qwen Chat 上にオプションとして出現しましたが、Alibaba から正式なリリースノートも、ModelScope/HuggingFace でのオープンウェイト公開もまだありません。

:::message alert
**現時点（2026-05-19）で「Qwen 3.7 をローカルで動かす」記事や手順は全て予測または誤情報です**。ホスティングされたチャット UI 上の表示と、ダウンロード可能なモデルの公開は別物です。Qwen エコシステムでは特に、ライセンス条項を含めた公式リリースを待つ必要があります。
:::

本記事では、**今すぐ動かせる Qwen 3.6 系を主軸** に解説し、Qwen 3.7 公開後にすぐ移行できるよう設計の勘所も整理します。

### 27B Dense と 35B-A3B MoE は別物

同じ「Qwen 3.6」でも 27B と 35B-A3B は性質が大きく違います。

| 項目 | Qwen3.6-27B (Dense) | Qwen3.6-35B-A3B (MoE) |
|------|---------------------|----------------------|
| 全パラメータ作動 | ✅ 毎トークン全 27B | ❌ 毎トークン 3B のみ |
| 生成速度（Unsloth測定）[^1] | 〜140 tok/s (UD-Q2_K_XL) | **〜220 tok/s** |
| 品質 | **コーディングで優位** | 速度は速いが質はやや劣る |
| 推奨 VRAM | 24GB あれば最適 | 16GB でも RAM オフロードで動作 |
| 向く用途 | コード生成、深い推論 | チャット、要約、エージェント大量並列 |

出典: [aimadetools の比較](https://www.aimadetools.com/blog/qwen-3-6-27b-vs-35b-a3b/), [Unsloth ドキュメント](https://unsloth.ai/docs/models/qwen3.6)

[^1]: Unsloth 公式ドキュメントの数値（GPU 未特定）。同ページでは RTX 6000 で 160/240 tok/s も併記。RTX 3090 でのコミュニティ実測は 27B Dense で 80〜100 tok/s 前後との報告もある（[出典](https://www.reddit.com/r/LocalLLaMA/comments/1t07su1/followup_qwen3627b_on_1_rtx_3090_pushing_to_218k/)）。

**選び方の原則**:
- 24GB VRAM があってコードを毎日書く → **27B Dense**
- 16GB 以下 or 速度最優先 → **35B-A3B MoE**

---

## 前提知識：なぜ今 Qwen をローカルで動かすのか

2026年に入り、ローカル LLM 環境は以下の理由で「業務利用に耐える」段階に来ました。

1. **262K コンテキスト** — Qwen 3.6 でデフォルト 262K、長文ドキュメントや巨大コードベースを一度に読み込める
2. **MoE モデルの実用化** — 35B-A3B のように「サイズは大きいが推論は軽い」モデルが普及
3. **量子化技術の進化** — TurboQuant KV キャッシュ圧縮など、24GB に 262K 文脈が乗る
4. **コーディング能力の急上昇** — r/LocalLLaMA では「4B モデルでベンチ 87%」のような報告も出ている（[出典: Reddit 投稿](https://www.reddit.com/r/LocalLLaMA/comments/1tgecrq/i_built_a_coding_agent_that_gets_87_on_benchmarks/)）

特に **「Anthropic が EU をサイバー AI から除外」** ([Reddit r/cybersecurity](https://www.reddit.com/r/cybersecurity/comments/1tgmscx/anthropic_shuts_the_eu_out_of_its_most_advanced/)) のような地政学的制限が顕在化する中、ローカル運用の重要性は増しています。

---

## セットアップ：必要なもの

### 推奨ハードウェア

| 要素 | 最低 | 推奨 |
|------|------|------|
| GPU VRAM | 16GB (RTX 4060 Ti 16GB / 3090) | **24GB (RTX 3090/4090)** |
| システム RAM | 32GB | 64GB (オフロード用) |
| ストレージ | 30GB 空き | 100GB 空き (複数モデル) |
| OS | Windows/macOS/Linux | Ubuntu 22.04 LTS |

### ソフトウェア構成（推奨）

- **バックエンド**: `llama.cpp` (mainline / master ブランチの最新版)
- **量子化モデル配布**: [Unsloth](https://huggingface.co/unsloth) (UD-Quant) または [GGUF 公式](https://huggingface.co/Qwen)
- **フロントエンド**: OpenCode / Continue.dev / LM Studio / Open WebUI のいずれか

---

## インストールと初回起動

### llama.cpp ビルド（CUDA）

```bash
# 最新版を取得（2026-05時点で MTP がメインラインにマージ済み）
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release -j
```

### モデルのダウンロード

Unsloth の MTP 対応 GGUF を推奨します（後述する MTP 速度ブーストが使えます）。

```bash
# Qwen3.6-27B-MTP-IQ4_KS（24GB VRAM 向け）
huggingface-cli download unsloth/Qwen3.6-27B-MTP-GGUF \
  "Qwen3.6-27B-MTP-IQ4_KS.gguf" --local-dir ./models
```

:::message alert
**MTP を使いたい場合は必ずファイル名に "MTP" が入った GGUF を選ぶこと**。非 MTP 版は起動はしますが speculative decoding が動きません（[出典: dredyson の解説](https://dredyson.com/mtp-llama-cpp-with-qwen3-6-27b-a-complete-beginners-step-by-step-guide-to-speculative-decoding-turboquant-and-running-multiple-models-on-limited-gpu-vram/)）。
:::

### 初回起動コマンド

```bash
./build/bin/llama-server \
  -m ./models/Qwen3.6-27B-MTP-IQ4_KS.gguf \
  -ngl 99 \
  -c 156000 \
  -fa on \
  --spec-type draft-mtp \
  --parallel 1 \
  --port 9090
```

主要オプション解説：

| フラグ | 意味 |
|--------|------|
| `-ngl 99` | 全レイヤーを GPU にオフロード |
| `-c 156000` | コンテキスト長 156K（24GB 安全圏） |
| `-fa on` | Flash Attention 有効 |
| `--spec-type draft-mtp` | MTP speculative decoding 有効化（2026年5月時点の正式フラグ名） |
| `--parallel 1` | MTP は `n_parallel=1` のみサポート |

---

## ⭐ 5つの実践ワークフローパターン

### パターン1: シングルセッション・コーディング（24GB / 27B Dense）

最も基本構成。OpenCode や Continue.dev から `http://localhost:9090` を OpenAI 互換エンドポイントとして指定するだけ。

```bash
# OpenCode の場合
opencode --model openai/Qwen3.6-27B --api-base http://localhost:9090/v1
```

### パターン2: 大量並列エージェント（16GB / 35B-A3B MoE）

エージェント並列実行時は MoE の高速さが効きます。Claude Code 系の subagent を 5-10 個並列で動かすような用途。

```bash
./build/bin/llama-server \
  -m ./models/Qwen3.6-35B-A3B-MTP-Q4_K_M.gguf \
  -ngl 99 -c 65536 -fa on \
  --parallel 8
```

:::message
MoE モデルは並列度を上げても速度低下が小さい。Dense モデルとの最大の使い分けポイント。
:::

### パターン3: 超長文コンテキスト（262K with TurboQuant KV）

[TurboQuant KV cache](https://github.com/ggml-org/llama.cpp/discussions/20969) を使うと KV キャッシュが 3〜6 倍圧縮され、24GB に 262K 文脈が乗ります。

:::message alert
**TurboQuant は 2026年5月時点で mainline llama.cpp にマージされていません**。動かすには [TheTom/turboquant_plus](https://github.com/TheTom/turboquant_plus) などのコミュニティフォークが必要です（[出典: Towards AI 解説](https://pub.towardsai.net/running-a-35b-model-locally-with-turboquant-whats-actually-possible-right-now-1ac5327430b0)）。mainline でこのコマンドを実行すると未対応エラーになります。
:::

```bash
# TheTom/turboquant_plus フォークをビルド済みの想定
./build/bin/llama-server \
  -m ./models/Qwen3.6-27B-MTP-IQ4_KS.gguf \
  -ngl 99 -c 262144 -fa on \
  -ctk turbo3 -ctv turbo3 \
  --spec-type draft-mtp --parallel 1
```

KV cache タイプは `turbo3`（3.25ビット・約4.9倍圧縮）と `turbo4`（4.25ビット・約3.8倍圧縮）の2種類。Q8_0+ ウェイトとは `turbo3`、より高精度を求めるなら `turbo4` が目安です。巨大コードベース全体を一度に読ませる用途に最適。

### パターン4: ハイブリッド GPU+CPU オフロード（VRAM 不足対策）

VRAM が足りない場合、MoE モデルの一部レイヤーを CPU に逃がす方法。

```bash
./build/bin/llama-server \
  -m ./models/Qwen3.6-35B-A3B-Q4_K_M.gguf \
  -ngl 60 \
  -ot ".ffn_.*_exps.*=CPU" \
  -c 32768 -fa on
```

MoE のエキスパート層を CPU 側に逃がすことで、12GB GPU + 32GB RAM でも 35B-A3B が走ります（[出典: carteakey](https://carteakey.dev/blog/running-qwen3-6-mtp-locally/)）。

### パターン5: マルチモデル・オーケストレーション

Reddit で話題になった ["Claude × MiniMax × Kimi" の多重エージェント構成](https://www.reddit.com/r/ClaudeCode/comments/1tgfm1x/i_didnt_think_this_was_possible/) のローカル版。

- **Claude Code (Manager)** がクラウド側で計画立案
- **ローカル Qwen3.6-35B-A3B** が実行ワーカーとして大量タスクをこなす
- API ベースは `http://localhost:9090/v1` 一本

エージェント並列度が上がるほどクラウド API コストは無視できなくなるため、実行系をローカル MoE に置き換える設計が現実解になりつつあります。

---

## ⭐ Unsloth/llama.cpp公式が推奨するベストプラクティス

### 推奨1: Unsloth の "UD" (Unsloth Dynamic) 量子化を使う

Unsloth が推進する [Unsloth Dynamic 2.0 GGUF](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs) は、**重要なレイヤーだけを選択的に高ビット（8/16-bit）で残す** ハイブリッド量子化。同等品質の他社量子化より約 8GB 小さくなる一方、精度劣化は 1 ポイント以内に収まると Unsloth は説明しています。

Qwen 3.6 系では `UD-Q2_K_XL` / `IQ4_KS` あたりが 24GB VRAM 向けの定番です（[出典: Unsloth Qwen3.6 ドキュメント](https://unsloth.ai/docs/models/qwen3.6)）。

### 推奨2: MTP は必ず `--spec-type draft-mtp` で有効化

MTP のメインラインマージ後、フラグ名は `--spec-type draft-mtp` に統一されました（旧名は廃止）。

> The MTP support PR has officially been merged into the llama.cpp mainline master branch, and the flag has been officially renamed to --spec-type draft-mtp.

出典: [llama.cpp Discussion #20969](https://github.com/ggml-org/llama.cpp/discussions/20969)

### 推奨3: KV キャッシュも量子化する

通常モデル重みを FP16/Q4 にしても、KV キャッシュが FP16 のままでは長文時に VRAM を食い潰します。**mainline で安全に使うなら `-ctk q8_0 -ctv q8_0`**、TurboQuant フォークが導入できるなら `-ctk turbo3 -ctv turbo3` で更に圧縮するのが定石です。

---

## ⭐ やりがちなアンチパターン 7選

### 1. 非 MTP の GGUF を選んでしまう

:::message alert
ファイル名に "MTP" が入っていない GGUF で `--spec-type draft-mtp` を指定しても、エラーは出ずに **MTP が無効のまま起動**します。1.5〜1.8 倍の速度ブーストを取り逃します。
:::

### 2. `llama.cpp` を数日アップデートしていない

[Reddit の PSA 投稿](https://www.reddit.com/r/LocalLLaMA/comments/1tgobhj/psa_if_you_havent_updated_llamacpp_for_a_couple/) で報告された通り、ここ数日で MTP 周りの性能が劇的に改善されています。「MTP は遅い」と感じたらまず `git pull && cmake --build` を試してください。

### 3. ik_llama.cpp に盲目的に切り替える

ik_llama.cpp は CPU/ハイブリッド推論や DeepSeek 用の高速化が売りですが、**Qwen3 MoE + IQ4_XS では mainline より遅い** という報告もあります（[Issue #1699](https://github.com/ikawrakow/ik_llama.cpp/issues/1699)）。必ず自環境でベンチを取って比較すること。

### 4. `--parallel` を 2 以上にしながら MTP を有効化する

MTP は **`n_parallel=1` での運用が公式に推奨** されています。`--parallel 2` 以上でも起動はしますが、メモリ圧迫によるクラッシュやドラフト受容率の低下が報告されており、`--spec-type draft-mtp` を使う限り `--parallel 1` に固定するのが安全です（[出典: dredyson MTP ガイド](https://dredyson.com/mtp-llama-cpp-with-qwen3-6-27b-a-complete-beginners-step-by-step-guide-to-speculative-decoding-turboquant-and-running-multiple-models-on-limited-gpu-vram/)）。

### 5. 24GB VRAM に 35B-A3B Q8_0 を載せようとする

35B-A3B でも Q8_0 量子化だと 35GB 近く食います。24GB ではフルロードできず、結果的に CPU オフロードで遅くなる本末転倒。**Q4_K_M / IQ4_KS が 24GB の最適解**。

### 6. コンテキストを 262K でフルロードしてしまう

262K コンテキストは魅力的ですが、TurboQuant KV を使わない場合 FP16 KV だけで 30GB を超えます。**まず 128K で動かし、必要に応じて TurboQuant フォーク + 262K に拡張** が正解。

### 7. Qwen 3.7 のオープンウェイトを待ち続けて手を動かさない

Qwen 3.7 の正式リリース時期は未公表。Qwen 3.6 系は 2026年4月時点で 27B/35B-A3B ともに公開済みで、エコシステム（量子化、MTP、TurboQuant）も整備済み。**3.7 を待たず 3.6 で基盤を作ることを推奨**します。

---

## 量子化と KV キャッシュの最適値

VRAM 別の推奨組み合わせを整理します。tok/s は **Unsloth・dredyson の測定値（GPU 環境は出典により異なる）** を目安として記載しているため、自環境では必ずベンチマークを取ってください。

| VRAM | モデル | 量子化 | KV cache | コンテキスト | 目安 tok/s |
|------|--------|--------|----------|------------|-----------|
| 12GB | 35B-A3B + CPU offload | Q4_K_M | q8_0/q8_0 | 32K | 〜30 tok/s |
| 16GB | 35B-A3B | Q4_K_M | q8_0/q8_0 | 65K | 〜100 tok/s |
| **24GB** | **27B Dense + MTP** | **IQ4_KS** | **q8_0/q8_0** | **156K** | **〜140 tok/s** |
| 24GB | 35B-A3B + MTP | Q4_K_M | q8_0/q8_0 | 65K | 〜220 tok/s |
| 24GB | 27B + TurboQuant ※フォーク要 | IQ4_KS | turbo3/turbo3 | **262K** | 〜130 tok/s |
| 48GB | 35B-A3B | Q6_K | f16/f16 | 128K | 〜200 tok/s |

出典: [Unsloth Qwen3.6 ドキュメント](https://unsloth.ai/docs/models/qwen3.6), [dredyson の包括比較](https://dredyson.com/i-tested-every-solution-for-qwen3-6-27b-heres-what-actually-works-a-complete-comparison-of-vllm-llama-cpp-mtp-fp8-awq-int4-and-dual-node-deployments-with-benchmarks-pros-cons-and-proven-re/), [Reddit benchmark スレッド](https://www.reddit.com/r/LocalLLaMA/comments/1tgis7s/qwen_36_27b_on_24gb_vram_setup_backend/)

---

## バックエンド・ランタイム比較

| バックエンド | 強み | 弱み | 向いている人 |
|-------------|------|------|-------------|
| **llama.cpp (mainline)** | MTP・TurboQuant 公式対応、安定 | エキスパート向け CLI | 標準解。迷ったらこれ |
| **ik_llama.cpp** | CPU/ハイブリッド最適化、SOTA 量子化 | Qwen3 MoE で逆に遅い場合あり | DeepSeek 派、CPU 主体 |
| **vLLM** | スループット最強、本番 API 向き | VRAM フルロード前提、設定難 | 本番サーバー運用者 |
| **Ollama** | セットアップ最速、初心者向け | MTP/TurboQuant 等の最新機能対応が遅い | 初心者・カジュアル利用 |
| **LM Studio** | GUI 完備、モデル管理楽 | CLI 統合・自動化に弱い | デスクトップ単体利用 |
| **MLX (Apple Silicon)** | M1/M2/M3 で爆速、メモリ統合 | macOS 限定 | Mac ユーザー |

---

## 実践チェックリスト

### セットアップ時
- [ ] llama.cpp を最新の master からビルドした（MTP マージ済みであること）
- [ ] GGUF ファイル名に "MTP" が含まれている（speculative decoding を使う場合）
- [ ] `nvidia-smi` で GPU が認識されている
- [ ] CUDA Toolkit のバージョンが llama.cpp の要求と一致

### 日常運用時
- [ ] コンテキストは必要分だけ（262K フルは TurboQuant フォーク使用時のみ）
- [ ] `--spec-type draft-mtp` を使うときは `--parallel 1` に固定
- [ ] KV キャッシュも量子化（最低 q8_0、フォーク導入時は turbo3）
- [ ] 週 1 で `git pull && cmake --build` して MTP 改善を取り込む

### トラブル時
- [ ] OOM したらまず KV キャッシュ量子化を強める（q8_0 → q4_0、フォーク導入なら turbo3）
- [ ] 速度が遅いと感じたら llama.cpp を最新化
- [ ] MoE モデルで遅い場合、`-ot` で CPU オフロードを調整

---

## まとめ

- **要点1**: Qwen 3.7 はまだオープンウェイトが公開されていない。今すぐ動かすなら **Qwen 3.6 系**
- **要点2**: 24GB VRAM の最適解は **Qwen3.6-27B Dense + MTP + IQ4_KS + q8_0 KV**
- **要点3**: 速度最優先・並列エージェント用途は **Qwen3.6-35B-A3B MoE**
- **要点4**: 速度ブーストは **MTP の `--spec-type draft-mtp`** と **TurboQuant KV** が二大柱
- **要点5**: バックエンドは迷ったら **llama.cpp mainline**。ik_llama.cpp は必ずベンチして比較

Qwen 3.7 が正式公開された際にも、ここで身につけた MTP/TurboQuant/量子化選定の知識はそのまま流用できます。**まず 3.6 で基盤を作る** のが、2026年5月時点の最適解です。

---

## 参考リンク

- [Qwen 公式ドキュメント (llama.cpp 連携)](https://qwen.readthedocs.io/en/latest/run_locally/llama.cpp.html)
- [Unsloth Qwen3.6 ドキュメント](https://unsloth.ai/docs/models/qwen3.6)
- [llama.cpp Discussion #20969: TurboQuant KV Cache](https://github.com/ggml-org/llama.cpp/discussions/20969)
- [Reddit: Qwen 3.6 27B on 24GB VRAM benchmark](https://www.reddit.com/r/LocalLLaMA/comments/1tgis7s/qwen_36_27b_on_24gb_vram_setup_backend/)
- [Reddit: Qwen 3.7 ドロップ報告](https://www.reddit.com/r/LocalLLaMA/comments/1tgpabe/qwen_37_droped_on_qwen_chat/)
- [Startup Fortune: Qwen 3.7 リリース状況分析](https://startupfortune.com/alibabas-qwen-team-pushes-forward-with-qwen-37-release-amid-export-control-headwinds/)
- [aimadetools: 27B Dense vs 35B-A3B MoE 比較](https://www.aimadetools.com/blog/qwen-3-6-27b-vs-35b-a3b/)
- [dredyson: MTP + llama.cpp 完全ガイド（英語）](https://dredyson.com/mtp-llama-cpp-with-qwen3-6-27b-a-complete-beginners-step-by-step-guide-to-speculative-decoding-turboquant-and-running-multiple-models-on-limited-gpu-vram/)

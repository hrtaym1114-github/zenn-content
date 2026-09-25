---
title: "Antigravity SDKのローカル実行を整理する — 16GB MacでGemma 4エージェントはどこまで回るか"
emoji: "🤖"
type: "tech"
topics: ["AIエージェント", "Gemma", "Ollama", "Python", "LLM"]
published: true
---

## この記事で分かること

「社内が閉域網だから、AIエージェントは諦めていた」——この記事はその前提を壊すために書いた。

Googleが2026年9月23日にAntigravity SDKのローカルAIモデル対応を発表した。**トークンコスト$0・データは端末から出ない・完全オフライン**でエージェントワークフローが回る。ただし公式の目玉であるGemma 4 26Bは**24GB以上のメモリ推奨**。16GBマシンは対象外に見える。

本記事は16GB Mac（MacBook Air M5）で実際にSDKをインストールし、2つのローカル実行ルートの可否を検証した結果を整理する。

:::message
**対象読者**: 閉域網・オフライン環境でエージェントを残したい技術者。16GB前後のマシンでローカルLLMを実務に使う人。
:::

**TL;DR（16GB Mac実測・2026-09-25時点）**

| ルート | 結果 | 内容 |
|---|---|---|
| `LiteRTAgentConfig` + Gemma 4 26B | ❌ 要件不足 | DL 16.8GB / **24GB以上推奨**。16GB機には載らない |
| `LocalOpenAIAgentConfig` + Ollama gemma4:12b | ✅ **動いた** | Agent起動1.9s。**ファイル作成タスクを完遂**（16.7s）。メモリは空き10%まで張り付く |

---

## 「Antigravity」が2つある — まず整理しよう

検索すると混乱する最大の理由はここにある。

| 項目 | Google Antigravity（IDE） | Antigravity SDK |
|------|--------------------------|-----------------|
| カテゴリ | エージェント開発IDE（VS Code系） | エージェント構築ライブラリ（Python） |
| 使い方 | アプリを開いて会話する | `pip install google-antigravity` してコードを書く |
| ローカルLLM対応 | 対応はするが設定UI経由 | **本記事の対象**。2つのConfigで明示的に指定 |
| 向いている人 | IDE完結で開発したい人 | エージェントを**コードに組み込みたい**人 |

「AntigravityでローカルLLM」と検索すると、IDEの設定画面の話とSDKの話が混ざって出てくる。本記事は**SDK**の話だ。

### ローカル実行も2ルートある

| 項目 | `LiteRTAgentConfig` | `LocalOpenAIAgentConfig` |
|------|---------------------|--------------------------|
| 接続先 | `.litertlm` ファイルを直接ロード | Ollama / LM Studio / vLLM 等のOpenAI互換サーバ |
| サーバ管理 | SDKが起動・管理してくれる | 自分でサーバを立てる |
| 対応モデル（2026-09時点） | **Gemma 4 26B A4B のみ** | サーバが載せられる任意のモデル |
| 推奨メモリ | **24GB以上** | モデル次第（小さければ16GBでも可） |

:::message alert
公式docsに明記されている注意: **`litert-lm serve` に `LocalOpenAIAgentConfig` で接続してはいけない**。その用途には `LiteRTAgentConfig` を使う。
:::

---

## なぜ2ルートが存在するのか — 分岐の経緯

公式ブログが挙げるローカル対応の設計意図は4つある（[公式発表](https://developers.googleblog.com/introducing-support-for-local-ai-models-in-the-antigravity-sdk/)）。①API費用ゼロ。②データを端末に留保するコンプライアンス対応。③オフライン耐性。④クラウドとローカルのハイブリッド。

2つのConfigに分かれている理由は、**「オンボードしたい人」と「資産を活かしたい人」で最適解が違う**からだ:

- `LiteRTAgentConfig` は、**LiteRT（旧TensorFlow Lite）形式に最適化されたモデルを最初から用意して配る**路線。Gemma 4 26B A4B（MoE、生成時アクティブ4B）専用の最適化をSDK側が背負う。その代わりモデル選択の自由度は下がる
- `LocalOpenAIAgentConfig` は、**すでにローカルでLLMサーバを運用している人全員**を取り込む路線。公式は「plug-and-play support」と呼び、バックエンドを替えても「agent orchestration, tools, and workflows completely unchanged」（オーケストレーション・ツール・ワークフローは完全に不変）と説明する。**既存のエージェントコードから `base_url` を差し替えるだけでローカルに落ちる**

なぜLiteRT最適化が26B A4B一点なのか。公式は明言していないが、A4BというMoE構成（総26B・アクティブ4B）が**メモリを食う割に生成が軽い**、オンボデバイス実行に向いたバランスだからだと読める。逆に言えば、16GB Macが公式ルートで使えるのは「LiteRT版の小型モデルが出るまで待つ」か「OpenAI互換ルートで小さいモデルを載せる」かの二択だ。

:::message
この使い分けを知っていると、今後LiteRT対応モデルが追加されたとき（おそらく小型Gemmaから）に「乗り換えるべきか、Ollamaのままか」を自分で判断できる。
:::

---

## 前提知識：なぜローカルエージェントなのか

エージェントワークフローは**トークンを大量に消費する**。多段タスクでは1回の実行で数万トークンが流れ、APIコストとレート制限が実用の壁になる。さらにエージェントはファイル内容やログをプロンプトに乗せるため、**閉域網ではそもそもクラウドAPIに届かない**。

公式が紹介する実証例（Architect-Builderパターン）が示すのは、この問題の解き方だ: クラウドのGemini 3.8 Flashが計画役、**ローカルのGemma 4群が実行役**。コード監査タスクで、クラウドに送ったのは**95トークン**（ファイル名と指示のみ）、**全体の97.2%（3,322トークン）はローカル実行**だった（[公式発表](https://developers.googleblog.com/introducing-support-for-local-ai-models-in-the-antigravity-sdk/)）。閉域なら「計画だけ人間が書いて、実行をローカルに寄せる」——16GB Macはこの実行側に入れる余地がある。

---

## セットアップ（16GB Mac実測）

### SDKのインストール

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install google-antigravity litert-lm
```

### Ollama側の準備（16GB Macの現実解）

```bash
# gemma4:12b を取得（DL 7.6GB）
ollama pull gemma4:12b
```

26BをLiteRTで読む場合は、16.8GBのモデルを別途インポートする:

```bash
litert-lm import --from-huggingface-repo=litert-community/gemma-4-26B-A4B-it-litert-lm \
  gemma-4-26B-A4B-it-gpu.litertlm gemma4-26b
```

:::message alert
**16GB Macではこの26Bルートは推奨しない。** 公式docsの要件は「24GB以上のVRAMまたはユニファイドメモリを推奨」。16.8GBのモデルファイルを16GBメモリのマシンに載せる設計はスワップ前提になる（実測は後述の可否表へ）。
:::

### 落とし穴（macOS）

`litert-lm import` がSSL証明書エラーで失敗する場合は公式の回避策を使う:

```bash
pip install certifi
export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())")
```

---

## 使い方 — 2ルートのコード

### Ollamaルート（16GB Macの本命）

```python
from google.antigravity import Agent, LocalOpenAIAgentConfig

config = LocalOpenAIAgentConfig(
    model="gemma4:12b",
    base_url="http://localhost:11434/v1",
).lightweight()

async with Agent(config) as agent:
    response = await agent.chat("What files are in the current directory?")
    async for token in response:
        print(token, end="", flush=True)
```

`.lightweight()` を付けるのが公式の推奨パターン。ローカルモデル向けにツールとプロンプトを最適化し、64kのKV-cacheに合わせたコンテキスト圧縮が自動設定される。

### ファイル編集を許可する場合

```python
config = LocalOpenAIAgentConfig(
    model="gemma4:12b",
    base_url="http://localhost:11434/v1",
).lightweight()

async with Agent(config) as agent:
    # workspaces と policies を明示する
    response = await agent.chat(...)
```

---

## 16GB Macの実測可否表 — 回るのはどこまでか

本記事のコマンドはMacBook Air M5 16GB / macOS / Ollama 0.34.3 / gemma4:12b / google-antigravity 0.1.18 で実行して確認している（2026-09-25時点）。

### 可否表

| やりたいこと | 16GB Macで可能か | 実測・根拠 |
|---|---|---|
| Agent起動 | ✅ | **1.9s** |
| ディレクトリのファイル列挙（ツール実行） | ✅ | **32.3s**。正しくファイル一覧を生成 |
| ファイル作成・編集（workspaces指定） | ✅ | **16.7s**。「hello.txtを作ってDONEと返せ」で**実際にファイルが生成されていた**（筆者が中身を開いて確認） |
| 日本語の応答 | ✅ | 1行生成 **9.3s** |
| Gemma 4 26B（LiteRTルート） | ❌ | **要件24GB以上・DL 14.7GiB**。DLが終盤でConnection resetになり失敗（実測）。16GB機はスワップ前提で設計として成立しない |
| ハイブリッド（計画クラウド・実行ローカル） | ✅（クラウド側のみ閉域外） | 実行側を本構成に置ける |

### 実行時のリソース

| 指標 | 値 |
|---|---|
| gemma4:12b の実メモリ | 8.1GB |
| プロセッサ | **100% GPU（スワップなし）** |
| コンテキスト長 | 32768 |
| Agent動作中の空きメモリ | **10%** |

:::message alert
空きメモリ10%は「動いたが張り付いた」という意味だ。私の環境ではAgent実行中、他のアプリを開き直すと即座にスワップに落ちる感触だった。16GB Macでgemma4:12bをAgentに使うときは、**重いアプリを閉じてから実行する**こと。
:::

### 体感のまとめ

遅い。1タスク16〜32秒は、クラウドAPIの感覚からすると10倍以上遅い。ただし**閉域で動くエージェントは「遅くてもゼロ」との比較**であり、日次の定型処理（ログ要約・ファイル整理・簡単なパッチ作成）なら実用圏内と判断した。長文生成や反復の重いタスクは16GBでは厳しい。

なお26Bルートは、まず14.7GiBのモデルDL自体が壁になる。私の環境では**DLが終盤でConnection resetになり失敗した**（再試行も不安定）。DLが通っても24GB推奨のモデルを16GBメモリに載せる設計はスワップ前提で、「16GBなら12B以下で組む」と決めてかかる方が早い。

---

## 5つのワークフローパターン

### パターン1: 100%ローカル完結（16GB Mac本命）

Ollama + gemma4:12bだけの構成。コスト$0・完全オフライン。閉域網でもそのまま動く。

### パターン2: Architect-Builder（公式推奨のハイブリッド）

クラウドのGemini 3.8 Flashに計画させ、実行をローカルGemma 4に任せる。公式デモではトークンの97.2%がローカルに流れた。閉域でない環境ならコスト最適化として、閉域なら計画だけ人間が書いて実行をローカルに寄せる。

### パターン3: バックエンド差し替え（既存資産の再利用）

すでにOpenAI互換APIで書いたエージェントコードがあるなら、`base_url` を `http://localhost:11434/v1` に替えるだけでローカルに落ちる。LM Studioなら `http://localhost:1234/v1`。

### パターン4: 閉域網での運用

インターネットに出られない環境では、モデルファイルとvenvを構成管理で配る。`litert-lm import` はネット接続が要るため、**事前に取得したモデルファイルを配布**する。

### パターン5: 異動後に残す構成

エージェントの構成は「venv + requirements + Ollamaのモデル指定 + 設定スクリプト」で再現可能にしておく。後任は `pip install -r requirements.txt` と `ollama pull gemma4:12b` だけで同じ環境が立つ。

---

## 公式のベストプラクティス

> Don't use `LocalOpenAIAgentConfig` to connect to `litert-lm serve`. Use `LiteRTAgentConfig` instead.
>
> — [公式docs / local-models](https://antigravity.google/docs/sdk/local-models/)

### 推奨1: `.lightweight()` を付ける

ローカルモデル向けにツール・プロンプトが最適化され、コンテキスト圧縮のしきい値が既定設定される。付けないと小モデルがフルのツールセットとシステム指示に呑まれる。

### 推奨2: `model_path` は絶対パスで

チルダ `~` は自動展開されない。`os.path.expanduser()` を通す。

### 推奨3: ハイブリッドで「計画はクラウド・実行はローカル」

トークン効率を最大化する公式の推奨構成。全ローカルより、強いモデルに計画だけ任せる方がトークンあたりの成果が大きい。

---

## やりがちなアンチパターン 7選

### 1. 26Bを16GBマシンに無理投入する

DL 16.8GB・推奨24GB。要件不足を「量子化すれば何とかなる」と楽観せず、**可否表の1行目として「26B不可」を先に確定する**。16GBは12B以下で組む。

### 2: チルダパスでモデルが見つからない

`model_path="~/litert..."` は展開されずFile Not Foundになる。絶対パスか `os.path.expanduser()` を使う。

### 3: macOSのSSLエラーで詰まる

`litert-lm import` の証明書検証エラーは、`certifi` を入れて `SSL_CERT_FILE` をexportすれば解ける（公式記載の回避策）。

### 4: `litert-lm serve` に `LocalOpenAIAgentConfig` で接続する

公式docsが明確に禁止している。この用途は `LiteRTAgentConfig` のみ。

### 5: `policy.allow_all()` を本番構成で使い続ける

公式例は検証用の簡易設定。実運用では必要なワークスペースと権限に絞る。**ローカル実行でもプロンプトインジェクションのリスクは消えない**——エージェントが読むファイルに悪意のある指示が入りうる点は、ローカルでも変わらない。

### 6: `.lightweight()` なしで小モデルにフルツールを渡す

12Bクラスはフルのシステム指示とツール群に埋まる。軽量プリセットのコンテキスト圧縮（64k KV-cache基準）に任せる。

### 7: エージェントの多段ターンでコンテキストを膨張させる

多段タスクは毎ターン履歴が積まれ、小モデルはすぐ圧縮しきい値を踏む。**1エージェント1ジョブ**に分割する。16GBの遅い生成速度では、分割は速度面でも有利（1回の長い生成より複数の短い生成のほうが中断・再開しやすい）。

---

## 関連ツール比較

| バックエンド | 強み | 弱み | 向いている人 |
|---|---|---|---|
| Ollama | 導入が最短。モデル管理が楽。Mac対応良好 | 高速化の自由度は中程度 | **16GB Macの第一候補**（本記事の構成） |
| LM Studio | GUIで試せる。MLX系モデルも扱える | サーバ運用はOllamaの後発 | 手元で対話しながら確認したい人 |
| vLLM | 高スループット。本格運用向け | Macでは動かしにくい。CUDA前提 | GPUサーバを持っている人 |
| LiteRT（litert-lm） | オンボデバイス特化。SDKが管理 | **26B A4B限定**。24GB推奨 | 公式最適化に乗りたい人 |

---

## 実践チェックリスト（16GB Mac向け）

### セットアップ時
- [ ] venvで独立環境を作る（python3.14で動作確認済み）
- [ ] `ollama pull gemma4:12b`（7.6GB・空きディスクを確認）
- [ ] macOSでSSLエラーが出たら `certifi` + `SSL_CERT_FILE` の回避策を適用
- [ ] `base_url` は `http://localhost:11434/v1`（`/v1` 忘れに注意）

### 運用時
- [ ] 重いアプリを閉じてからAgentを実行（空きメモリ10%まで張り付く）
- [ ] `.lightweight()` を付ける
- [ ] 1エージェント1ジョブで分割
- [ ] `ollama ps` でGPU100%かつスワップしていないことを確認

### トラブル時
- [ ] `ollama ps` のPROCESSORが `100% GPU` でない → モデルサイズか空きメモリを疑う
- [ ] 応答が返らない → `~/.litert-lm/` とモデルパスの展開を確認
- [ ] タスクが途中で止まる → コンテキスト圧縮しきい値。ジョブを分割

---

## まとめ

- **16GB MacでもAntigravity SDKのローカルエージェントは動く**: Ollama + gemma4:12b でファイル作成タスクを完遂（実測16.7s、生成物を確認済み）
- **26B（LiteRT）は16GB機には載らない**: DL 16.8GB・24GB推奨。要件不足は「不可」と最初に断定する
- **動いた構成**: MacBook Air M5 16GB / Ollama 0.34.3 / gemma4:12b（8.1GB・100% GPU） / google-antigravity 0.1.18
- **遅さは「ゼロとの比較」**: 1タスク16〜32秒は実用圏内。ただしメモリは空き10%まで張り付く
- **公式の設計思想はハイブリッド**: 計画はクラウド・実行はローカルで97.2%のトークンをローカルに流せる

「閉域だからエージェントは無理」という前提は、2026年9月23日で古くなった。16GB Macの「実行役」として、まず1つの定型ジョブを回すところから始めればいい。

---

## 参考リンク

- [公式発表: Introducing Support for Local AI Models in the Antigravity SDK](https://developers.googleblog.com/introducing-support-for-local-ai-models-in-the-antigravity-sdk/)
- [公式docs: Local models — Google Antigravity](https://antigravity.google/docs/sdk/local-models/)
- [litert-community/gemma-4-26B-A4B-it-litert-lm（Hugging Face）](https://huggingface.co/litert-community/gemma-4-26B-A4B-it-litert-lm)

※本記事は2026年9月25日時点の情報に基づく。Antigravity SDKのローカル対応は発表3日目の新機能であり、今後のバージョンで挙動が変わる可能性がある。
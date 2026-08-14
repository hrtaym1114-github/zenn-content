---
title: "【2026年最新】DeepSeek HarnessをローカルLLMで動かす完全ガイド — 「モデルは差し替えられるか」から実測値まで"
emoji: "🔌"
type: "tech"
topics: ["DeepSeek", "Ollama", "LLM", "AIエージェント", "TypeScript"]
published: true
---

:::message
本記事は **2026年8月14日時点** の検証結果です。DeepSeek Harness は developer preview であり、公式 README も「**THERE WILL BE COMPATIBILITY-BREAKING CHANGES**」と明記しています。設定ファイルのスキーマは変わる前提で読んでください。検証バージョンは `@deepseek-ai/dsh@0.1.0-rc.6`（2026-08-13 公開）です。
:::

## この記事で分かること

2026年8月13日、DeepSeek が OSS のエージェントハーネス **DeepSeek Harness（`dsh`）** を公開しました。MIT ライセンス、TypeScript/Node.js 製、「**Everything is a Plugin**」を掲げた設計で、公開から1日で GitHub 79,000 stars を超えています（2026-08-14 時点の実測値）。

Claude Code の OSS 代替として紹介されることが多いのですが、日本語圏の技術者が最初に知りたいのは機能一覧ではないはずです。**中国のモデルベンダーが作ったハーネスに、自分のソースコードを流していいのか。** その判断は「モデルを DeepSeek 以外に差し替えられるか」で決まります。差し替えられるなら、ハーネスはローカルで動く実行基盤であり、コードは外に出ません。差し替えられないなら、それは実質 DeepSeek API のクライアントです。

ところが公式のモデル設定ガイドには、**Ollama もローカルLLMも一言も出てきません**。カタログにあるのは OpenAI、Anthropic、DeepSeek などの商用プロバイダだけです。

この記事では、実際に手元の Mac（Apple M5 / メモリ 16GB / macOS 26.5.2）で Ollama を繋いで動かし、以下を確定させます。

- モデルは差し替え可能か（結論: **可能**。ただし公式に手順がないので自分で書く）
- そのための `settings.yaml` の完全な書き方（動作確認済みの全文を掲載）
- 何もしないと必ず踏む罠（**認証キーなしのローカルサーバは起動しない**）
- **どのサイズのモデルなら実用になるのか**（ここが最大の落とし穴。30Bクラスは失敗しました）

---

## 【混乱ポイント】LLMアダプタが2つある — `llm-deepseek` と `llm-pi-ai`

最初に整理しておくべき点はここです。DeepSeek Harness には **LLMアダプタが2種類同梱されており、どちらを使うかでできることが根本的に変わります**。しかも `web` プロファイルの既定構成には**両方**が入っているため、リポジトリを眺めただけでは違いが見えません。

`packages/llm/README.md` の記述を整理すると、こうなります。

| パッケージ | 役割 | ローカルLLMを繋げるか |
|---|---|---|
| `llm-deepseek` | DeepSeek 直結アダプタ | ❌ 不可（DeepSeek専用） |
| `llm-pi-ai` | 汎用マルチプロバイダアダプタ | ✅ **これを使う** |
| `llm` | LLMサービスの抽象定義とストリーム語彙 | （土台） |
| `llm-retry` | プロバイダ単位のリトライ | （周辺） |
| `token-meter` | トークン計測 | （周辺） |

**ローカルLLMを繋ぐ話は、全部 `llm-pi-ai` の話です。** これは `@earendil-works/pi-ai` を裏に持つ汎用アダプタで、公式 README にこう書かれています。

> A route naming an installed pi-ai provider inherits its endpoint, wire protocol, and model catalog as defaults and overrides them field by field; **a route pi-ai does not ship is declared outright, so an OpenAI-compatible gateway, a self-hosted server, or a provider newer than the installed catalog is configuration rather than a code change.**
>
> — [packages/llm/llm-pi-ai/README.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/llm/llm-pi-ai/README.md)

引用の後半が決定的です。**「self-hosted server は code change ではなく configuration」** — つまり、Ollama のようなセルフホストの OpenAI互換サーバは、プラグインを書かずに設定ファイルだけで繋がる、と公式が設計意図として明言しています。Ollama という単語こそ出てきませんが、道は最初から用意されています。

もう1点、混同しやすい用語を潰しておきます。

| 用語 | 意味 |
|---|---|
| **route（ルート）** | プロバイダ1件を指すキー。`ollama` のように自分で命名する |
| **catalog route** | pi-ai が最初から知っているプロバイダ（openai, anthropic 等） |
| **hand-declared route** | pi-ai が知らないので全部自分で書くルート ← **Ollama はこちら** |
| **profile（プロファイル）** | `web` / `headless` などの起動形態。`$DSH_HOME/profiles/` 配下 |

`profile` はモデル設定とは無関係の「起動形態」の話です。ここを混同すると設定ファイルの置き場所を延々探すことになります。

---

## 前提知識 — ハーネスとは何か、なぜモデル差し替えが論点なのか

ハーネス（harness）とは、モデルと「ツール・ファイル・実行環境」の間に立つ実行基盤層のことです。ツール呼び出し、コンテキスト管理、セッション永続化、サンドボックス、エラー処理を担います。Claude Code や Codex CLI が担っている層と言えば早いでしょう。

DeepSeek Harness が特異なのは、**その全構成要素をプラグインとして外に出した**点です。モデル、ツール、スキル、セッション、サンドボックス、ストレージ、ループ、スケジューリング、UI — すべてがプラグインで、ハーネス本体はそれらの合成にすぎません。基盤には [Cordis](https://github.com/cordiverse/cordis) というプラグインシステムが使われています。

この設計だからこそ「モデルだけ差し替える」が成立します。逆に言えば、**モデルがプラグインなら、DeepSeek のモデルを使わない構成も正当な使い方**ということです。

そしてこれは、コードの秘匿性を気にする現場にとって決定的な意味を持ちます。ハーネスは MIT ライセンスのローカル実行バイナリです。推論先をローカルの Ollama に向ければ、**ソースコードもプロンプトも一切ネットワークに出ません**。ハーネスの出自と、データの行き先は、切り離して評価できます。

---

## セットアップ — 起動して構造を把握する

Node.js があれば準備は不要です。まず起動して構造を確認します。

```sh
npx @deepseek-ai/dsh web
```

Web UI が `http://127.0.0.1:3080` で立ち上がります。

CLI としては `dsh` が「プロファイルを起動するランチャー」で、以下の形を取ります。

```sh
dsh --profile web          # Web UI（dsh web と同じ）
dsh --profile headless "run the tests"   # 1タスク実行して終了
dsh --profile tui          # TUI
```

検証用に、既存環境を汚さないよう `DSH_HOME` を切り替えるのが安全です。

```sh
export DSH_HOME=/path/to/dsh-test/dshhome
```

初回起動で `$DSH_HOME/profiles/{web,headless}/` が生成されます。ここで**最重要のデバッグコマンド**を押さえておきます。

```sh
dsh --profile headless --dump-default-config
```

構成済みのプラグインツリーが全部 YAML で出ます。筆者の環境では 81 個のプラグインが並び、その中に既定モデルの指定が入っていました。

```yaml
- id: agent-default-model
  name: '@deepseek-ai/dsh-agent-default-model'
  config:
    provider: deepseek-official
    model: deepseek-v4-flash
```

**既定は `deepseek-official` / `deepseek-v4-flash`。** これを自分のルートに向け直すのが、この記事の作業の全体像です。

---

## Ollama ルートを追加する — 動作確認済みの `settings.yaml` 全文

設定は `$DSH_HOME/settings.yaml` に書きます。**このファイルは初期状態では存在しないので、自分で作成します。** 以下は筆者の環境で実際に動作した全文です。

```yaml
llm-pi-ai:
  providers:
    ollama:
      displayName: Ollama (local)
      api: openai-completions
      baseURL: http://127.0.0.1:11434/v1
      apiKeyEnv: OLLAMA_API_KEY
      streamIdleTimeoutMs: 1800000
      defaultContextWindow: 32768
      defaultMaxTokens: 4096
      models:
        - id: qwen3-coder:30b
          name: Qwen3 Coder 30B
          contextWindow: 32768
          maxTokens: 4096
        - id: qwen3:4b
          name: Qwen3 4B
          contextWindow: 32768
          maxTokens: 4096
agent-default-model:
  provider: ollama
  model: qwen3:4b
```

各フィールドの意味を、公式仕様に基づいて説明します。

| フィールド | 役割 | 注意点 |
|---|---|---|
| `ollama:` | ルート名。自分で決める | セッションや既定モデルがこの名前を参照するため**後から変更できない**（公式に「Provider ID is permanent」と明記） |
| `api` | ワイヤプロトコル | Ollama の `/v1` は OpenAI Chat Completions 互換なので `openai-completions` |
| `baseURL` | エンドポイント | 末尾の `/v1` が必要。パスは前置詞として保持される |
| `apiKeyEnv` | 認証キーの**参照名**（キー本体ではない） | **省略不可。詳細は次項** |
| `models` | モデル一覧 | hand-declared route では**必須**。`ollama list` の名前と完全一致させる |
| `defaultContextWindow` | 未記述モデルの既定 | 既定値は 262,144。ローカルには過大なので必ず下げる |
| `streamIdleTimeoutMs` | ストリーム無通信のタイムアウト | 既定5分。ローカル推論は遅いので延ばす |

起動して疎通確認します。

```sh
cd /path/to/workdir
DSH_HOME=$DSH_HOME OLLAMA_API_KEY=ollama \
  npx @deepseek-ai/dsh --profile headless "Reply with exactly the word: PONG"
```

```
PONG
```

**繋がりました。** DeepSeek のAPIキーは一切設定していません。

### ツール呼び出しまで動くか

エージェントとして機能するには、テキスト生成だけでなくツール呼び出しが動く必要があります。作業ディレクトリにファイルを置いて試します。

```sh
echo 'The secret code is ORANGE-7742.' > secret.txt

DSH_HOME=$DSH_HOME OLLAMA_API_KEY=ollama \
  npx @deepseek-ai/dsh --profile headless \
  "Read the file secret.txt in the current directory and tell me the secret code it contains."
```

```
The secret code contained in `secret.txt` is **ORANGE-7742.**
```

所要 **1分38秒**（`npx` のダウンロード時間込み、`qwen3:4b`）。ローカルの 4B モデルが、ハーネスのファイル読み取りツールを正しく呼び出して回答しました。**「モデルは差し替えられるか」への答えは、ツール呼び出しまで含めて Yes です。**

:::message alert
**認証キーなしのローカルサーバは起動しません。** これが最初に踏む罠です。

Ollama は認証を要求しないので `apiKeyEnv` を消したくなりますが、消すと失敗します。実測結果:

```
dsh: PI_AI_ERROR: No API key for provider: ollama
```

公式 README も既知の制約として明記しています。

> **An unauthenticated route depends on its protocol** — naming no credential resolves the route as configured-but-keyless, but pi-ai's OpenAI-compatible implementation still requires an API key or an `Authorization` header, so **a keyless local server needs a placeholder credential referenced by `apiKeyEnv`** or an `Authorization` entry in `headers`.

対処は簡単で、**中身は何でもいいのでダミーの環境変数を渡す**だけです（上の例では `OLLAMA_API_KEY=ollama`）。値は検証されません。
:::

---

## 5つの設定パターン

用途別に、そのまま使える設定を並べます。

### パターン1: Ollama を丸ごと繋ぐ（基本形）

前掲の全文がこれにあたります。`models` に使うモデルを列挙するのが基本です。**`ollama list` の表示名と完全一致**させてください。`qwen3-coder:30b` のようにタグまで含めます。一致しない場合、リクエスト前に `LlmError('UNKNOWN_MODEL')` で落ちます。

### パターン2: LM Studio / llama.cpp サーバに繋ぐ

OpenAI互換サーバなら同じ形で繋がります。ポートとモデルIDを変えるだけです。

```yaml
llm-pi-ai:
  providers:
    lmstudio:
      displayName: LM Studio
      api: openai-completions
      baseURL: http://127.0.0.1:1234/v1
      apiKeyEnv: LMSTUDIO_API_KEY   # ダミーで可
      models:
        - id: your-model-id
```

### パターン3: ローカルと商用を併用し、用途で切り替える

ルートは複数宣言でき、`providers` は**プロバイダ単位でマージ**されます。機密性の高い作業はローカル、重い推論は商用、という使い分けができます。

```yaml
llm-pi-ai:
  providers:
    ollama:
      api: openai-completions
      baseURL: http://127.0.0.1:11434/v1
      apiKeyEnv: OLLAMA_API_KEY
      models:
        - id: qwen3:4b
    anthropic:            # カタログルート。エンドポイントもモデル一覧もpi-ai任せ
      apiKeyEnv: ANTHROPIC_API_KEY
agent-default-model:
  provider: ollama
  model: qwen3:4b
```

`anthropic` のようなカタログルートは、`apiKeyEnv` だけで完結します。エンドポイント・プロトコル・モデル一覧は pi-ai の内蔵カタログが供給するためです。

### パターン4: 社内ゲートウェイ経由で使う

企業のLLMゲートウェイも hand-declared route として同じ形で書けます。推論方言（thinking の送り方）がゲートウェイのURLから判別できない場合に備え、`compat.thinkingFormat` で明示できます。

```yaml
llm-pi-ai:
  providers:
    corp-gateway:
      displayName: Corp Gateway
      apiKeyEnv: CORP_GATEWAY_API_KEY
      api: openai-completions
      baseURL: https://gateway.example.internal/v1
      compat:
        thinkingFormat: deepseek
      models:
        - id: internal-large
          contextWindow: 65536
          maxTokens: 8192
```

### パターン5: 画像を扱うモデルを宣言する

**手書きで宣言したモデルは、明示しない限り text-only 扱いです。** 画像を添付すると送信前に拒否されます。Web UI のフォームにこの項目はないため、`settings.yaml` に直接書く必要があります。

```yaml
      models:
        - id: llava-model
          input: [text, image]
```

なお、この宣言は**エンドポイントに問い合わせず、そのまま信じられます**。過大申告すると送信後にプロバイダ側で弾かれ、しかも画像はセッションログに残るため同じ失敗を繰り返します。回復には別モデルへの切り替えか新規セッションが必要です。

---

## 公式が定める設計原則

公式ドキュメントから、設定を書く上で守るべき原則を引用します。ここを外すと、原因の分かりにくい失敗を踏みます。

**1. 認証情報を設定ファイルに書かない**

> `apiKeyEnv` is a credential *reference* resolved per request, so **no secret enters this file**.

`settings.yaml` に入るのは環境変数名だけです。Web UI から保存したキーは `$DSH_HOME/.credentials.yaml` に格納され、UI 側には二度と平文が返りません（write-only）。

**2. `models` を書いたらカタログは「置換」される（追加ではない）**

> A profile's `models` list ***replaces*** the route's installed catalog rather than extending it.

カタログルートのモデルを1つだけ直したいなら `models` ではなく `modelOverrides` を使います。`models` を書いた瞬間、そのルートで使いたいモデルは**全部**列挙する義務が生じます。

**3. 変更は再起動不要、次のリクエストから効く**

> Model changes take effect on the next request without restarting the server.

アダプタは設定を起動時に固定せず、操作のたびに読み直す設計です。

**4. 設定は「書いた場所」で拒否される**

> an unserviceable profile is refused **where it is written**

不正な設定は保存時点で `settings-rejected` として弾かれ、保存されません。すでに保存済みのセクションが壊れた場合も、設定シームが直前の正常値を保持するため、環境ごと死ぬことはありません。

**5. `headers` に認証情報を書かない**

> **`headers` can carry a credential the redactor never sees** — the profile's `headers` dict is plain strings, so `Authorization` or `api-key` set there is returned verbatim by a redacted `describe()`.

`headers` に直接 `Authorization` を書くと、マスキング対象外となり UI に平文で表示されます。必ず `apiKeyEnv` を使ってください。

---

## やりがちなアンチパターン7選

実際に踏んだもの、公式が制約として明記しているものを挙げます。

### 1. `apiKeyEnv` を省略する

前述の通り `PI_AI_ERROR: No API key for provider` で即死します。ダミー値で構わないので必ず設定します。**ローカルLLM利用者が最も高確率で踏む罠です。**

### 2. ルート名を後から変える

Provider ID は永続的です。セッション、既定モデル、認証情報の参照がすべてこの名前を使っています。改名するには「新ルートを追加して旧ルートを削除」しか手段がありません。最初に決め切ってください。

### 3. `defaultContextWindow` を放置する

未設定時の既定は **262,144** です。ローカルの小型モデルにこの値が適用されると、実際には収まらないコンテキストを「収まる」と判断してしまいます。使うモデルの実際の値に合わせて必ず下げます。

### 4. モデルIDをタグなしで書く

`qwen3-coder` と書いても `ollama list` の `qwen3-coder:30b` とは一致せず、`UNKNOWN_MODEL` になります。タグまで完全一致が必要です。

### 5. 1つのルートに複数プロトコルを混ぜようとする

> **One wire protocol per route** — `api` applies to the whole route.

`api` はルート全体に効きます。プロトコルの違うモデルを同居させることはできません。ルートキーを分けるのが公式の回避策です。

### 6. `models` と `modelOverrides` を併用する

`models` はカタログを置換するため、その上で `modelOverrides` を書くと**スキップではなく拒否**されます。存在しないモデルIDを指定した場合も同様に拒否されます（黙って無視されるより、タイポを探す時間が減るという設計判断です）。

### 7. `~/.aws/credentials` などのローカル認証情報に期待する

> **Provider-native discovery reads the process environment only** — It reads no local credential directory.

環境変数しか読みません。ファイルに置いた認証情報は見えないため、Bedrock/Vertex 系を使う場合は環境変数の明示が必要です。

---

## 【実測】どのサイズのモデルなら実用になるか — 8,225トークンの壁

ここが本記事で最も重要なパートです。**「繋がる」と「使える」は別問題でした。**

検証環境: Apple M5 / メモリ 16GB / macOS 26.5.2 / Ollama 0.32.9

| モデル | サイズ | 同一タスク（ファイル読み取り）の結果 |
|---|---|---|
| `qwen3:4b` | 2.5GB | ✅ **成功**（1分38秒） |
| `qwen3-coder:30b` | 18GB（Q4_K_M / MoE 30.5B） | ❌ **失敗**（5分でHTTP 500、2回とも） |

30B が落ちた原因は、Ollama 側のサーバログに明確に残っていました。

```
slot operator(): id 0 | task 8 | new prompt, n_ctx_slot = 32768, n_keep = 4, task.n_tokens = 8225
slot print_timing: id 0 | task 8 | prompt processing, n_tokens = 512,  progress = 0.25, t = 103.26 s / 4.96 tokens per second
slot print_timing: id 0 | task 8 | prompt processing, n_tokens = 1024, progress = 0.31, t = 194.24 s / 5.27 tokens per second
[GIN] 2026/08/14 - 17:47:53 | 500 | 4m59s | 127.0.0.1 | POST "/v1/chat/completions"
```

読み解くべき数字は2つです。

**① `task.n_tokens = 8225`**

「ファイルを1つ読め」という短い指示に対し、実際にモデルへ渡ったプロンプトは **8,225トークン**でした。ユーザーの指示は20トークン程度ですから、**残りのほぼ全部がシステムプロンプトとツール定義**です。ハーネスは多数のツール（ファイル操作、シェル、検索、TODO、サブエージェント等）をモデルに提示するため、**何を頼んでも最低8,000トークン前後が固定費として乗ります。**

**② プロンプト処理 4.96〜5.27 tok/s**

前処理（prompt processing）の速度がこれです。8,225 ÷ 5 ≒ **1,645秒 ≒ 27分**。**回答を1文字も生成しないうちに27分**かかる計算で、Ollama 側の5分制限に当然引っかかります。

`streamIdleTimeoutMs` を30分に延ばしても解決しません。これはハーネス側のタイムアウトであり、上限に達しているのは Ollama サーバ側だからです。仮に両方延ばしたとしても、1往復に30分かかるエージェントは実用になりません。

:::message alert
**ボトルネックは生成速度ではなくプロンプト処理速度です。**

ローカルLLMの評価では生成速度（tok/s）ばかり見がちですが、エージェント用途では話が違います。毎ターン8,000トークン超を前処理する必要があるため、**prompt processing のスループットが実用性を直接決めます。**

`qwen3-coder:30b` は 21.9GB のモデルで、VRAM には 11.5GB しか載りませんでした（16GB機）。メモリに収まりきらないMoEモデルは、前処理が桁で遅くなります。
:::

**実用ラインの目安（16GB機での実測に基づく）**

| 判定 | 条件 |
|---|---|
| ✅ 実用 | メモリに完全に載る小型モデル（4B級 / 3GB前後）。1タスク1〜2分 |
| ⚠️ 要検証 | 7〜14B級。前処理速度を必ず先に測る |
| ❌ 非現実的 | メモリに載り切らないモデル。前処理だけで数十分 |

判断は「モデルサイズ」ではなく「**メモリに全部載るか**」で行ってください。載らない瞬間に、エージェント用途としては崩壊します。

**先に測るべき数字はこれです。**

```sh
# 8,000トークン級の前処理速度を確認してから本番投入する
tail -f ~/.ollama/logs/server.log | grep "prompt processing"
```

この値が **50 tok/s を下回る**なら、8,000トークンの前処理に3分弱かかります。エージェントとしては厳しい水準です。

---

## 関連ツール比較

ローカルLLMでコーディングエージェントを動かす選択肢を並べます（※2026年8月時点）。

| ツール | ライセンス | ローカルLLM | 特徴 |
|---|---|---|---|
| **DeepSeek Harness** | MIT | ✅ 設定のみで可 | 全要素プラグイン。設定の自由度は随一だが developer preview |
| Claude Code | 商用 | ❌ | 完成度・安定性は最高。Anthropic API 前提 |
| Cline / Roo Code | Apache-2.0 | ✅ | VS Code 拡張。導入は最も容易 |
| Aider | Apache-2.0 | ✅ | CLI特化・Git統合が強い |
| OpenHands | MIT | ✅ | サンドボックス実行が本格的 |

DeepSeek Harness を選ぶ理由があるとすれば、**「ハーネス自体を改造したい」場合**です。モデルもツールもループもプラグインなので、独自のツールセットや実行ループを組んだ社内エージェント基盤を作るには、この分解度は他にない強みになります。

逆に「ローカルLLMでコードを書きたいだけ」なら、現時点では Cline や Aider の方が導入コストは低いです。DeepSeek Harness は破壊的変更が予告されており、**設定ファイルを書き直す前提で付き合う必要があります。**

---

## 実践チェックリスト

```
□ Node.js を用意した
□ DSH_HOME を検証用ディレクトリに分離した
□ dsh --profile headless --dump-default-config で既定構成を確認した
□ $DSH_HOME/settings.yaml を新規作成した（初期状態では存在しない）
□ llm-pi-ai の providers にルートを追加した（llm-deepseek ではない）
□ api: openai-completions と baseURL の末尾 /v1 を確認した
□ apiKeyEnv をダミー値でも必ず設定した ← 最頻の罠
□ models のモデルIDを ollama list とタグまで完全一致させた
□ defaultContextWindow を実際の値まで下げた（既定262,144は過大）
□ agent-default-model を自分のルートに向けた
□ headless で疎通確認した（PONG テスト）
□ ツール呼び出しを確認した（ファイル読み取りテスト）
□ 8,000トークン級の prompt processing 速度を測った ← 実用性の分岐点
□ 破壊的変更に備えて settings.yaml をバージョン管理下に置いた
```

---

## まとめ

1. **モデルは差し替えられます。** `llm-pi-ai` アダプタに OpenAI互換ルートを宣言すれば、Ollama のローカルモデルでツール呼び出しまで動作しました。DeepSeek のAPIキーは不要で、コードは一切外に出ません。
2. **公式ガイドに手順はありません。** カタログにあるのは商用プロバイダのみで、Ollama の記述はゼロです。`settings.yaml` を自分で書く必要があります。
3. **最大の罠は認証キーです。** Ollama は認証不要ですが、`apiKeyEnv` を省くと `PI_AI_ERROR: No API key` で起動しません。ダミー値で回避できます。
4. **本当の壁はモデルサイズです。** ツール定義だけで毎ターン8,000トークン超が乗るため、prompt processing が遅いモデルは前処理だけで数十分かかります。16GB機での `qwen3-coder:30b` は5分でタイムアウトし、`qwen3:4b` は1分38秒で完走しました。**判断基準はパラメータ数ではなく「メモリに全部載るか」です。**
5. **developer preview であることを忘れずに。** 公式が破壊的変更を明言しています。本番投入ではなく、プラグイン構造の実験台として付き合うのが現時点での正しい距離感です。

---

## 参考リンク

- [DeepSeek Harness — GitHub](https://github.com/deepseek-ai/deepseek-harness)
- [公式: モデル設定ガイド](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md)
- [公式: `llm-pi-ai` アダプタ仕様](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/llm/llm-pi-ai/README.md)
- [公式: プラグイン設定カタログ](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)
- [Cordis — プラグインシステム](https://github.com/cordiverse/cordis)

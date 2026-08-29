---
title: "Claude Code × Ollamaのコンテキスト上限を整理する — 1Mモデルが200kに縮む3つの原因と解法"
emoji: "🐫"
type: "tech"
topics: ["ClaudeCode", "Ollama", "LLM", "AI", "cli"]
published: true
---

## この記事で分かること

「Ollamaのクラウドモデルは1Mコンテキストのはずなのに、Claude Codeが200kで勝手に圧縮を始める」 – この現象に遭遇して、公式の案内どおり `[1m]` をモデル名に付けたら**起動すらしなくなった**、という経験はないでしょうか。

原因は1つではありません。**1Mに関わるレイヤーが3つあり、それぞれ別の場所で値を決めている**ためです。この記事は、どこで200kに縮むかを整理し、コピペで動くalias 1行の解法と、公式ドキュメントが定義する3つのケースまでを示します。

- **TL;DR**: 未知のモデルIDに対してClaude Codeは200kを仮定してauto-compactする。`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576` をaliasに足すだけで1Mの実力を取り戻せる

:::message
本記事のコマンドは Apple Silicon Mac / Claude Code 2.1.251 / Ollama で **2026-08-30 に実行して確認**しています。`ollama launch` 経由の `[1m]` 拒否とzshのグロブエラーは当日再現済み。直接 `claude` を叩く経路（パターン2）は公式ドキュメントベースの未検証です。
:::

---

## [★] まず整理: 「1M」を決めるのは3つのレイヤー

「1Mコンテキストが使えるはず」という期待と実際の挙動が食い違うとき、値を決めているのは次の3層です。**どの層の数字が最終的に効くか**を先に押さえると、以降の説明はすべて1本の線でつながります。

| レイヤー | 役割 | コンテキストの扱い |
|---|---|---|
| Ollama（モデル提供側） | モデルを実際にserveする | `glm-5.3:cloud` は 1,048,576 を申告 |
| Claude Code（エージェント側） | セッションを管理しauto-compactする | **知らないモデルIDには200kを仮定** |
| `ollama launch`（ランチャー側） | 引数を検証してClaude Codeを起動する | `[1m]` のような記法を**モデル名として先に検証**し、通す前に弾く |

起動時に出る警告が、この2層目の挙動そのものです。

```text
"glm-5.3:cloud" is not a model this version of Claude Code recognizes,
so auto-compact will keep this session within 200k tokens
(the context window it assumes).
```

つまり**モデルは1Mの能力を持ちながら、エージェント側の仮定によって1/5に制限されている**状態です。警告は親切ですが、表示を読み流していると「1Mモデルを買って200kで使う」ことを長期間続けることになります。

---

## [★★] なぜそうなったのか — 設計経緯

「公式が `[1m]` を案内しているのに、なぜ `ollama launch` では動かないのか」。ここを履き違えると設定を何時間も回すことになるので、公式ドキュメントの設計意図を先に確認します。

Claude Codeのモデル設定ドキュメント（[Correct the window for a gateway or custom model ID](https://code.claude.com/docs/en/model-config)）は、未知のモデルIDの扱いを**3つのケースに分けて定義**しています。要点を抜き出すと:

1. **`claude-` で始まらず `[1m]` も含まない未知ID**（`glm-5.3:cloud` がこれ）→ `CLAUDE_CODE_MAX_CONTEXT_TOKENS` が**そのまま直接適用**される
2. **`claude-` で始まらないが `[1m]` を含む未知ID** → Claude Codeは**1Mウィンドウを仮定**する（変数は単独では効かない）
3. **`claude-` で始まるID・Claudeモデルに解決されるID** → 変数は `DISABLE_COMPACT` 併用時のみ有効

この定義から読み取れる設計意図を整理します。

| 論点 | 設計意図 | 検討された代替案 | 出典 |
|---|---|---|---|
| 未知IDに200kを仮定 | APIがエラーを返すまで放置するのではなく、**安全側のウィンドウで事前に圧縮（proactive compaction）**を続ける | `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` で「APIに拒否されてから初めて圧縮」に切替可能 | [model-config](https://code.claude.com/docs/en/model-config) |
| `[1m]` をClaude Codeが解釈する | サフィックスは**Claude Code側の記法**。ゲートウェイ越しの未知IDにも1Mを仮定する道を用意している | 同機能を環境変数でも提供（`CLAUDE_CODE_MAX_CONTEXT_TOKENS`） | 同上 |
| `ollama launch` が `[1m]` を弾く | ランチャーは**モデル名の検証を最初に行う**。Claude Code用の記法を知らないので、到達前に `Error: invalid model name` で拒否 | —（レイヤー間で記法を共有していない） | 実行時エラー（2026-08-30再現） |

つまり **Claude Code側には最初から道が2本用意されていた**のに、片方（`[1m]`）はランチャーの名前検証で到達できず、もう片方（環境変数）だけがランチャーを素通りして届く——これが「公式の案内通りにやったのに動かない」の正体です。抽象化レイヤーを噛ませると、**下層ツール固有の記法が上層に届かない**典型的な罠です。

---

## 前提知識: Ollamaクラウドモデルの実測値

「本当に1Mなのか」を、`ollama show` の申告値で確認します（2026-08-30時点の実測）。

```bash
ollama show glm-5.3:cloud | grep "context length"
# context length      1048576
```

| モデル | context length（ollama show実測） |
|---|---|
| `glm-5.3:cloud` | 1,048,576 |
| `glm-5.3-flash:cloud` | 1,048,576 |
| `deepseek-v4-flash:cloud` | 1,048,576 |
| `deepseek-v4-pro:cloud` | 1,048,576 |
| `kimi-k3:cloud` | 1,048,576 |

2026年のフロンティアモデルでは1Mが事実上の標準になっています。「全部同じ値で怪しい」と最初は疑いましたが、`ollama show` の申告値は公式モデルページの記載と一致しており、杞憂でした。

:::message alert
ただし `docs.ollama.com` のクラウドページには、**クラウド側のコンテキスト上限やトランケーション方針の記載がありません**。1Mは「モデルの理論値」であって「クラウドが実際に受け付ける値」の保証ではない点は正直に書いておきます。長大なセッションで `prompt is too long` 系のエラーが出たら、`CLAUDE_CODE_MAX_CONTEXT_TOKENS` を段階的に下げてください。
:::

---

## 解法: alias 1行（コピペで動く）

結論を先に。`ollama launch` 経由でも、**環境変数は子プロセスにそのまま継承される**ので、モデル名は素のままでコンテキストだけ宣言すれば通ります。

```bash
# ~/.zshrc
alias ccglm='CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576 ollama launch claude --model glm-5.3:cloud'
alias cckimi='CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576 ollama launch claude --model kimi-k3:cloud'
alias ccds='CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576 ollama launch claude --model deepseek-v4-flash:cloud'
```

前節のケース1（`claude-` 非プレフィックス・`[1m]` なしの未知ID）なので、変数は**追加条件なしで直接適用**されます。効いたかどうかは、起動時の200k警告が消えるかで判定できます。

失敗する書き方は次のとおりです。

```bash
# ❌ ollama が先にモデル名を検証して弾く（2026-08-30 実行時エラー）
ollama launch claude --model 'glm-5.3:cloud[1m]'
# Error: invalid model name
```

---

## [★] 5つのコンテキスト設定パターン

用途ごとに使い分けを整理します。

### パターン1: 環境変数で上限を宣言する（本記事の推奨）

前節のalias。`ollama launch` 経由でも届き、proactive compaction（事前圧縮）は宣言したウィンドウで継続します。

### パターン2: `[1m]` をモデルIDに付ける

公式ドキュメントのケース2。`claude-` 非プレフィックスの未知IDに `[1m]` を付けると、Claude Codeは1Mウィンドウを仮定します。ただし `ollama launch` はこの記法を通さないため、**Claude Codeを直接起動してOllamaのエンドポイントを向ける構成限定**です。

```bash
# 直接 claude を叩く場合（未検証・公式docベース）
# クォート必須: zshは [1m] をグロブとして解釈する（2026-08-30再現）
claude --model 'glm-5.3:cloud[1m]'
```

### パターン3: 圧縮の発火位置だけ調整する

上限は正しいが**圧縮が早すぎる/遅すぎる**場合は `CLAUDE_CODE_AUTO_COMPACT_WINDOW` で圧縮計算に使う容量を別途指定できます（`100000`〜`1000000`の範囲、プレーンな整数のみ。`500k` のような省略形は `500` として読まれるので注意）。1Mウィンドウで500kの位置から圧縮したい、といった調整に使います。

### パターン4: エラー駆動の圧縮に切り替える

「圧縮は絶対にさせたくない。上限はAPIに判断させたい」場合は `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1`（**Claude Code v2.1.223以降が必要**）。未知IDでも、**APIが会話を拒否してから初めて**圧縮に入ります。

### パターン5: 逆向き問題 — ローカル小窓モデルの200k過大誤認

同じ構造の問題は**下方向**でも起きます。8k〜32kのローカルモデルもClaude Codeからは200kと仮定されるため、実際の上限を超えてリクエストを投げてエラーになります。こちらが `CLAUDE_CODE_MAX_CONTEXT_TOKENS` の公式ドキュメントが挙げる本来の主用途です。

```bash
# 32kモデルの例
CLAUDE_CODE_MAX_CONTEXT_TOKENS=32768 ollama launch claude --model qwen3-coder:30b
```

---

## [★] 公式ドキュメントの3ケース（そのまま引用）

[model-config（Correct the window for a gateway or custom model ID）](https://code.claude.com/docs/en/model-config) 「Correct the window for a gateway or custom model ID」より、`CLAUDE_CODE_MAX_CONTEXT_TOKENS` の適用条件は3つに分かれます。

> If the ID doesn't start with `claude-` or contain `[1m]`, in any casing, and Claude Code can't resolve it to a Claude model, the variable applies directly and proactive compaction continues at the declared window.
>
> — [Model configuration / Correct the window for a gateway or custom model ID](https://code.claude.com/docs/en/model-config)

| ケース | モデルIDの特徴 | `CLAUDE_CODE_MAX_CONTEXT_TOKENS` の効き方 |
|---|---|---|
| 1 | `claude-` 非プレフィックス・`[1m]` なし・未知（**Ollamaクラウドモデルはここ**） | **そのまま直接適用** |
| 2 | `claude-` 非プレフィックス・`[1m]` あり・未知 | 1Mを仮定。変数は単独では効かない（ウィンドウを矯正するなら `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` 併用） |
| 3 | `claude-` プレフィックス / Claudeモデルに解決される | `DISABLE_COMPACT` 併用時のみ有効 |

覚えるべきは**自分のモデルIDがどのケースに該当するか**だけです。ケース3（例: `anthropic/claude-opus-4-8` のようなID）で変数が効かないのは仕様であり、Ollamaクラウドモデル（ケース1）とは効き方が違う点に注意してください。

---

## [★] やりがちなアンチパターン 7選

### 1. `[1m]` を `ollama launch` に渡す

:::message alert
ランチャーのモデル名検証で `Error: invalid model name`。Claude Codeに届く前に失敗するので、何を変えても直りません。パターン1（環境変数）を使ってください。
:::

### 2. `[1m]` をクォートせずに書く

zshは `[1m]` をグロブとして解釈します。

```text
zsh: no matches found: glm-5.3:cloud[1m]
```

（2026-08-30再現）直接 `claude` を叩く経路を試す場合もクォート必須です。

### 3. 「警告は無害」と読み流す

警告自体はセッションを止めませんが、**1Mの実力を1/5で使っている**ことを意味します。長いリポジトリ読み込みや大量ファイル編集で、本領が発揮できないままauto-compactが入り、作業の文脈が失われます。

### 4. `claude-` プレフィックスのIDに変数を単独で設定する

ケース3では `DISABLE_COMPACT`（全圧縮無効化）が併用条件です。「Ollamaでは効いたのにゲートウェイでは効かない」場合は、まずモデルIDのケース分けを疑ってください。

### 5. `ollama show` の申告値をクラウド保証と混同する

申告値は「モデルの能力」です。クラウド側が実際に受け付ける上限の保証は（現時点では）ドキュメント化されていません。エラーが出たら変数を下げる、という運用を前提にしてください。

### 6. 値を科学記法で書く

`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1e6` のような科学記法は、v2.1.208 未満では `1` として解釈される不具合がありました（v2.1.208で修正、v2.1.211以降は公式にサポート）。バージョンを問わず10進法で `1048576` と書くのが安全です。

### 7. 確認をサボる

設定が効いたかどうかは、**起動警告の消失**と `/context` の表示で必ず確認してください。aliasを書いただけで試していないと、typoのまま数週間200kで使い続けることになります。

---

## 定量: 何がどれだけ変わるか

| 項目 | 設定なし | alias設定後 |
|---|---|---|
| Claude Codeの仮定ウィンドウ | 200,000 | 1,048,576 |
| モデル能力の利用率 | 約20% | 約100%（モデル申告値に対して） |
| 起動警告 | 出る | 消える |
| proactive compaction | 200k超過前に発火 | 宣言ウィンドウに対する割合で発火 |

1Mウィンドウでの圧縮発火位置はデフォルトで約967k（Sonnet 5の1Mセッションと同水準の余裕係数）が目安ですが、カスタムIDでは宣言したウィンドウに対する割合で計算されるため、余裕を持たせたい場合はパターン3で調整します。

---

## 4変数の比較表

| 変数 | 効用 | 主な用途 |
|---|---|---|
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | Claude Codeが仮定するウィンドウを宣言 | 未知IDの上限訂正（上下両方向） |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | 圧縮計算に使う容量を指定 | 発火位置の調整 |
| `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT` | 未知IDでもAPI拒否まで圧縮しない | 圧縮を絶対にさせたくない場合 |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | 1Mバリアントを無効化し200k扱いに | コンプラ用途（上限を下げたい時） |

---

## 実践チェックリスト

### セットアップ時
- [ ] 対象モデルの `ollama show <model>` でcontext lengthを確認した
- [ ] aliasに `CLAUDE_CODE_MAX_CONTEXT_TOKENS` を含めた（モデル名は素のまま）
- [ ] 起動時の200k警告が消えることを確認した

### 日常運用時
- [ ] `/context` で実際に読み込めている量をたまに確認する
- [ ] 長大セッションでエラーが出たら変数を段階的に下げる

### トラブル時
- [ ] `invalid model name` → `[1m]` をランチャーに渡していないか
- [ ] `no matches found` → zshのクォート漏れか
- [ ] 変数が効かない → モデルIDがケース3（`claude-` プレフィックス）でないか

---

## まとめ

- **1Mを決めるレイヤーは3つ**: モデル（Ollama）・エージェント（Claude Code）・ランチャー（`ollama launch`）。縮むのは2層目の「未知ID=200k仮定」
- **公式の解法は2本**: `[1m]` サフィックスと `CLAUDE_CODE_MAX_CONTEXT_TOKENS`。前者はランチャーが弾くので、`ollama launch` 経由では後者一択
- **ケース1の未知IDには変数が直接効く**: `DISABLE_COMPACT` 併用が必要なのは `claude-` プレフィックスIDだけ
- **同じ罠は下方向にもある**: ローカル小窓モデルの200k過大誤認。変数は元々そちらが主用途
- **申告値とクラウド保証は別物**: `ollama show` の1Mを過信せず、エラー時は変数を下げる運用を

「ランチャー経由だとツール固有の記法が届かない」 – この構造は `[1m]` に限らず、フラグを転送しないラッパー全般で起きます。中継層を1つ噛ませた時点で、**その層が両端の記法を知っているか**を疑うのが最初の一歩です。

---

## 参考リンク

- [Claude Code モデル設定（model-config）](https://code.claude.com/docs/ja/model-config) — 3ケースの正典
- [Claude Code 環境変数リファレンス](https://code.claude.com/docs/ja/env-vars) — `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT`（v2.1.223+）・`CLAUDE_CODE_AUTO_COMPACT_WINDOW` の正典
- [Claude Code CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) — v2.1.208の科学記法バグ修正・v2.1.211の正式サポート
- [Ollama クラウドドキュメント](https://docs.ollama.com/cloud)
- [ollama/ollama#17584](https://github.com/ollama/ollama/issues/17584) — `ollama launch` の `[1m]` 拒否が報告されているIssue
---
title: "Warp OSS化4ヶ月、マージPRの68%はbotだった"
emoji: "🌀"
type: "tech"
topics: ["warp", "terminal", "opensource", "ai", "agent"]
published: true
---

<!--
ファクトチェック: 済（2026-08-29 Genspark gsk cross_check / 31クレーム検証 — TRUE 17 / PARTIALLY 6 / UNVERIFIABLE 8）
  → 修正反映3件: 旧Proプラン廃止時期・BYOKの対象プラン条件・BYOKの設定パス
  → cross_check の誤指摘2件（bootstrapのHomebrew導入・protoc依存）は一次ソースで反証し不採用
GitHub集計: Search API を月次照会（2026-08-29取得）。再現クエリは本文に記載。
ビルド実測: Apple M5 / macOS 26.5.2 / Rust 1.92.0 で実行。
-->

## 1. この記事で分かること

2026年4月28日、Warp Terminalがクライアントをオープンソース化しました。当時「AI×ターミナルの戦争が再点火した」と騒がれ、私もその週に整理記事を書きました。

そこで書いた予測のひとつが、これです。

> **誤解4: 「コードを書くのは人間のcontributor」 → ❌ AI agent が主体**

4ヶ月経ったので、GitHubのAPIを叩いて答え合わせをしました。結果は予測通り – というより、予測より徹底していました。

| 月 | マージされたPR | うち `warp-agent-staging[bot]` | bot比率 |
|---|---|---|---|
| 2026-05 | 726件 | 0件 | **0%** |
| 2026-06 | 452件 | 33件 | 7.3% |
| 2026-07 | 613件 | 237件 | 38.7% |
| 2026-08（29日まで） | 341件 | 232件 | **68.0%** |

*集計: GitHub Search API（`repo:warpdotdev/Warp is:pr is:merged`）を月次で照会。2026-08-29取得。*

人間がマージさせたPRは月726件から109件へ、**85%減りました**。同じ期間にbotは0件から232件に増えています。Warpは「エージェントがコードを書くOSS」を宣言しただけでなく、**4ヶ月で実際にそこへ移行しきった**わけです。

この記事で扱うこと:

- ✅ **4ヶ月分の実測データ** — マージPRのbot比率、issue処理数、PR滞留の実数
- ✅ **なぜそうなったのか** — Ozの設計意図と `CONTRIBUTING.md` が定めた貢献フロー
- ✅ **手元でビルドした記録** — 2回失敗して3回目で通るまでの実エラーと所要時間
- ✅ **ライセンスの実態** — 81クレートのうちMITは何個か（数えました）
- ✅ 価格・利用パターンの2026年8月時点の姿（**BYOKはFreeプランでも使えるようになった**）

扱わないこと: Warpの基本的な使い方。本記事は**OSS化の「その後」に振り切ります**。

:::message
**本記事の情報基準日（as-of）: 2026年8月29日**
数値はすべてこの日にGitHub API・公式Pricingページ・リポジトリ実体から取得したものです。Warpは開発が非常に活発（直近pushは取得当日）なため、読む時点との差分は各自ご確認ください。
:::

---

## 2. ★ 4ヶ月前の「4つの誤解」答え合わせ

OSS化直後、私は4つの誤解を整理しました。それぞれが4ヶ月後にどうなったかを先に示します。

| 4月に書いたこと | 8月時点の答え | 判定 |
|---|---|---|
| 誤解1: Warp全体がOSSになった → 実際はclientのみ | 変わらず。サーバとOzはプロプライエタリのまま | ✅ 当たり |
| 誤解2: ライセンスは1つ → AGPLv3とMITに分割 | 方向は当たりだが**比率を見誤っていた**（後述） | 🔺 半分 |
| 誤解3: Ozはコードネーム → 収益源の別製品 | それ以上だった。Claude CodeとCodexも動かす基盤に進化 | ✅ 当たり |
| 誤解4: 人間がコードを書く → AI agentが主体 | 8月のマージPRの68%がbot。想定より徹底 | ✅ 当たり |
| （初稿では未分離）BYOLLM | BYOK＝Freeでも可 / BYOLLM＝Enterprise限定、と別物だった | ❌ 外し |

**外した点を2つ先に書きます**。ひとつは誤解2で「AGPLv3とMITに分割されている」と書いたとき、私は暗黙に「UIフレームワークがMITなら、流用できる範囲はそれなりに広いだろう」と考えていました。実際にリポジトリを取得して数えたところ、**81クレート中MITは2つだけ**でした。詳細は第6章に書きます。

もうひとつは「BYOLLM」をひとまとめの機能として書いたことです。実際にはAPIキー持ち込み（BYOK）と自社ホスト推論（BYOLLM）は別物で、前者はFreeプランでも使え、後者はEnterprise限定でした。第7章で分けています。

---

## 3. 実測 — 4ヶ月で何が起きたのか

### 3.1 リポジトリの規模

まず全体像です。すべて2026-08-29にGitHub APIから取得した値です。

| 指標 | 値 |
|---|---|
| Star | 64,607 |
| Fork | 5,480 |
| Watcher | 345 |
| Open issue | 3,823 |
| Closed issue | 7,051 |
| PR総数 | 4,643 |
| うちマージ済み | 2,296（49.5%） |
| うちオープン | 1,293 |
| うちクローズ（未マージ） | 1,054 |

OSS化から4ヶ月で **issueを10,874件受け取り、うち7,051件を閉じている**（進捗率64.8%）。オープンソースプロジェクトとして異常な処理量です。人間のメンテナだけでこの量を捌くのは無理で、ここがOzを投入した動機に直結します。

### 3.2 bot比率の推移が本題

冒頭の表を再掲し、人間側の数字を補います。

| 月 | マージ総数 | bot | 人間 | bot比率 |
|---|---|---|---|---|
| 2026-05 | 726 | 0 | 726 | 0% |
| 2026-06 | 452 | 33 | 419 | 7.3% |
| 2026-07 | 613 | 237 | 376 | 38.7% |
| 2026-08 | 341 | 232 | 109 | 68.0% |

![マージPRの内訳とbot比率の推移（2026-05〜2026-08）](/images/warp-terminal-oss-launch-guide-2026/bot-pr-ratio.png)
*左: マージされたPRの人間/bot内訳。右: bot比率の推移。GitHub Search APIを月次集計（2026-08-29取得）。*

2つ読み取れます。

**1つめ: 移行は段階的だった。** 5月時点ではbotのマージはゼロです。6月に33件で試し、7月に237件へ一気に増やし、8月には過半を超えました。「OSS化と同時にエージェントに切り替えた」のではなく、**4ヶ月かけて置き換えた**というのが実際の姿です。

**2つめ: 総量が減っている。** マージ総数は726 → 341と半減以下です。bot導入で生産量が増えたわけではありません。初期の駆け込み的なマージが落ち着き、レビューゲートが効き始めた結果と読むのが妥当でしょう。

### 3.3 botのPRも全部は通っていない

「botが出せば通る」わけでもありません。`warp-agent-staging[bot]` のPRを状態別に数えると:

| 状態 | 件数 |
|---|---|
| マージ済み | 502 |
| オープン（滞留中） | 620 |
| クローズ（未マージ） | 181 |

**滞留620件がマージ済み502件を上回っています**。8月に作成されたPR 839件のうち588件（70.1%）がbot由来であることを踏まえると、生成のスループットにレビューが追いついていない構図が見えます。エージェントを入れてもボトルネックは消えず、**人間のレビューへ移動しただけ**ということです。

:::message alert
**この数値の限界**: `warp-agent-staging[bot]` は「Ozが動かすbotアカウント」であって、bot以外のPRが100%人間の手書きである保証はありません。個人アカウントでエージェントを使って書いたPRはこの集計では「人間」に入ります。したがって**68%は下限**とみるべきです。
:::

---

## 4. なぜこうなったのか — Ozと `CONTRIBUTING.md` の設計

数字の背景には、明文化された設計思想があります。

### 4.1 Ozは「Warp専用エージェント」ではなくなった

Oz自体はOSS化より前、**2026年2月10日**にローンチしています。そして**2026年5月19日**のマルチハーネス対応で、Warp Agentに加えて **Claude CodeとCodexも動かせる**オーケストレータになりました。

つまりWarpの立ち位置は「AIターミナルの会社」から「**どのエージェントでも運用できるクラウド基盤の会社**」に移っています。clientをOSSにできたのは、収益の重心がとっくにそちらへ移っていたからです。

そして自社のOSSリポジトリは、そのOzの**ショーケース兼負荷試験場**になっています。1万件超のissueを捌く様子が公開されていること自体が、Ozの最も強い営業資料です。

### 4.2 貢献フローが「Oz前提」で書かれている

`CONTRIBUTING.md` を読むと、これが通常のOSSと違うことがはっきり書かれています。

> Warp's contribution model is shaped by [Oz](https://oz.warp.dev), an agent that automates parts of triage, spec writing, implementation, and review.

要点は4つです。

- **issueが起点**。設計の議論はissueで完結させ、そこからPRに進む
- **機能追加はspec PRが先**。`specs/` 配下に `product.md`（プロダクト仕様）と `tech.md`（技術仕様）をコミットしてから実装に入る
- **レディネスラベルが門番**。`ready-to-spec` / `ready-to-implement` が付くまでPRは受け付けられない。議論しただけでは着手の許可にならない
- **レビューは自動が既定**。PRを開くとOzが自動アサインされ初回レビューを出す。Ozが承認して初めて、Warp社の担当者レビューが要求される

さらに `warp:reserved-internal` ラベルが付いたissueには**contributorがPRを出しても、Ozが説明コメント付きで自動的に却下します**。

ここが設計として面白いところです。従来のOSSでは「PRを出す自由」がまずあって、マージされるかどうかが後段の関門でした。Warpは**関門を最上流のissueに移し、下流を自動化した**わけです。人間の役割は「コードを書くこと」から「仕様を決めて検証すること」に移されています。

公式の言い方はもっと踏み込んでいます。

> well-tuned agent infrastructure like Oz will manage code better in the long run than humans

### 4.3 外部コントリビュータは機械的に識別されている

`.github/workflows/` を見ると `label_external_contributors.yml` があります。外部からのPRは自動でラベル付けされ、内部のPRとは別扱いになります。`check_approvals.yml`、`stale_requested_changes_prs.yml`、`close_stale_fix_prs.yml` も並んでおり、**PRのライフサイクル管理がほぼ全自動**です。

---

## 5. 手元でビルドした — 2つの壁を越えて4分59秒

「OSSなのだから自分でビルドできる」と4月の初稿には書きました。実際にやりました。**ビルドは通りましたが、素の `cargo build` では2回失敗しています**。その記録を書きます。

### 5.1 実行環境

| 項目 | 値 |
|---|---|
| マシン | Apple M5 / 10コア / RAM 16GB |
| OS | macOS 26.5.2（ビルド 25F84） |
| Rust | 1.92.0（`rust-toolchain.toml` で固定。rustupが自動取得） |
| git-lfs | 3.5.1 |
| Xcode | インストール済み（`/Applications/Xcode.app`） |

### 5.2 クローンは27秒、782MB

```bash
git clone --depth 1 https://github.com/warpdotdev/Warp.git
```

`--depth 1` で **27.3秒 / 782MB**。`.gitattributes` を見るとGit LFSが必須で、`crates/input_classifier/models/**`（機械学習モデル）と `*.pdb` がLFS管理です。`git lfs pull` を忘れるとビルドが通りません。

### 5.3 壁1: `protoc` がない（2分31秒で停止）

公式の `AGENTS.md` には `cargo run` でもいけると書いてあるので、まず素の cargo で試しました。

```bash
cargo build --bin warp
```

554個目のクレートで停止。所要 **2分31秒**（real 150.86s / user 344.44s）。

```
error: failed to run custom build command for `warp_multi_agent_api v0.0.0
  (https://github.com/warpdotdev/warp-proto-apis.git?rev=0ca49ce...)`

  --- stderr
  Error: Custom { kind: NotFound, error: "Could not find `protoc`.
  If `protoc` is installed, try setting the `PROTOC` environment variable
  to the path of the `protoc` binary. To install it on macOS, run
  `brew install protobuf`." }
```

止まったクレート名に注目してください。**`warp_multi_agent_api`** です。「OSS化されたのはターミナルのclientだけ」のはずですが、そのclientをビルドするのに**マルチエージェントAPIのprotobuf定義**が要ります。`request.proto`、`task.proto`、`orchestration.proto`、`skill.proto` といったファイル名が並びます。clientは最初からエージェント基盤に繋ぐ前提で作られている、ということが構造から読み取れます。

回避策はエラーメッセージ通りです。

```bash
brew install protobuf   # 7.3秒 / libprotoc 36.0 が入った
```

### 5.4 壁2: Metal Toolchainがない（41秒で停止）

再開したところ、今度は41.35秒で別の壁に当たりました。

```
thread 'main' panicked at crates/warpui/build.rs:113:5:
error compiling metal shaders to .air; error: cannot execute tool 'metal'
due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain
```

WarpのUIはMetalシェーダをビルド時にコンパイルします。Xcode本体が入っていても、**Metal Toolchainは別コンポーネント**で、明示的にダウンロードが必要です。

```bash
xcodebuild -downloadComponent MetalToolchain
```

ダウンロードは **687.9MB / 45.7秒**（Metal Toolchain 17F109）。Xcodeを入れているから大丈夫、とは言えません。

### 5.5 3回目で通った — ビルド正味4分59秒

Metal Toolchain導入後、3回目のビルドが **1分47秒**（real 106.71s）で完了しました。

```
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 1m 46s
```

失敗した2回も含めた実測をまとめます。

| 工程 | 所要時間 | 結果 |
|---|---|---|
| `git clone --depth 1` | 27.3秒 | 782MB取得 |
| ビルド1回目 | 2分31秒 | ❌ `protoc` なしで停止（554クレート目） |
| `brew install protobuf` | 7.3秒 | libprotoc 36.0 |
| ビルド2回目 | 41.4秒 | ❌ Metal Toolchainなしで停止 |
| `xcodebuild -downloadComponent MetalToolchain` | 45.7秒 | 687.9MB |
| ビルド3回目 | **1分47秒** | ✅ 成功 |
| **ビルド計** | **4分59秒**（150.9 + 41.4 + 106.7秒） | — |

成果物のサイズは無視できません。

| 対象 | サイズ |
|---|---|
| `target/debug/warp` | **767MB**（Mach-O 64-bit arm64） |
| `target/` 全体 | **12GB** |

M5の10コアで正味5分は速い部類ですが、**ディスクを12GB持っていかれます**。試すだけのつもりなら、この点は先に知っておいたほうがいいでしょう。

:::message
**ここまでで止めた理由**: 生成された `target/debug/warp` に `--help` を渡しても標準出力は空で、プロセスが常駐します。これはGUIアプリのバイナリで、macOSでは `./script/macos/run` が `.app` バンドル化とコード署名を行って初めて通常起動する設計だからです。本稿ではGUIの起動と操作までは行っていません。**ビルドが通ることの確認まで**が本節の検証範囲です。
:::

### 5.6 教訓: `./script/bootstrap` を飛ばしてはいけない

私が踏んだ2つの壁は、どちらも `./script/bootstrap` を実行していれば起きませんでした。

```bash
./script/bootstrap   # プラットフォーム固有のセットアップ
./script/run         # ビルドして起動
./script/presubmit   # fmt + clippy + テスト（PR前に必須）
```

初稿で私が書いた `cargo build --release` は**不十分な手順**でした。訂正します。

ただし `bootstrap` の中身を読むと、これはこれで気軽ではありません。実行前に表示される内容がこれです。

- Xcodeをactive developer directoryとして設定
- Cargo、Homebrew、**PowerShell**、**Docker**、**gcloud** とその関連ツールのインストール/更新
- `aarch64-apple-darwin` ターゲットの追加
- **gcloudの認証チェック**（未認証ならログインを促す）
- `warpdotdev/common-skills` からエージェント用スキルを取得

`script/macos/bootstrap` を読むと、実際に `brew install` されるのは次の面々です。

```
jq / sentry-cli / clang-format / create-dmg / multitime
powershell（cask） / pkgconf / llvm / docker（cask） / google-cloud-sdk
```

加えて PowerShell 用の `PSScriptAnalyzer` モジュールまで入ります。Homebrew自体が無い場合はインストールした上で「PATHを確認して再実行してください」と言って一度終了する作りです。

`--skip-gcloud-auth` と `--skip-common-skills` で一部は無効化できます。しかし**既定でGoogle Cloud SDKとDockerとPowerShellを入れにくるOSSプロジェクト**というのは、率直に言って身構えます。ここにも「これはWarp社内の開発環境をそのまま公開したものだ」という性格が出ています。

---

## 6. ライセンスの実態 — 81クレート中MITは2つ

4月の初稿で私が見誤った点です。実際に数えました。

```bash
# ワークスペースの既定ライセンス
$ grep -A2 '^\[workspace.package\]' Cargo.toml
authors = ["Warp Team <dev@warp.dev>"]
license = "AGPL-3.0-only"

# クレートごとのライセンス指定を集計
$ grep -h '^license' crates/*/Cargo.toml | sort | uniq -c
   2 license = "MIT"
  79 license.workspace = true
```

| 区分 | クレート数 | 割合 |
|---|---|---|
| MIT（`warpui`, `warpui_core`） | 2 | 2.5% |
| AGPL-3.0-only（workspace継承） | 79 | 97.5% |

*母数は `crates/` 配下のディレクトリ数（81）。ワークスペースは `members = ["crates/*", "app"]` なので、`app` を含めると82になります。*

**MITなのはUIフレームワークの2クレートだけ**です。「MIT部分があるから流用しやすい」という期待は、この比率を見ると成立しません。ターミナルの中身（コマンド解析、補完、ブロックUI、エージェント連携）はすべてAGPLv3側にあります。

実務上の意味はこうです。

- **UIツールキットとしてwarpuiを使いたい** → MITなので比較的自由
- **ターミナルとしてforkして製品化したい** → 97.5%がAGPLv3。ネットワーク越しに提供するなら**ソース公開義務が発生する**
- **社内で改変して使う** → 配布しなければ義務は発生しないが、社内ポリシーとの整合は法務確認を推奨

初稿では「MIT部分のみが安全」と書きました。方向は合っていますが、**その「MIT部分」が全体の2.5%しかない**ことまで書くべきでした。

---

## 7. 4つの利用パターン（2026年8月版）

初稿では「BYOLLM」を1つの選択肢としてまとめていましたが、**これは2つの別機能**でした。分けて整理します。

| パターン | 構成 | 向いている人 | 条件（※2026年8月時点） |
|---|---|---|---|
| 1. 公式版 + 有料tier | 配布バイナリ + Oz | AI機能をフルに使いたい個人 | Build 月$20〜 |
| 2. OSS clientのみセルフビルド | 自前ビルド、Oz無し | 閉域環境・ソース監査が必要な組織 | 無料。ただしビルドの壁は第5章参照 |
| 3a. **BYOK**（自分のAPIキー） | 公式版 + 自分のOpenAI/Anthropic/Googleキー | クレジットではなく従量で払いたい個人 | **Freeを含む対象プランで可**（個人・従業員10名以下の組織） |
| 3b. **BYOLLM**（自社ホストのモデル） | 公式版 + 自社クラウドの推論基盤 | データ所在地を統制したい組織 | **Enterpriseプラン限定** |
| 4. fork して製品化 | 改変・再配布 | ターミナル製品の土台にしたい | **97.5%がAGPLv3**。第6章を熟読 |

**3a と 3b の差は大きい**ので押さえてください。

- **BYOK** は自分のAPIキーをWarpに登録する機能です。設定は**Settingsを開いて `API keys` で検索**します（専用のサイドバー項目が無いため、公式ドキュメントもこの方法を案内しています）。**Freeプランを含む対象プランで使えます** — ただし対象は「個人ユーザー、および従業員10名以下の組織」で、それより大きい組織は Business / Enterprise が必要です。2025年10月の新価格発表時点では **Buildプラン限定**だったので、ここは明確に緩和されました。
- **BYOLLM** は自社クラウド（AWS Bedrock、Vertex AI。Azure Foundryは対応予定）にホストしたモデルへリクエストを流す機能で、**Enterpriseプランでしか使えません**。ルーティングとガバナンス、可観測性はWarp側が持ちます。

「自分のモデルを使いたい」の中身がAPIキーの持ち込みなら無料でできますが、推論そのものを自社インフラに寄せたいならEnterprise契約が要ります。

パターン2の位置づけは4月時点より厳しくなったと考えています。ビルドに必要な前提（gcloud、Docker、PowerShell、Metal Toolchain）が「社内環境の再現」に寄っており、閉域環境で通すのは相応の手間です。

---

## 8. 価格の現在地

:::message alert
**初稿の誤りを訂正します。** 2026-04-30版で「Build tier $18/月〜」と書いたのは**年払い時の月額換算**でした。月払いは$20です。以下、月払い/年払いを分離します。
:::

| プラン | 月払い | 年払い（月あたり） | 付属クレジット | 備考 |
|---|---|---|---|---|
| Free | $0 | — | 従量課金のみ | 基本のターミナル機能とエージェントCLI |
| **Build** | **$20** | $18（10%引） | 1,500 | フロンティア/OSSモデルへのフルアクセス |
| Max | $200 | $180 | 18,000 | Buildの12倍 |
| Business | $50/ユーザー | $45/ユーザー | 1,500/席 | 上限25席、SSO、データ管理 |
| Enterprise | 個別見積 | 個別見積 | 共有プール | 席数無制限 |

*※2026年8月時点。現行体系は2025年10月30日に発表されたもので、旧 Pro / Turbo / Lightseed プランは2025年12月1日以降の初回更新でBuildへ移行しました（新規登録は即日切替）。最新値は[公式Pricingページ](https://www.warp.dev/pricing)を確認してください。*

**clientがOSSでも、AI機能を使うならここに課金する**。この構造は4月から変わっていません。

---

## 9. アンチパターン答え合わせ

4月に挙げた5つのアンチパターンを、4ヶ月分の事実で採点します。

### AP1: 「OSSになったから完全に無料で使い放題」

**✅ 依然として最大の誤解。** clientのライセンス費用はゼロですが、AI機能はOz経由で有料です。Freeプランは従量課金のみ。

### AP2: clientをforkしてSaaS化

**🔺 危険度を上方修正。** 97.5%がAGPLv3である以上、ネットワーク越しの提供はソース公開義務を引き起こします。MIT部分は2クレートのみ。

### AP3: UIだけ流用してAGPLv3部分を引きずる

**✅ 当たり。** `grep -h '^license' crates/*/Cargo.toml` で境界を確認してから設計してください。依存の引き込みは `cargo tree` で追えます。

### AP4: 「Oz抜きでも同じ体験ができる」と期待する

**✅ 当たり、かつ構造的に確定。** ビルドが `warp_multi_agent_api` で止まった件（第5.3節）が示す通り、clientはエージェント基盤への接続を前提に組まれています。

### AP5: 「PRを出せばマージされる」OSS文化を期待する

**✅ 完全に当たり。しかも明文化された。** `CONTRIBUTING.md` は、レディネスラベルが付くまでPRを受け付けないこと、機能追加にはspec PRが必要なこと、`warp:reserved-internal` のissueに対するPRは**Ozが自動却下する**ことを明記しています。

貢献したい人への実務的な助言はこうなります。**コードから書き始めないこと。** issueを立てるか既存issueを探し、`ready-to-implement` が付くのを待つ。機能追加なら `product.md` と `tech.md` を先に書く。この順序を外すと、どれだけ良いコードでも入りません。

---

## 10. 関連ターミナル比較（※2026年8月時点）

| ツール | OSS範囲 | AI内蔵 | 言語 | ライセンス | 特徴 |
|---|---|---|---|---|---|
| **Warp** | clientのみ（97.5%がAGPLv3） | ✅ Oz経由 | Rust | AGPLv3 + MIT | agent-first、Star 64.6k |
| Wave | ✅ 全体 | △ 拡張 | Go | Apache-2.0 | フルOSS、ペイン分割が強い |
| Ghostty | ✅ 全体 | ❌ なし | Zig | MIT | パフォーマンス特化 |
| iTerm2 | ✅ 全体 | △ プラグイン | Objective-C | GPLv2 | macOS定番、長期安定 |
| Zed（terminal） | ✅ 全体 | ✅ assistant | Rust | GPLv3 | エディタ統合 |

**Warpの立ち位置**: 「ターミナルの完成度 × クラウドエージェント統合」は依然として唯一です。一方で、純粋にOSSであることを重視するなら Wave / Ghostty が候補になります。**この4ヶ月でその差はむしろ開きました**——Warpが「エージェント基盤の入口」に寄ったぶん、単体のターミナルとしての性格は薄くなっています。

---

## 11. 実践チェックリスト

**使うだけの人:**

- [ ] 用途を決める — AI機能フル（有料tier）か、OSS clientのみ（セルフビルド）か
- [ ] 有料契約するなら [公式Pricing](https://www.warp.dev/pricing) で月払い/年払いを確認（Build 月$20 / 年$18）

**ビルドしたい人:**

- [ ] `git lfs` を先に入れる（未導入だとbootstrapが止まる）
- [ ] `./script/bootstrap` を実行する（`cargo build` 直叩きは第5章の壁に当たる）
- [ ] gcloud認証を避けたいなら `--skip-gcloud-auth --skip-common-skills` を付ける
- [ ] macOSなら Metal Toolchain（`xcodebuild -downloadComponent MetalToolchain`）
- [ ] PR前に `./script/presubmit`

**コントリビュートしたい人:**

- [ ] コードより先にissueを見る。`ready-to-implement` が付いているか確認する
- [ ] 機能追加なら `specs/` に `product.md` + `tech.md` のspec PRから
- [ ] `warp:reserved-internal` のissueには手を出さない（Ozが自動却下する）
- [ ] 実装PRには手動テストの証跡を添える（`CONTRIBUTING.md` の要求事項）

**forkを検討する人:**

- [ ] `grep -h '^license' crates/*/Cargo.toml | sort | uniq -c` でAGPL/MITの境界を数える
- [ ] ネットワーク越しの提供があるならAGPLv3のソース公開義務を法務確認

---

## 12. まとめ

4ヶ月分の事実を3点に集約します。

1. **agent-firstは宣伝ではなく実装だった。** マージPRに占めるbot比率は5月0% → 8月68%。人間のマージは月726件から109件へ85%減。ただし移行は段階的で、4ヶ月かかっています。
2. **ボトルネックは消えず、移動した。** botのPRは滞留620件がマージ済み502件を上回ります。生成が速くなった分、レビューに詰まっています。エージェントを入れれば全部速くなる、という話ではありません。
3. **「OSS化」の実質は2.5%だった。** 81クレート中MITは2つ。残りはAGPLv3で、ビルドすらエージェント基盤のproto定義を必要とします。無料で手に入るのはターミナルの器であって、価値の中心はOz側に残されたままです。

4月に「Warpは戦略転換をした」と書きましたが、4ヶ月見た後の言い方はこうです。**Warpはターミナルの会社をやめ、エージェント運用基盤の会社になった。** OSSリポジトリはその基盤の実演装置です。1万件超のissueをOzが捌く様子が公開されていること自体が、最も雄弁な製品デモになっています。

**コードを書く工程を自動化し、人間を仕様と検証に配置する**——この形が他のOSSに広がるかどうかは、まだ分かりません。ただ少なくとも、それが機能する条件（潤沢な資金、自社製のエージェント基盤、明文化された貢献フロー）を全部揃えた事例が1つ、公開の場で動いています。次にこれを追うプロジェクトが出たとき、Warpの4ヶ月は比較対象になるはずです。

---

## 参考リンク

- [Warp公式アナウンス: Warp is now open-source](https://www.warp.dev/blog/warp-is-now-open-source)
- [Warp公式: The virtuous loop of Open Agentic Development](https://www.warp.dev/blog/the-virtuous-loop-of-open-agentic-development)
- [Warp公式: Introducing Oz](https://www.warp.dev/blog/oz-orchestration-platform-cloud-agents)
- [GitHub: warpdotdev/Warp](https://github.com/warpdotdev/Warp) — `CONTRIBUTING.md` / `AGENTS.md`
- [Warp Pricing](https://www.warp.dev/pricing)
- [Warp docs: Bring Your Own API Key](https://docs.warp.dev/agents/inference/bring-your-own-api-key/) / [Bring Your Own LLM（Enterprise）](https://docs.warp.dev/enterprise/enterprise-features/bring-your-own-llm/)
- [The New Stack: Warp's gamble](https://thenewstack.io/warp-open-source-client/)
- [EveryDev: The Real Product Is Oz](https://www.everydev.ai/p/news-warp-opensourced-its-terminal-code-the-real-product-is-oz)

---

**本記事の数値は2026年8月29日時点の実測です。** GitHubの各カウントはGitHub Search APIを月次で照会したもの、ビルドの所要時間はApple M5 / macOS 26.5.2 / Rust 1.92.0 の手元環境での実行結果です。Warpは開発が非常に活発なため、最新の値は各自ご確認ください。

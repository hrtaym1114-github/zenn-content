---
title: "従量APIの予算ガードはどこで素通りするか — NaN・負の金額・失敗した実行の記録漏れ"
emoji: "🧯"
type: "tech"
topics: ["Python", "CLI", "cron", "API", "個人開発"]
published: false
---

:::message alert
**この記事で扱う3つの問題のうち、どれもリリース版ではまだ直っていません。**

- 対象: [api-budget-guard](https://github.com/hrtaym1114-github/api-budget-guard) [v0.1.1](https://github.com/hrtaym1114-github/api-budget-guard/releases/tag/v0.1.1)（コミット `1ed0dc9`。2026-10-22 時点の `main` と同じ）
- 確認日: 2026-10-22（JST）。Linux / Python 3.13.5 の1台で再現
- 修正の状態: NaN と負の金額は、修正ブランチ `claude/v0.1.1-hardening-20261020` で拒否されることを確認しました。ただし**このブランチは未マージで、リリースもされていません**。失敗した実行が記録されない問題は、修正ブランチでも直っていません
- v0.1.1 を使っている場合の回避策は、後半の「v0.1.1 を使い続ける場合の回避策」の節にまとめました
:::

cron やスケジュール実行のエージェントに従量課金の API を呼ばせていると、気になるのは「誰も見ていない間に、どこまで使ってしまうか」です。そのために、実行前に見積もって上限を超えるなら止める小さな CLI、api-budget-guard を自分で作りました。

方針は fail-closed、つまり「判定できないときは止める」です。ところが自分たちでレビューしてみると、上限をそのまま素通りする経路が見つかりました。この記事はその失敗記録です。再現できたものだけを書いています。

## 無人の定期実行で支出に上限をかける手段

先に、ほかの手段と比べたときの位置づけを書いておきます。プロバイダ側の仕様は、公式ドキュメントで確認できた2社だけを載せました。

| 手段 | 実行前に止まるか | 気づく・止まるタイミング | 弱いところ |
|---|---|---|---|
| ダッシュボードを事後に確認する | 止まらない | 人が見たとき | 見るまでは何も起きない。Google Cloud は、利用から Cloud Billing への反映に遅れがあると明記している |
| プロバイダの支出上限（Anthropic） | 止まる | 自分で設定した月の上限に達したとき。リクエストが HTTP 400（`invalid_request_error`）を返す | 単位は組織の月額。ジョブ単位の上限ではない |
| プロバイダの予算（Google Cloud） | alerts-only の予算では止まらない | 通知のしきい値を超えたとき | 公式に「alerts-only の予算は利用や支出を自動で止めない」とある。spend cap の予算は対応サービスだけ |
| ジョブにハードコードした上限 | 止まる（そのジョブの中だけ） | ジョブが自分で数えた値を超えたとき | ジョブをまたいで合計できない。数え方はジョブごとにバラバラになる |
| 自作のガード（api-budget-guard） | 止まる（はずだった） | 実行前の `check`、または `run` でラップしたとき | 見積もりは設定ファイルの単価から計算するので実際の請求額ではない。入力の検証や記録の経路に穴があると素通りする（本記事） |

出典:

- Anthropic: [Rate limits — Spend limits](https://platform.claude.com/docs/en/api/rate-limits)（2026-10-22 確認）
- Google Cloud: [Create, edit, or delete budgets and budget alerts](https://cloud.google.com/billing/docs/how-to/budgets)（2026-10-22 確認）

プロバイダ側の上限はアカウント全体の最後の防波堤で、ジョブごとの細かい上限は手元で持つ、という分担になります。自作のガードはプロバイダの上限の代わりにはなりません。api-budget-guard の README も、プロバイダの請求アラートを置き換えることは目的に含めていません。

## 自作ガードの作り: 実行前に見積もって判定し、記録する

api-budget-guard の流れは次のとおりです。

1. 見積もる: 設定ファイルの単価 × 呼び出し件数
2. 判定する: 1回あたりの上限、ルーチンの期間上限、全体の上限、無料残高の安全マージン
3. 記録する: JSONL の台帳に1行追記する
4. 結果を終了コードで返す: `0` は実行してよい、`10` は縮退して実行、`20` は拒否

cron から使うときは、`run` でジョブを包みます。判定が `20` ならジョブは起動しません。設定ファイルや台帳がない、JSON が壊れているといった場合も `20` になるようにしてありました。

以下の再現はすべて x-api プリセットで `init` した直後の状態から、`API_BUDGET_GUARD_NOW=2026-10-22T12:00:00+09:00` に時刻を固定して実行しています。この日付では `keyword-watch` ルーチンの上限は、1回あたり $0.25、期間で $0.80 です（プリセットの単価は例示の値で、実際の価格ではありません）。

## 失敗記録1: NaN がすべての上限判定を通る

:::message alert
v0.1.1（`main`）で再現。修正ブランチ（未マージ）では拒否されることを確認済み。
:::

金額の引数は argparse の `type=float` で受けていました。Python の `float("nan")` は通るので、`--usd nan` がそのまま入ります。

```
$ api-budget-guard check --routine keyword-watch --usd nan
[go] keyword-watch: estimate $nan; spent $0.000 of $0.80; within budget
[exit 0]
$ api-budget-guard check --routine no-such-routine --usd nan
[go] no-such-routine: estimate $nan; spent $0.000; within budget
[exit 0]
```

判定は `estimate_usd > per_run` のような比較でできています。NaN との大小比較は常に False なので、「上限を超えたら拒否」のどの条件にも当たりません。上限が設定されていないルーチンを拒否する条件（`estimate_usd > 0 and not rc`）も False になり、存在しないルーチン名でも通りました。

`check` だけならその1回で済みますが、`record` で台帳に書くと後を引きます。

```
$ api-budget-guard record --routine keyword-watch --tool search_posts_all --usd nan
Recorded keyword-watch search_posts_all: $nan
[exit 0]
```

台帳にはこう残ります。`json.dumps` は既定で NaN を拒否しません。

```json
{"cost_usd": NaN, "kind": "spend", "objects": 0, "owned": false, "routine": "keyword-watch", "tool": "search_posts_all", "ts": "2026-10-22T12:00:00+09:00"}
```

このあと $7.50 を正しく記録しても、合計は NaN のままでした。

```
$ api-budget-guard record --routine keyword-watch --tool search_posts_all --usd 7.5
Recorded keyword-watch search_posts_all: $7.500
[exit 0]
$ api-budget-guard check --routine keyword-watch --call search_posts_all:10
[go] keyword-watch: estimate $0.050; spent $nan of $0.80; within budget
[exit 0]
```

上限 $0.80 に対して $7.50 使っているのに `go` です。合計に NaN が1つ混ざると、その期間の累計による判定はずっと効きません。

## 失敗記録2: 負の金額で支出合計が帳消しになる

:::message alert
v0.1.1（`main`）で再現。修正ブランチ（未マージ）では拒否されることを確認済み。
:::

`record --usd` は負の値も受け付けていました。上限ちょうどまで記録して拒否される状態を作り、そこに負の金額を1行入れます。

```
(record --objects 10 を16回。台帳は16行、合計 $0.80)
$ api-budget-guard check --routine keyword-watch --call search_posts_all:10
[deny] keyword-watch: estimate $0.050; spent $0.800 of $0.80; routine phase cap reached: $0.800 spent of $0.800
[exit 20]
$ api-budget-guard record --routine keyword-watch --tool search_posts_all --usd -10
Recorded keyword-watch search_posts_all: $-10.000
[exit 0]
$ api-budget-guard check --routine keyword-watch --call search_posts_all:10
[go] keyword-watch: estimate $0.050; spent $-9.200 of $0.80; within budget
[exit 0]
```

拒否されていたジョブが `go` に戻りました。返金や訂正のつもりで負の値を書く、計算ミスで差額が負になる、といった操作ミスでも同じことが起きます。

## 失敗記録3: 失敗した実行が台帳に記録されない

:::message alert
v0.1.1（`main`）で再現。**修正ブランチ（未マージ）でも同じ結果で、未修正です。**
:::

`run` は、ジョブが終了コード0で終わったときだけ見積もり額を記録していました。ジョブが失敗するとその終了コードを返すだけで、台帳には何も書きません。

```
$ api-budget-guard run --routine keyword-watch --call search_posts_all:50 -- python3 -c "raise SystemExit(3)"
[exit 3]
(同じ run をあと9回。台帳は0行のまま)
$ api-budget-guard check --routine keyword-watch --call search_posts_all:50
[go] keyword-watch: estimate $0.250; spent $0.000 of $0.80; within budget
[exit 0]
$ api-budget-guard run --routine keyword-watch --call search_posts_all:50 -- python3 -c "pass"
[exit 0]
(成功した1回だけ記録され、台帳は1行)
```

1回 $0.25 の見積もりで10回失敗しても、ガードから見た支出は $0 のままです。

実際の API ジョブは、何件か呼んで課金されたあとで失敗することがあります。失敗すると cron が次の回に同じジョブをもう一度走らせるので、失敗が続くほど、課金されているのに記録されない実行が積み上がります。「成功したときだけ記録する」は会計としては自然に見えますが、上限の判定に使う記録としては、止める方向とは逆に倒れていました。README にも「成功したあとに記録する」と書いていたので、仕様どおりの動きです。仕様の段階で fail-closed になっていませんでした。

## 3つに共通していたこと

設定ファイルや台帳の欠落、JSON の構文エラーには `20` を返すようにしていて、そこはテストもありました。v0.1.1 のテスト20件はすべて通っています。崩れていたのは別の場所でした。

- **入力の境界**: 「壊れたファイル」は拒否していたのに、「数値として読めるが意味のない値」（NaN、負の金額）は素通りしていた
- **比較の書き方**: 「超えたら拒否」と書くと、比較が成り立たない値は許可側に落ちる。「範囲内なら許可」と書いていれば、NaN は拒否側に落ちていた
- **記録の経路**: 判定は実行前にしていたのに、記録は成功したときだけだった。失敗した分の支出は、次の判定から見えない

どれも「異常系は止める」と決めたつもりで、異常の範囲を狭く取っていたことが原因でした。

## v0.1.1 を使い続ける場合の回避策

修正版がリリースされるまでの回避策です。ここに書いたうち、ジョブが失敗したときに自分で記録する方法（下のスクリプト）と台帳の点検（下の Python）は、v0.1.1 で実際に動かして確かめました。

- `--usd` に外から値を渡すときは、呼び出す前に「有限で0以上」かを確かめる。単価から計算させてよい場面では `--usd` ではなく `--call` / `--objects` を使う
- 台帳に NaN や負の `cost_usd` がないか定期的に点検する。見つかった行は手で直す

```python
import json, math

for n, line in enumerate(open("ledger.jsonl"), 1):
    row = json.loads(line)
    cost = row.get("cost_usd")
    if cost is not None and (not math.isfinite(cost) or cost < 0):
        print(f"line {n}: bad cost_usd {cost}")
```

- `run` が失敗したときは、呼び出し側で見積もり額を記録する。ガード自身の判定（`10` と `20`）と区別するため、それ以外の0でない終了コードのときだけ記録する

```bash
api-budget-guard run --routine keyword-watch --call search_posts_all:50 -- ./job.sh
rc=$?
if [ "$rc" -ne 0 ] && [ "$rc" -ne 10 ] && [ "$rc" -ne 20 ]; then
  api-budget-guard record --routine keyword-watch --tool search_posts_all \
    --objects 50 --note "failed run rc=$rc"
fi
```

この形で、終了コード3で失敗するジョブを繰り返し実行したところ、1回ごとに台帳が1行ずつ増え、4回目は `routine phase cap reached: $0.750 spent of $0.800` で拒否されてジョブが起動しませんでした。ただし、ジョブ自身が `10` や `20` で終わった場合は区別できず記録されません。ジョブ側で使う終了コードを `10` と `20` 以外にしておく必要があります。

## 自分のガードを点検するチェックリスト

api-budget-guard に限らず、自作のガードに当てはまる項目です。

- [ ] 金額・件数の入力は「有限で0以上」だけを受け付けているか（NaN、inf、負の値で試したか）
- [ ] 上限判定は「範囲内なら許可、それ以外は拒否」の形になっているか。比較できない値が許可側に落ちないか
- [ ] 台帳や設定から読んだ値も、同じ検証を通しているか（入口だけ検証して、保存済みのデータを信じていないか）
- [ ] 失敗した実行も支出として記録しているか。少なくとも「失敗」の種類を付けて残しているか
- [ ] ガード自身の拒否と、ジョブの失敗を終了コードで区別できるか
- [ ] 想定外の例外も拒否の終了コードになるか。呼び出し側は「許可の終了コード以外はすべて止める」と書いているか
- [ ] テストに、正常系と「ファイルが壊れた」だけでなく、「値がおかしい」「途中で失敗した」ケースがあるか
- [ ] プロバイダ側の上限やアラートも併せて設定しているか

## 修正の状態（2026-10-22 時点）

| 問題 | v0.1.1（`main`） | 修正ブランチ `claude/v0.1.1-hardening-20261020`（未マージ・未リリース） |
|---|---|---|
| NaN がすべての判定を通る | 再現 | `Denied: --usd must be a non-negative number: nan`（exit 20） |
| 負の金額で合計が減る | 再現 | `Denied: --usd must be a non-negative number: -10.0`（exit 20） |
| 失敗した実行が記録されない | 再現 | 再現（未修正） |

修正ブランチのテストは70件で、すべて通りました。上の表の拒否メッセージは、v0.1.1 と同じ入力を修正ブランチのコードで実行した結果です。

同じレビューで見つかった別の問題も1つ、どちらでも未修正です。`balance --usd 3.6 --paid 3.0` のように `--free` を省くと、無料残高が $3.60 として記録され、安全マージンの判定を通ってしまいます（同じ残高を `--free 0.6` で記録すると、$0.25 の見積もりは正しく拒否されました）。回避策は、`balance` では `--free` と `--paid` を両方指定することです。

## この記事で確かめていないこと

- Python 3.13.5 以外のバージョンでの挙動
- 実際のプロバイダ API を呼ぶジョブでの再現（ジョブは `python3 -c` のダミー）
- Anthropic と Google Cloud 以外のプロバイダの支出上限の仕様

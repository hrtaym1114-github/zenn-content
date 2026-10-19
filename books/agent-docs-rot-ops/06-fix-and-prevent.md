---
title: "直し方と再発防止 — rules層・hooks・CI（動かした出力つき）"
free: false
---

# 直し方と再発防止

章04と05から、直し方を手順にします。後半の hooks と CI は、スクリプトの全文と、2026-10-20 に実際に動かした出力を載せます。動かせなかった部分は「未検証」と書きます。

## 原則1: 値ではなく「正本の場所」を書く

モデル名・件数・残量・プラン名は、指示ファイルに書かない。代わりに、次の2つを書きます。

- 正本のファイル（例: スクリプトの既定値 `AGY_MODEL`）
- 確認コマンド（例: `ls .claude/commands | wc -l`、状態確認ツール）

コミットBがこの形です。値が変わっても、指示ファイルを直す必要がなくなります。

## 原則2: 参照は1つの基準で、機械に読める形で書く

- リポジトリルートからのパスに統一する。スキル内だけで閉じる参照は `./` から始めて明示する
- 「正本の場所」も同じ。コミットBで書いた `write-with-gemini.sh` はファイル名だけだったので、lint からは見つからない参照になった（章04）。`scripts/gemini-writer/write-with-gemini.sh` のようにパスで書く
- プレースホルダは `<日付>_<内容>.md` のように、実在パスと見分けがつく記法に揃える
- スラッシュコマンドは、名前空間を使うなら `/note:xxx` のように実際の呼び方で書く

## 原則3: ミラーは手で持たない

`.claude/skills` と `.agents/skills` のような二重管理は、片方を正本にして、もう片方はスクリプトで生成します。lint は正本だけに当てます。章05では357件の警告が両側で同じでした。

## 原則4: 改名は検索とセットにする

コマンドやファイルを改名するときは、指示ファイル群全体を旧名で検索してから閉じる。これを rules に書いておきます。

```markdown
<!-- .claude/rules/ 配下の例 -->
## 改名・削除時
コマンド・スキル・エージェント・参照ファイルを改名または削除したら、
CLAUDE.md / AGENTS.md / .claude/ / .agents/ を旧名で検索し、残った参照を同じ変更で直す。
直したあとに lint を流し、置き換え先の名前に実体があることを確かめる。
```

10/03 の監査では、rules の2か所を直して、スキルと登録表の7か所を残しました（章04）。

ただし公式ドキュメントのとおり、CLAUDE.md や rules は「文脈」であって強制ではありません。守らせたい場合は次の hooks へ。

## 共通部品: ベースライン差分スクリプト

hooks と CI の両方で、同じスクリプトを使います。「いまの警告」と「保存しておいた警告（ベースライン）」を比べ、**増えた分だけ** を出します。

```python:scripts/diff_baseline.py
#!/usr/bin/env python3
"""agent-docs-lint --json の結果をベースラインと比べ、新しく増えた警告だけを出す。
キーは (path, rule, message)。行番号はキーに入れない（前後の行が動くたびに新規扱いになるため）。
usage: diff_baseline.py BASELINE.json NOW.json   新規があれば exit 1
"""
import collections, json, sys

def keys(path):
    with open(path, encoding="utf-8") as fh:
        return collections.Counter((f["path"], f["rule"], f["message"]) for f in json.load(fh))

base, now = keys(sys.argv[1]), keys(sys.argv[2])
new, fixed = now - base, base - now
for (path, rule, message), n in sorted(new.items()):
    print(f"NEW {path}: {rule}: {message}" + (f" (x{n})" if n > 1 else ""))
print(f"baseline={sum(base.values())} now={sum(now.values())} new={sum(new.values())} fixed={sum(fixed.values())}")
sys.exit(1 if new else 0)
```

同じ指摘が同じファイルに複数あっても数えられるよう、集合ではなく多重集合（`Counter`）で差を取ります。

ベースラインは、現状の警告をそのまま保存してコミットします。

```sh
agent-docs-lint . --json --warn-only > lint-baseline.json
```

## hooks: 書いた直後に知らせる

Claude Code の PostToolUse フックで、指示ファイルが編集されたときだけ lint を回します。

```json:.claude/settings.json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/scripts/lint-agent-docs-if-changed.sh",
            "args": []
          }
        ]
      }
    ]
  }
}
```

```bash:scripts/lint-agent-docs-if-changed.sh
#!/usr/bin/env bash
# Claude Code PostToolUse フック。指示ファイルが編集されたときだけ lint し、
# ベースラインにない警告が増えていたら exit 2（stderr が Claude に返る）。
set -u
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
file=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))')
rel="${file#"$root"/}"
case "$rel" in
  CLAUDE.md|AGENTS.md|*/CLAUDE.md|*/AGENTS.md|.claude/*|.agents/*) ;;
  *) exit 0 ;;
esac
now=$(mktemp)
trap 'rm -f "$now"' EXIT
if ! agent-docs-lint "$root" --json --warn-only > "$now"; then
  echo "agent-docs-lint を実行できませんでした" >&2
  exit 1
fi
python3 "$root/scripts/diff_baseline.py" "$root/lint-baseline.json" "$now" >&2 || exit 2
exit 0
```

押さえておく仕様は2つです（[Hooks reference](https://code.claude.com/docs/en/hooks)、2026-10-20 参照）。

- PostToolUse で **exit 2** を返すと、stderr が Claude に渡る。exit 0 の stderr は Claude には見えない。exit 1 などそれ以外のコードは「止めないエラー」扱いで、画面に通知が出るだけ。ドキュメント上は Claude には届かない（exit 1 の場合を Claude Code 上では試していない）
- PostToolUse はツールが **実行されたあと** に走る。編集を取り消すことはできない。Claude に「いま腐りを足した」と知らせて、直させるための仕組み

### 動かした結果1: スクリプト単体

小さな一時リポジトリ（既存の警告2件をベースラインに入れたもの）で、フックへの入力 JSON を手で渡して試しました。

```text
== 変更なしで CLAUDE.md を編集した扱い
baseline=2 now=2 new=0 fixed=0
exit=0
== 対象外ファイル（docs/guide.md）
exit=0
== CLAUDE.md の2行目に、存在しないファイルとコマンドへの参照を足す
NEW CLAUDE.md: dead_ref: missing referenced path: docs/new-flow.md
NEW CLAUDE.md: dead_ref: missing slash command target: /release-check
baseline=2 now=4 new=2 fixed=0
exit=2
== agent-docs-lint が PATH にない環境
scripts/lint-agent-docs-if-changed.sh: line 14: agent-docs-lint: command not found
agent-docs-lint を実行できませんでした
exit=1
```

3つ目では、行を挿入したので既存の警告の行番号が1つずれています。それでも「新規」には数えられていません。行番号をキーに入れない理由がこれです。

4つ目の exit 1 は、上の仕様どおり Claude には届きません。lint が入っていない環境では、**フックは黙って何もしないのと同じ** になります。確実に止めたいなら、Claude Code v2.1.295 以降で使える `"onFailure": "block"` を検討してください（この設定は未検証）。

### 動かした結果2: 実際の Claude Code から

同じ一時リポジトリで Claude Code v2.1.299 を非対話モード（`claude -p`）で起動し、「CLAUDE.md に、存在しないファイル `docs/release-checklist.md` を参照する1行を足して」と頼みました。デバッグログにはこう残りました（時刻は JST に直しています）。

```text
2026-10-20 08:48:21 [DEBUG] Hooks: PostToolUse:Edit [${CLAUDE_PROJECT_DIR}/scripts/lint-agent-docs-if-changed.sh] finished with status 2 (91ms)
2026-10-20 08:48:21 [ERROR] "Hook PostToolUse:Edit (PostToolUse) error: status code 2
stderr:
NEW CLAUDE.md: dead_ref: missing referenced path: docs/release-checklist.md
baseline=2 now=3 new=1 fixed=0"
```

Claude は編集のあと、フックのメッセージを引用して「`docs/release-checklist.md` が存在しない」と報告しました。編集そのものは残っています。PostToolUse は止める仕組みではなく、知らせる仕組みだということが、この結果からも分かります。

### 動かした結果3: 実規模のリポジトリで

2026-10-12 時点のコミットを書き出したコピー（警告1,051件）に、同じスクリプトとベースラインを置きました。CLAUDE.md に存在しない参照を1行足した場合の結果です。

```text
NEW CLAUDE.md: dead_ref: missing referenced path: docs/does-not-exist.md
baseline=1051 now=1052 new=1 fixed=0
exit=2
real	0m1.234s
```

1,051件の既存警告があっても、出てくるのは足した1件だけです。1回あたり約1.2秒なので、編集ごとに走らせても待ち時間は気になりません（筆者の作業用マシンでの値）。

## CI: 新しく増えた分だけ落とす

既存の警告が数百件あるリポジトリで、いきなり「警告ゼロ」をゲートにするのは無理です。

1. 現状の警告を JSON で保存し、ベースラインとしてコミットする
2. CI ではベースラインとの差分だけを見て、**新規の警告が出たら落とす**
3. 直した分は、同じ PR でベースラインを作り直してコミットする

```yaml:.github/workflows/agent-docs-lint.yml
name: agent-docs-lint

on:
  pull_request:
    paths:
      - "CLAUDE.md"
      - "AGENTS.md"
      - "**/CLAUDE.md"
      - "**/AGENTS.md"
      - ".claude/**"
      - ".agents/**"
      - "lint-baseline.json"

jobs:
  new-findings-only:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install "git+https://github.com/hrtaym1114-github/agent-docs-lint.git@v0.1.0"
      - run: agent-docs-lint . --json --warn-only > "$RUNNER_TEMP/now.json"
      - run: python3 scripts/diff_baseline.py lint-baseline.json "$RUNNER_TEMP/now.json"
```

### 動かした結果4: CI と同じコマンドを手元で

**GitHub Actions 上での実行は未検証です。** 確かめたのは次の3つまでです。

- ワークフローの書式: actionlint 1.7.7 でエラーなし
- インストール行: 新しい仮想環境で `pip install "git+https://github.com/hrtaym1114-github/agent-docs-lint.git@v0.1.0"` が通り、`agent-docs-lint 0.1.0` が入った
- 後半2ステップ: `RUNNER_TEMP` を一時ディレクトリにして、同じコマンドを手元で実行した（Python 3.13。CI の 3.12 とは違う）

```text
== クリーン状態
baseline=2 now=2 new=0 fixed=0
step_exit=0
== 腐りを1件足したPR相当
NEW AGENTS.md: dead_ref: missing referenced path: docs/missing.md
baseline=2 now=3 new=1 fixed=0
step_exit=1
== 既存の腐りを1件直したPR相当
baseline=2 now=1 new=0 fixed=1
step_exit=0
```

3つ目のとおり、腐りを直しても CI は落ちません。ベースラインを作り直さないと `fixed=1` のまま残ります。CI では、ベースラインが減る方向にしか動かないことを強制していません。そこは PR のレビューで見ます。

## 検証状況のまとめ

| 項目 | 状態 |
| --- | --- |
| `diff_baseline.py`（行ずれ・新規・修正の判定） | 動いた |
| フックスクリプト単体（対象外ファイル・新規あり・新規なし・lint なし） | 動いた |
| 実際の Claude Code v2.1.299 からの PostToolUse 呼び出し | 動いた（exit 2、stderr が Claude に届いた） |
| 1,051件規模のリポジトリでの所要時間 | 約1.2秒 |
| `"onFailure": "block"` | 未検証 |
| ワークフローの書式（actionlint） | エラーなし |
| ワークフローの GitHub Actions 上での実行 | **未検証** |
| CI 後半2ステップの手元実行 | 動いた（Python 3.13 で） |
| Windows・macOS での動作 | 未検証 |

## 手作業監査の頻度

静的チェックで拾えない種類（外部ツールの仕様変更、方針の古さ、ファイル間の矛盾）のために、手作業監査や LLM 監査は残します。目安は「ワークフローを置き換えたとき」と「外部ツールのメジャー更新のとき」です。定期ではなく出来事に紐づけたほうが続く、というのは筆者の考えです（一般論で、測ってはいません）。

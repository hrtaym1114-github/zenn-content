# Playwright CLI vs MCP トークン消費量ベンチマーク

## 計測方法

Max plan では `/cost` が使えないため、**OpenTelemetry コンソール出力**でトークン数を自動収集する。

## すぐ始める手順

```bash
cd ~/Desktop/work1/zenn-content
./benchmarks/playwright-cli-vs-mcp/run-trial.sh cli simple 1
```

### STEP 1: Claude を起動

スクリプトが表示する起動コマンドをターミナル2にコピペして実行。
クリップボードはまだ使わないので自由にコピーしてOK。

```
Enter を押す
```

### STEP 2: プロンプトを貼り付け

Enter を押すとプロンプトがクリップボードにコピーされる。
ターミナル2で Cmd+V → Enter → タスク完了を待つ → `/exit`

```
Enter を押す
```

### STEP 3: ログ回収

OTelログを自動パース → ツール回数を入力 → 結果ファイル生成。

## 実行順序（全18試行）

交互実行でバイアスを分散する。

```
 # | コマンド
---|--------------------------------------------------
 1 | ./run-trial.sh cli simple 1
 2 | ./run-trial.sh mcp simple 1
 3 | ./run-trial.sh mcp simple 2
 4 | ./run-trial.sh cli simple 2
 5 | ./run-trial.sh cli simple 3
 6 | ./run-trial.sh mcp simple 3
 7 | ./run-trial.sh cli medium 1
 8 | ./run-trial.sh mcp medium 1
 9 | ./run-trial.sh mcp medium 2
10 | ./run-trial.sh cli medium 2
11 | ./run-trial.sh cli medium 3
12 | ./run-trial.sh mcp medium 3
13 | ./run-trial.sh cli complex 1
14 | ./run-trial.sh mcp complex 1
15 | ./run-trial.sh mcp complex 2
16 | ./run-trial.sh cli complex 2
17 | ./run-trial.sh cli complex 3
18 | ./run-trial.sh mcp complex 3
```

## 注意事項

- CLI試行: `--disallowedTools "mcp__playwright__*"` で MCPツール自動ブロック
- MCP試行: `--disallowedTools "Bash"` で Bashツール自動ブロック
- 各試行は必ず新規セッションで開始
- タスク実行中は人間の追加入力をしない
- `2>ファイル` の stderr リダイレクトを忘れないこと（OTelデータ取得に必須）
- 全試行完了後、`results/summary.md` に中央値を集計する

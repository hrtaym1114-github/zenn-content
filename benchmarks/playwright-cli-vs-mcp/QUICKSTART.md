# Playwright CLI vs MCP トークン消費量ベンチマーク

## 計測方法

Max plan では `/cost` が使えないため、**OpenTelemetry コンソール出力**でトークン数を自動収集する。

Claude Code 起動時に環境変数を設定すると、stderr に `claude_code.token.usage` メトリクスが出力される。スクリプトがこれをパースして input/output/cacheRead/cacheCreation 別に集計する。

## すぐ始める手順

### ターミナル1（記録用）

```bash
cd ~/Desktop/work1/zenn-content
./benchmarks/playwright-cli-vs-mcp/run-trial.sh cli simple 1
```

スクリプトがプロンプトをクリップボードにコピーし、ターミナル2で実行するコマンドを表示する。

### ターミナル2（計測用）

スクリプトが表示するコマンドをそのままコピペ:

```bash
CLAUDE_CODE_ENABLE_TELEMETRY=1 \
OTEL_METRICS_EXPORTER=console \
OTEL_METRIC_EXPORT_INTERVAL=5000 \
claude --no-chrome 2>raw-logs/cli/cli-simple-trial1-otel.log
```

セッション内で:
1. `Cmd+V` で貼り付け → Enter
2. タスク完了まで待つ（何も入力しない）
3. `/exit`

### ターミナル1に戻る

Enter → ツール呼び出し回数を入力 → 結果ファイルが自動生成される

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

- MCP版: Claude が `claude-in-chrome` ではなく `mcp__playwright__browser_*` ツールを使っているか確認
- 各試行は必ず新規セッション（`claude --no-chrome`）で開始
- タスク実行中は人間の追加入力をしない
- `2>ファイル` で stderr をリダイレクトしないとOTelデータが取れない
- 全試行完了後、`results/summary.md` に中央値を集計する

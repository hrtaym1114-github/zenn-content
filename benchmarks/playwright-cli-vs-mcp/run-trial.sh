#!/bin/zsh
# Playwright CLI vs MCP ベンチマーク 試行実行ヘルパー
# 計測方法: OpenTelemetry コンソール出力 + デバッグログ
#
# Usage:
#   ./run-trial.sh <method> <scenario> <trial_number>
#   例: ./run-trial.sh cli simple 1
#
# フロー:
#   STEP 1: 環境設定コマンドを表示 → 手動でターミナル2にコピーしてClaude起動
#   STEP 2: Enter → プロンプトをクリップボードにコピー → ターミナル2に貼り付け
#   STEP 3: Claude完了・/exit後 → Enter → ログ回収・結果生成

set -euo pipefail

METHOD="${1:?Usage: $0 <cli|mcp> <simple|medium|complex> <1|2|3>}"
SCENARIO="${2:?Usage: $0 <cli|mcp> <simple|medium|complex> <1|2|3>}"
TRIAL="${3:?Usage: $0 <cli|mcp> <simple|medium|complex> <1|2|3>}"

TRIAL_ID="${METHOD}-${SCENARIO}-trial${TRIAL}"
METHOD_UPPER=$(echo "$METHOD" | tr '[:lower:]' '[:upper:]')
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPTS_DIR="${BASE_DIR}/prompts"
LOGS_DIR="${BASE_DIR}/raw-logs/${METHOD}"
RESULTS_DIR="${BASE_DIR}/results"
PROMPT_FILE="${PROMPTS_DIR}/${SCENARIO}-${METHOD}.txt"
OTEL_LOG="${LOGS_DIR}/${TRIAL_ID}-otel.log"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: プロンプトファイルが見つかりません: $PROMPT_FILE"
  exit 1
fi

# 手法に応じてツール制限フラグを生成
if [ "$METHOD" = "cli" ]; then
  TOOL_FLAG='--disallowedTools "mcp__playwright__*"'
  TOOL_NOTE="mcp__playwright__* ブロック済み → Bash + playwright-cli のみ"
elif [ "$METHOD" = "mcp" ]; then
  TOOL_FLAG='--disallowedTools "Bash"'
  TOOL_NOTE="Bash ブロック済み → mcp__playwright__* のみ"
fi

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║  Playwright CLI vs MCP ベンチマーク        ║"
echo "╠════════════════════════════════════════════╣"
printf "║  試行ID:   %-30s ║\n" "${TRIAL_ID}"
printf "║  手法:     %-30s ║\n" "${METHOD_UPPER}"
printf "║  シナリオ: %-30s ║\n" "${SCENARIO}"
printf "║  試行:     %-30s ║\n" "#${TRIAL}"
echo "╚════════════════════════════════════════════╝"

# =============================================
# STEP 1: Claude 起動
# =============================================
echo ""
echo "━━━ STEP 1/3: ターミナル2で Claude を起動 ━━━"
echo ""
echo "  ⚠ 必ず以下のコマンドをそのままコピーして実行してください"
echo "  ⚠ --resume は使わないでください（新規セッション必須）"
echo ""
LAUNCH_CMD="CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_METRICS_EXPORTER=console OTEL_METRIC_EXPORT_INTERVAL=5000 claude --no-chrome --dangerously-skip-permissions ${TOOL_FLAG} 2>${OTEL_LOG}"
echo "  ${LAUNCH_CMD}"
echo ""
echo "  (${TOOL_NOTE})"
echo ""
# 起動コマンドをクリップボードにコピー（STEP2でプロンプトに上書きされる）
echo "$LAUNCH_CMD" | pbcopy
echo "  ✓ 起動コマンドをクリップボードにコピーしました"
echo "    → ターミナル2で Cmd+V → Enter"
echo ""
read "?Claude が起動したら Enter..."

# =============================================
# STEP 2: プロンプトをコピー → 貼り付け
# =============================================
echo ""
echo "━━━ STEP 2/3: プロンプトを貼り付けて実行 ━━━"
echo ""
cat "$PROMPT_FILE" | pbcopy
echo "  ✓ プロンプトをクリップボードにコピーしました！"
echo ""
echo "  --- プロンプト内容 ---"
cat "$PROMPT_FILE"
echo ""
echo "  -----------------------"
echo ""
echo "  ターミナル2で Cmd+V → Enter"
echo "  タスク完了を待ち、/exit で終了"
echo ""

START_TIME=$(date +%s)
read "?/exit 完了後 Enter..."
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# =============================================
# STEP 3: ログ回収 + 結果生成
# =============================================
echo ""
echo "━━━ STEP 3/3: ログ回収 ━━━"

# --- OTel ログからトークン集計 ---
INPUT_TOKENS=0
OUTPUT_TOKENS=0
CACHE_READ=0
CACHE_CREATION=0

if [ -f "$OTEL_LOG" ] && [ -s "$OTEL_LOG" ]; then
  echo ""
  echo "  ✓ OTelログ検出: ${OTEL_LOG}"

  INPUT_TOKENS=$(grep -o '"type":"input"[^}]*"value":[0-9]*' "$OTEL_LOG" 2>/dev/null \
    | grep -o '"value":[0-9]*' | grep -o '[0-9]*' \
    | awk '{s+=$1} END {print s+0}')
  OUTPUT_TOKENS=$(grep -o '"type":"output"[^}]*"value":[0-9]*' "$OTEL_LOG" 2>/dev/null \
    | grep -o '"value":[0-9]*' | grep -o '[0-9]*' \
    | awk '{s+=$1} END {print s+0}')
  CACHE_READ=$(grep -o '"type":"cacheRead"[^}]*"value":[0-9]*' "$OTEL_LOG" 2>/dev/null \
    | grep -o '"value":[0-9]*' | grep -o '[0-9]*' \
    | awk '{s+=$1} END {print s+0}')
  CACHE_CREATION=$(grep -o '"type":"cacheCreation"[^}]*"value":[0-9]*' "$OTEL_LOG" 2>/dev/null \
    | grep -o '"value":[0-9]*' | grep -o '[0-9]*' \
    | awk '{s+=$1} END {print s+0}')

  echo "    Input tokens:    ${INPUT_TOKENS}"
  echo "    Output tokens:   ${OUTPUT_TOKENS}"
  echo "    Cache read:      ${CACHE_READ}"
  echo "    Cache creation:  ${CACHE_CREATION}"
else
  echo ""
  echo "  ⚠ OTelログが空または見つかりません: ${OTEL_LOG}"
  echo "    手動でトークン数を入力してください"
  read "INPUT_TOKENS?    Input tokens:   "
  read "OUTPUT_TOKENS?    Output tokens:  "
  CACHE_READ=0
  CACHE_CREATION=0
fi

TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# ツール呼び出し回数（手動入力）
read "TOOL_CALLS?  ツール呼び出し回数: "
read "SUCCESS?  タスク成功? (y/n): "

if [ "$SUCCESS" = "y" ]; then
  SUCCESS_STR="YES"
else
  SUCCESS_STR="NO"
fi

# デバッグログ保存
DEBUG_DEST="${LOGS_DIR}/${TRIAL_ID}-debug.txt"
CONTEXT_MAX="N/A"
TOKENS_CSV=""
if [ -f "$HOME/.claude/debug/latest" ]; then
  cp "$HOME/.claude/debug/latest" "$DEBUG_DEST"
  echo ""
  echo "  ✓ デバッグログ保存: ${DEBUG_DEST}"

  TOKENS_CSV=$(grep "autocompact: tokens=" "$DEBUG_DEST" | sed 's/.*tokens=\([0-9]*\).*/\1/' | tr '\n' ',')
  CONTEXT_MAX=$(grep "autocompact: tokens=" "$DEBUG_DEST" | sed 's/.*tokens=\([0-9]*\).*/\1/' | sort -n | tail -1)
  if [ -n "$CONTEXT_MAX" ]; then
    echo "    コンテキスト推移: ${TOKENS_CSV%,}"
    echo "    コンテキスト最大: ${CONTEXT_MAX}"
  fi
fi

# 個別結果ファイル生成
RESULT_FILE="${RESULTS_DIR}/${TRIAL_ID}.md"
cat > "$RESULT_FILE" << RESULT_EOF
# ${TRIAL_ID}

- 日時: $(date '+%Y-%m-%d %H:%M:%S')
- 手法: ${METHOD_UPPER}
- シナリオ: ${SCENARIO}
- 実行時間: ${ELAPSED}秒

## トークン消費

| 指標 | 値 |
|------|-----|
| Input tokens | ${INPUT_TOKENS} |
| Output tokens | ${OUTPUT_TOKENS} |
| Cache read | ${CACHE_READ} |
| Cache creation | ${CACHE_CREATION} |
| **Total tokens** | **${TOTAL_TOKENS}** |

## 補助メトリクス

- ツール呼び出し回数: ${TOOL_CALLS}
- コンテキスト最大トークン数: ${CONTEXT_MAX}
- タスク成功: ${SUCCESS_STR}

## コンテキスト推移 (autocompact)

${TOKENS_CSV%,}
RESULT_EOF

echo ""
echo "  ✓ 結果ファイル保存: ${RESULT_FILE}"
echo ""
echo "╔════════════════════════════════════════════╗"
printf "║  %-42s ║\n" "${TRIAL_ID} 完了"
printf "║  Input:  %-33s ║\n" "${INPUT_TOKENS} tokens"
printf "║  Output: %-33s ║\n" "${OUTPUT_TOKENS} tokens"
printf "║  Total:  %-33s ║\n" "${TOTAL_TOKENS} tokens"
echo "╚════════════════════════════════════════════╝"

#!/bin/zsh
# Playwright CLI vs MCP ベンチマーク 試行実行ヘルパー
#
# Usage:
#   ./run-trial.sh <method> <scenario> <trial_number>
#   例: ./run-trial.sh cli simple 1
#
# 手順:
#   1. スクリプトがプロンプトをクリップボードにコピー
#   2. 別ターミナルで新規 Claude Code セッションを開始
#   3. /cost → プロンプト貼り付け → 完了後 /cost
#   4. このスクリプトに戻ってコスト値を入力
#   5. デバッグログ自動保存 + 結果ファイル生成

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

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: プロンプトファイルが見つかりません: $PROMPT_FILE"
  exit 1
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
echo ""

# プロンプトをクリップボードにコピー
cat "$PROMPT_FILE" | pbcopy
echo "✓ プロンプトをクリップボードにコピーしました"
echo ""
echo "--- 使用プロンプト ---"
cat "$PROMPT_FILE"
echo ""
echo "─────────────────────────────────────────────"
echo " 別ターミナルで以下を実行:"
echo ""
echo "   1. claude --no-chrome"
echo "   2. /cost          ← ベースライン確認"
echo "   3. Cmd+V で貼り付け → Enter"
echo "   4. タスク完了を待つ（介入しない）"
echo "   5. /cost          ← 最終値を確認"
echo "   6. /exit"
echo "─────────────────────────────────────────────"
echo ""

START_TIME=$(date +%s)
read -p "セッション完了後 Enter を押す..."
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "--- コスト記録 ---"
read -p "Input tokens (最終値):  " INPUT_TOKENS
read -p "Output tokens (最終値): " OUTPUT_TOKENS
read -p "Total cost USD:         " TOTAL_COST
read -p "ツール呼び出し回数:     " TOOL_CALLS
read -p "タスク成功? (y/n):      " SUCCESS

if [ "$SUCCESS" = "y" ]; then
  SUCCESS_STR="YES"
else
  SUCCESS_STR="NO"
fi

TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# デバッグログ保存
LOG_DEST="${LOGS_DIR}/${TRIAL_ID}.txt"
CONTEXT_MAX="N/A"
if [ -f "$HOME/.claude/debug/latest" ]; then
  cp "$HOME/.claude/debug/latest" "$LOG_DEST"
  echo ""
  echo "✓ デバッグログ保存: ${LOG_DEST}"

  # autocompact tokens を抽出
  TOKENS_CSV=$(grep "autocompact: tokens=" "$LOG_DEST" | sed 's/.*tokens=\([0-9]*\).*/\1/' | tr '\n' ',')
  CONTEXT_MAX=$(grep "autocompact: tokens=" "$LOG_DEST" | sed 's/.*tokens=\([0-9]*\).*/\1/' | sort -n | tail -1)
  echo "  コンテキスト推移: ${TOKENS_CSV%,}"
  echo "  コンテキスト最大: ${CONTEXT_MAX}"
else
  TOKENS_CSV=""
  echo "⚠ デバッグログが見つかりません"
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
| Total tokens | ${TOTAL_TOKENS} |
| Cost (USD) | ${TOTAL_COST} |

## 補助メトリクス

- ツール呼び出し回数: ${TOOL_CALLS}
- コンテキスト最大トークン数: ${CONTEXT_MAX}
- タスク成功: ${SUCCESS_STR}

## コンテキスト推移

${TOKENS_CSV%,}
RESULT_EOF

echo ""
echo "✓ 結果ファイル保存: ${RESULT_FILE}"
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║  ${TRIAL_ID} 完了"
printf "║  Total: %-10s tokens | Cost: \$%-8s║\n" "${TOTAL_TOKENS}" "${TOTAL_COST}"
echo "╚════════════════════════════════════════════╝"

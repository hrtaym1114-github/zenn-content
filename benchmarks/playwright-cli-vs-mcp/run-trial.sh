#!/bin/zsh
# Playwright CLI vs MCP ベンチマーク 試行実行ヘルパー
# 計測方法: デバッグログから claude_code.token.usage を抽出
#
# Usage:
#   ./run-trial.sh <method> <scenario> <trial_number>
#   例: ./run-trial.sh cli simple 1
#
# フロー:
#   STEP 1: 起動コマンドをクリップボードにコピー → ターミナル2に貼り付けてClaude起動
#   STEP 2: Enter → プロンプトをクリップボードにコピー → ターミナル2に貼り付け
#   STEP 3: /exit後 → Enter → デバッグログからトークン数を自動抽出

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
echo "  ⚠ 必ず以下のコマンドで新規セッション起動（--resume 禁止）"
echo ""
LAUNCH_CMD="CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_METRICS_EXPORTER=console OTEL_METRIC_EXPORT_INTERVAL=5000 claude --no-chrome --dangerously-skip-permissions ${TOOL_FLAG}"
echo "  ${LAUNCH_CMD}"
echo ""
echo "  (${TOOL_NOTE})"
echo ""
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
# STEP 3: デバッグログからトークン数を自動抽出
# =============================================
echo ""
echo "━━━ STEP 3/3: ログ回収 ━━━"

# デバッグログを保存
DEBUG_SRC="$HOME/.claude/debug/latest"
DEBUG_DEST="${LOGS_DIR}/${TRIAL_ID}-debug.txt"

if [ ! -f "$DEBUG_SRC" ] || [ ! -s "$DEBUG_SRC" ]; then
  echo ""
  echo "  ⚠ デバッグログが見つかりません"
  echo "    手動でトークン数を入力してください"
  read "INPUT_TOKENS?    Input tokens:   "
  read "OUTPUT_TOKENS?    Output tokens:  "
  read "CACHE_READ?    Cache read:     "
  read "CACHE_CREATION?    Cache creation: "
else
  cp "$DEBUG_SRC" "$DEBUG_DEST"
  echo "  ✓ デバッグログ保存: ${DEBUG_DEST}"

  # claude_code.token.usage セクションからトークン数を集計
  # 形式: type: 'input' / 'output' / 'cacheRead' / 'cacheCreation' の後に value: N
  INPUT_TOKENS=$(awk "
    /name: 'claude_code.token.usage'/ { in_token=1 }
    in_token && /type: 'input'/ { found_type=1 }
    found_type && /value:/ { gsub(/[^0-9]/,\"\",\$2); sum+=\$2; found_type=0 }
    /^[^ ]/ && !/value:/ { in_token=0 }
  END { print sum+0 }" "$DEBUG_DEST")

  OUTPUT_TOKENS=$(awk "
    /name: 'claude_code.token.usage'/ { in_token=1 }
    in_token && /type: 'output'/ { found_type=1 }
    found_type && /value:/ { gsub(/[^0-9]/,\"\",\$2); sum+=\$2; found_type=0 }
    /^[^ ]/ && !/value:/ { in_token=0 }
  END { print sum+0 }" "$DEBUG_DEST")

  CACHE_READ=$(awk "
    /name: 'claude_code.token.usage'/ { in_token=1 }
    in_token && /type: 'cacheRead'/ { found_type=1 }
    found_type && /value:/ { gsub(/[^0-9]/,\"\",\$2); sum+=\$2; found_type=0 }
    /^[^ ]/ && !/value:/ { in_token=0 }
  END { print sum+0 }" "$DEBUG_DEST")

  CACHE_CREATION=$(awk "
    /name: 'claude_code.token.usage'/ { in_token=1 }
    in_token && /type: 'cacheCreation'/ { found_type=1 }
    found_type && /value:/ { gsub(/[^0-9]/,\"\",\$2); sum+=\$2; found_type=0 }
    /^[^ ]/ && !/value:/ { in_token=0 }
  END { print sum+0 }" "$DEBUG_DEST")

  echo ""
  echo "  --- トークン集計（デバッグログから自動抽出）---"
  echo "    Input tokens:    ${INPUT_TOKENS}"
  echo "    Output tokens:   ${OUTPUT_TOKENS}"
  echo "    Cache read:      ${CACHE_READ}"
  echo "    Cache creation:  ${CACHE_CREATION}"
fi

TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# autocompact からコンテキスト推移を抽出
CONTEXT_MAX="N/A"
TOKENS_CSV=""
if [ -f "$DEBUG_DEST" ]; then
  TOKENS_CSV=$(grep "autocompact: tokens=" "$DEBUG_DEST" | sed 's/.*tokens=\([0-9]*\).*/\1/' | tr '\n' ',')
  CONTEXT_MAX=$(grep "autocompact: tokens=" "$DEBUG_DEST" | sed 's/.*tokens=\([0-9]*\).*/\1/' | sort -n | tail -1)
  if [ -n "$CONTEXT_MAX" ]; then
    echo "    コンテキスト最大: ${CONTEXT_MAX}"
  fi
fi

# ツール呼び出し回数（デバッグログから自動取得）
TOOL_CALLS=0
if [ -f "$DEBUG_DEST" ]; then
  TOOL_CALLS=$(grep -c "Getting matching hook commands for PreToolUse" "$DEBUG_DEST" 2>/dev/null || echo 0)
fi
echo "    ツール呼び出し回数: ${TOOL_CALLS}"
echo ""
read "SUCCESS?  タスク成功? (y/n): "

if [ "$SUCCESS" = "y" ]; then
  SUCCESS_STR="YES"
else
  SUCCESS_STR="NO"
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
printf "║  Cache:  %-33s ║\n" "$((CACHE_READ + CACHE_CREATION)) tokens"
printf "║  Total:  %-33s ║\n" "${TOTAL_TOKENS} tokens"
echo "╚════════════════════════════════════════════╝"

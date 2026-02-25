# Playwright CLI vs MCP トークン消費量 実測サマリー

## 計測環境

- Claude Code: v2.1.58
- Model: claude-opus-4-6
- OS: macOS Darwin 25.3.0
- @playwright/cli: v1.59.0-alpha-1771104257000
- @playwright/mcp: latest (stdio via npx)
- 計測日: 2026-02-26

## 結果一覧

### Simple: ページ読み取り

| 試行 | 手法 | Input tokens | Output tokens | Total tokens | Cost | ツール回数 |
|------|------|-------------|---------------|-------------|------|-----------|
| 1 | CLI | | | | | |
| 2 | CLI | | | | | |
| 3 | CLI | | | | | |
| 1 | MCP | | | | | |
| 2 | MCP | | | | | |
| 3 | MCP | | | | | |

### Medium: フォーム入力

| 試行 | 手法 | Input tokens | Output tokens | Total tokens | Cost | ツール回数 |
|------|------|-------------|---------------|-------------|------|-----------|
| 1 | CLI | | | | | |
| 2 | CLI | | | | | |
| 3 | CLI | | | | | |
| 1 | MCP | | | | | |
| 2 | MCP | | | | | |
| 3 | MCP | | | | | |

### Complex: マルチステップ

| 試行 | 手法 | Input tokens | Output tokens | Total tokens | Cost | ツール回数 |
|------|------|-------------|---------------|-------------|------|-----------|
| 1 | CLI | | | | | |
| 2 | CLI | | | | | |
| 3 | CLI | | | | | |
| 1 | MCP | | | | | |
| 2 | MCP | | | | | |
| 3 | MCP | | | | | |

## 集計（中央値）

| シナリオ | 指標 | CLI | MCP | 削減率 |
|----------|------|-----|-----|--------|
| Simple | Total tokens | | | x |
| Simple | ツール回数 | | | - |
| Medium | Total tokens | | | x |
| Medium | ツール回数 | | | - |
| Complex | Total tokens | | | x |
| Complex | ツール回数 | | | - |

## コンテキスト成長データ（Complex trial 1）

### CLI

```
ターン, tokens
```

### MCP

```
ターン, tokens
```

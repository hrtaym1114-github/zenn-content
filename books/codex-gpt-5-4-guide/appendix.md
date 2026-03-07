---
title: "付録"
---

# 付録

## A. トラブルシューティング

| 問題 | 解決策 |
|------|--------|
| GPT-5.4 Proがタイムアウトする | バックグラウンドモードを使用。`xhigh`推論は数分かかる |
| 長文入力でコストが予想以上 | 272K超で2倍料金。入力を272K以下に抑えるか、要約してから送る |
| Codexタスクが30分以上かかる | タスクを分割して並列実行する |
| Computer Use操作が不正確 | スクリーンショットの解像度と対象アプリの状態を確認 |
| Tool Searchで適切なツールが選ばれない | ツールの説明文を改善し、名前を明確にする |

## B. 用語集

| 用語 | 説明 |
|------|------|
| Codex | OpenAIのクラウドベースソフトウェアエンジニアリングエージェント |
| Computer Use | AIがスクリーンショットを見てマウス/キーボードを操作する能力 |
| Tool Search | 多数のツール定義を効率的に検索・利用する機能 |
| Extreme Reasoning (xhigh) | 最大限の計算リソースで推論する最高レベルモード |
| OSWorld | デスクトップ操作能力を測定するベンチマーク |
| SWE-bench | ソフトウェアエンジニアリング能力を測定するベンチマーク |
| Worktree | Gitの機能。同一リポジトリの複数コピーで並行作業 |
| MCP | Model Context Protocol。AIモデルと外部ツールの接続規格 |
| Responses API | OpenAIの新しいAPI形式。マルチターン対話やツール利用に対応 |
| Sandbox | 隔離されたコンテナ環境。外部アクセス不可 |

## C. 参考リンク

- [Introducing GPT-5.4 | OpenAI](https://openai.com/index/introducing-gpt-5-4/)
- [GPT-5.4 Model | OpenAI API](https://developers.openai.com/api/docs/models/gpt-5.4)
- [GPT-5.4 Pro Model | OpenAI API](https://developers.openai.com/api/docs/models/gpt-5.4-pro)
- [Codex公式ページ | OpenAI](https://openai.com/codex/)
- [Codex Models](https://developers.openai.com/codex/models/)
- [Codex Pricing](https://developers.openai.com/codex/pricing/)
- [Codex Changelog](https://developers.openai.com/codex/changelog/)
- [Using GPT-5.4 | OpenAI API](https://developers.openai.com/api/docs/guides/latest-model/)
- [Prompt guidance for GPT-5.4](https://developers.openai.com/api/docs/guides/prompt-guidance)
- [Codex Security](https://developers.openai.com/codex/security/)

## D. 関連技術との比較

| 製品/技術 | 提供元 | 特徴 | GPT-5.4との関係 |
|-----------|--------|------|-----------------|
| Claude Code | Anthropic | CLI型コーディングエージェント | 競合。推論力で優位 |
| Gemini 3.1 | Google | マルチモーダルモデル | 競合 |
| Copilot | Microsoft/GitHub | IDE統合型コード補完 | Codexと連携可能 |
| Cursor | Cursor Inc. | AI搭載コードエディタ | 独立製品。GPT-5.4をバックエンドに使用可能 |
| Devin | Cognition | 自律型ソフトウェアエンジニア | 競合。Codexと類似コンセプト |

## E. GPT-5.4 リリースタイムライン

| 日付 | イベント |
|------|---------|
| 2025年後半 | GPT-5.2リリース |
| 2026年2月5日 | GPT-5.3-Codexリリース（コーディング特化） |
| 2026年2月上旬 | GPT-5.3-Codex、Microsoft Foundryリーダーボード1位獲得 |
| 2026年3月4日 | Codex Windows版リリース |
| 2026年3月5日 | **GPT-5.4リリース**（ChatGPT、Codex、API） |

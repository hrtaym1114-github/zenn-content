---
title: "Codexアプリとマルチエージェント"
---

# Codexアプリとマルチエージェント

## Codexアプリ

CodexにはmacOS版・Windows版（2026年3月4日〜）のデスクトップアプリがあります。

- 複数のエージェントを同時管理
- 並列タスク実行
- 長時間タスクとのコラボレーション

## マルチエージェント機能

Codexの大きな特徴は、**複数のエージェントを並列に動かせる**ことです。

- **Worktree（ワークツリー）対応**: 各エージェントがリポジトリの独立コピーで作業
- **コンフリクト回避**: エージェント間のコード衝突を防止
- **異なるパスの探索**: 複数のアプローチを同時に試行可能

```
プロジェクト
+-- Agent A: 新機能の実装
+-- Agent B: バグ修正
+-- Agent C: テスト追加
+-- Agent D: リファクタリング
```

## GitHub連携

- GitHubリポジトリとの直接連携
- GitHub上のClaude / Codexの選択が可能（Copilot Pro+ / Enterprise）
- 将来的にはイシュートラッカーやCIシステムからのタスク割り当ても予定

## Agents SDK連携

OpenAIのAgents SDKを使ってCodexをプログラマティックに操作できます。

```python
# Agents SDKでCodexを利用するイメージ
from openai import OpenAI

client = OpenAI()
# Codex APIを通じてタスクを投入
```

## /fast モード

Codex内の`/fast`モードで**トークン速度を1.5倍**に向上（知性レベルは維持）。素早いイテレーションが必要な場面で有用です。

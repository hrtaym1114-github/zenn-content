---
title: "API利用ガイド"
---

# API利用ガイド

## モデルID

| モデル | ID | 用途 |
|--------|-------|------|
| GPT-5.4 | `gpt-5.4` | 汎用・コーディング・エージェント |
| GPT-5.4 Pro | `gpt-5.4-pro` | 最高難度のタスク |

## 基本的なAPI呼び出し

```python
from openai import OpenAI

client = OpenAI()

response = client.responses.create(
    model="gpt-5.4",
    input="Pythonで効率的なマージソートを実装してください",
)

print(response.output_text)
```

## 推論レベルの指定

```python
response = client.responses.create(
    model="gpt-5.4",
    reasoning={"effort": "high"},
    input="この数学の証明を検証してください: ..."
)
```

## Tool Searchの利用

多数のツールを登録する場合、Tool Search機能を有効化してトークン消費を削減できます。

```python
response = client.responses.create(
    model="gpt-5.4",
    tools=[...],  # 多数のツール定義
    tool_search=True,  # Tool Search有効化
    input="このデータを分析してグラフを作成して"
)
```

## Computer Useの利用

Computer Use機能を使ってブラウザやデスクトップアプリを操作できます。

```python
# Playwrightベースの操作コード生成
response = client.responses.create(
    model="gpt-5.4",
    input="Google Sheetsを開いてA1セルに'Hello'と入力して",
    tools=[{"type": "computer_use"}]
)
```

## 長文コンテキストの利用

1Mトークンのコンテキストウィンドウを活用できます。

- 大規模コードベースの全体を読み込ませて質問
- 長いドキュメントの分析
- 複数ファイルにまたがるリファクタリング

:::message alert
272,000トークンを超える入力は**2倍料金**になります。
:::

## GPT-5.4 Proの利用

```python
# Responses APIのみ対応
response = client.responses.create(
    model="gpt-5.4-pro",
    reasoning={"effort": "xhigh"},
    input="この複雑な最適化問題を解いてください: ..."
)
```

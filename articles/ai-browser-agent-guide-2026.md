---
title: "【2026年最新】AIブラウザエージェント完全ガイド — Browser Use・Stagehand・主要ツール徹底比較"
emoji: "🌐"
type: "tech"
topics: ["AI", "BrowserUse", "Playwright", "Python", "TypeScript"]
published: false
---

## この記事で分かること

AIがブラウザを自律操作する「ブラウザエージェント」が2026年に入って急速に実用化されています。Browser Useは GitHub 78,000+ スター、Stagehandは 21,000+ スターを獲得し、企業での採用も加速中です。

この記事では、**主要なAIブラウザエージェントツールの仕組み・使い方・選び方**を、実際のコード例とともに解説します。

:::message
**対象読者**: AIを使った自動化に興味があるエンジニア（中級〜）。Playwright等のブラウザ自動化の基礎知識があると理解しやすいですが、なくても読めます。
:::

## AIブラウザエージェントとは

従来のブラウザ自動化（Selenium、Playwright等）は「CSSセレクタでボタンを特定 → クリック」という**決定的なスクリプト**で動きます。サイトのHTML構造が変わるたびにスクリプトが壊れる、いわゆる「セレクタ地獄」が宿命でした。

AIブラウザエージェントは、LLM（大規模言語モデル）がページの内容を**意味的に理解**し、自律的に判断・操作します。

```
従来: "button#submit をクリック" → HTML変更で壊れる
AI:   "送信ボタンをクリック" → ページ構造が変わっても動く
```

この違いは根本的です。セレクタ駆動から**目標駆動**への転換により、自動化の保守コストが劇的に下がります。

### なぜ2026年に実用化したのか

3つの要因が重なりました:

1. **LLMの推論能力向上** — Claude 4、GPT-4o、Gemini 2.5がWebページの構造を正確に解釈できるようになった
2. **クラウドブラウザ基盤の成熟** — BrowserbaseやSteelがエージェント向けのマネージドブラウザを提供
3. **オープンソースの爆発** — Browser Use、Stagehand等のフレームワークが登場し、数行のコードで実装可能に

AI Browser市場は2024年の45億ドルから2034年には768億ドルへ成長すると予測されています（CAGR 32.8%）。

## 主要ツール比較一覧

2026年3月時点の主要ツールを整理します。

### 開発者向けフレームワーク

| ツール | 言語 | GitHub Stars | 特徴 | LLM |
|--------|------|-------------|------|-----|
| **Browser Use** | Python | 78,000+ | 最も人気。柔軟なカスタマイズ | Claude, GPT, Gemini, Ollama |
| **Stagehand** | TypeScript | 21,000+ | act/extract/observe の3プリミティブ | Claude, GPT, Gemini |
| **Agent Browser** | Rust | 14,000+ | CLI特化。高速 | 各種LLM |
| **Skyvern** | Python | 20,000+ | ノーコード。フォーム自動化に強い | 各種LLM |
| **Steel** | — | 6,400+ | セルフホスト型インフラ | — |

### クラウドプラットフォーム

| ツール | 形態 | 特徴 |
|--------|------|------|
| **Browserbase** | マネージドクラウド | Stagehandと統合。2025年に5,000万セッション処理 |
| **Firecrawl** | API + サンドボックス | スクレイピング特化。82,000+ Stars |

### コンシューマー向け

| ツール | 月額 | 特徴 |
|--------|------|------|
| **Perplexity Comet** | 無料〜$200 | 自律ブラウジング + メール/カレンダー統合 |
| **ChatGPT Atlas** | 無料〜$20 | Agent Modeで独立タスク実行 |

:::message
この記事では**開発者向けフレームワーク**に焦点を当て、特に人気の高いBrowser UseとStagehandを深掘りします。
:::

## Browser Use — Python で最速スタート

Browser Useは、Pythonで書かれたオープンソースのAIブラウザエージェントフレームワークです。WebVoyagerベンチマークで**89.1%の成功率**を達成しており、現時点で最も実績のあるツールです。

### セットアップ

Python 3.11以上が必要です:

```bash
# プロジェクト初期化
uv init my-browser-agent && cd my-browser-agent
uv add browser-use
uv sync

# Chromium が入っていない場合
uvx browser-use install
```

環境変数を設定:

```bash
# .env
OPENAI_API_KEY=sk-...
# または
ANTHROPIC_API_KEY=sk-ant-...
```

### 基本的な使い方

```python
from browser_use import Agent, Browser, ChatBrowserUse
import asyncio

async def main():
    browser = Browser()
    agent = Agent(
        task="GitHubでbrowser-useリポジトリのスター数を調べて",
        llm=ChatBrowserUse(),  # 最適化済みモデル
        browser=browser,
    )
    result = await agent.run()
    print(result)

asyncio.run(main())
```

たった数行で、AIがブラウザを開き、GitHubに移動し、スター数を取得して返します。

### LLMの選択

Browser Useは複数のLLMに対応しています:

```python
# Browser Use独自の最適化モデル（最安）
from browser_use import ChatBrowserUse
llm = ChatBrowserUse()  # $0.20/1M入力, $2.00/1M出力

# Anthropic Claude
from langchain_anthropic import ChatAnthropic
llm = ChatAnthropic(model="claude-sonnet-4-6")

# Google Gemini
from langchain_google_genai import ChatGoogleGenerativeAI
llm = ChatGoogleGenerativeAI(model="gemini-3-flash-preview")

# OpenAI
from langchain_openai import ChatOpenAI
llm = ChatOpenAI(model="gpt-4o")

# Ollama（ローカル実行）
from langchain_ollama import ChatOllama
llm = ChatOllama(model="llama3")
```

### カスタムツールの追加

エージェントに独自の能力を追加できます:

```python
from browser_use import Agent, Controller

controller = Controller()

@controller.action("ファイルにテキストを保存する")
def save_to_file(text: str, filename: str):
    with open(filename, "w") as f:
        f.write(text)
    return f"Saved to {filename}"

agent = Agent(
    task="Hacker Newsのトップ記事を取得してresults.txtに保存して",
    llm=ChatBrowserUse(),
    controller=controller,
)
```

### 実践例: 競合価格モニタリング

```python
from browser_use import Agent, Browser
import json

async def monitor_prices():
    browser = Browser()
    agent = Agent(
        task="""
        以下のECサイトで「MacBook Air M4」の価格を調べて:
        1. Amazon.co.jp
        2. ヨドバシカメラ
        3. ビックカメラ
        各サイトの最安値をJSON形式で返して。
        """,
        llm=ChatBrowserUse(),
        browser=browser,
    )
    result = await agent.run()
    prices = json.loads(result)
    print(json.dumps(prices, ensure_ascii=False, indent=2))
```

## Stagehand — TypeScript で精密制御

Stagehandは、Browserbaseが開発するTypeScript/Python対応のブラウザ自動化フレームワークです。Browser Useが「タスクを丸投げ」するスタイルなのに対し、Stagehandは**3つのプリミティブ**で精密な制御を提供します。

### セットアップ

```bash
npx create-browser-app
```

これだけでプロジェクトの雛形が生成されます。

### 3つのプリミティブ: act / extract / observe

Stagehandの設計哲学は「自然言語とコードの融合」です。

**act — アクションの実行:**

```typescript
// 自然言語で操作を指示
await stagehand.act("検索ボックスに'AI browser agent'と入力してEnterを押す");

// より具体的に
await stagehand.act("ログインボタンをクリック");
```

**extract — 構造化データの抽出:**

```typescript
import { z } from "zod";

// Zodスキーマで型安全にデータ抽出
const { author, title, stars } = await stagehand.extract(
  "リポジトリの作者名、タイトル、スター数を抽出して",
  z.object({
    author: z.string().describe("リポジトリの作者名"),
    title: z.string().describe("リポジトリのタイトル"),
    stars: z.number().describe("スター数"),
  }),
);

console.log(`${author}/${title}: ${stars} stars`);
```

**observe — ページの観察:**

```typescript
// ページの状態を確認
const elements = await stagehand.observe("ページ上のナビゲーションリンク一覧");
console.log(elements);
```

### Agent Mode（マルチステップ）

複雑なワークフローにはAgent Modeを使います:

```typescript
const agent = stagehand.agent();

await agent.execute(
  "GitHubにログインし、最新のPull Requestを見つけて、レビューコメントを確認して"
);
```

### Playwrightとの併用

Stagehandの強みは、AI操作と従来のPlaywright操作を**シームレスに混ぜられる**ことです:

```typescript
// Playwrightの精密な操作
const page = stagehand.context.pages()[0];
await page.goto("https://example.com");

// AI操作に切り替え
await stagehand.act("Cookieバナーを閉じる");

// また Playwright に戻る
const content = await page.textContent("main");
```

この柔軟性は、「ほとんどは決定的なスクリプトで十分だが、一部だけAIの判断が必要」というケースに最適です。

## Browser Use vs Stagehand — どちらを選ぶ？

| 観点 | Browser Use | Stagehand |
|------|------------|-----------|
| **言語** | Python | TypeScript（Python版もあり） |
| **設計思想** | タスク丸投げ型 | プリミティブ組み合わせ型 |
| **制御の粒度** | 粗い（タスク単位） | 細かい（アクション単位） |
| **学習コスト** | 低い | やや高い |
| **カスタマイズ性** | カスタムツール追加 | Playwright完全統合 |
| **ベンチマーク** | WebVoyager 89.1% | — |
| **本番利用** | Cloud版あり | Browserbase統合 |
| **コスト** | 完全無料（LLM費用のみ） | 完全無料（LLM費用のみ） |

### 選定ガイド

**Browser Useを選ぶべきケース:**
- Pythonがメイン言語
- 「やりたいことを自然言語で投げたい」スタイル
- プロトタイプを最速で作りたい
- データスクレイピング・リサーチ自動化が目的

**Stagehandを選ぶべきケース:**
- TypeScriptがメイン言語
- 精密な制御が必要（金融系、フォーム入力等）
- 既存のPlaywrightテストコードがある
- 型安全にデータ抽出したい（Zodスキーマ）

## 実践パターン集

### パターン1: Webリサーチの自動化

複数ソースから情報を集約するエージェント:

```python
from browser_use import Agent

agent = Agent(
    task="""
    「AIブラウザエージェント」について以下を調査して:
    1. 最新のトレンド（2026年のニュース3件）
    2. 主要ツールの比較表
    3. 日本語の技術記事やブログ

    結果をMarkdown形式でまとめて。
    """,
    llm=ChatBrowserUse(),
)
```

### パターン2: フォーム自動入力

申請書や注文フォームの自動化:

```typescript
// Stagehand でフォーム入力
await stagehand.act("名前欄に '田中太郎' と入力");
await stagehand.act("メールアドレス欄に 'tanaka@example.com' と入力");
await stagehand.act("送信ボタンをクリック");
```

### パターン3: テスト自動化

E2Eテストを自然言語で記述:

```python
from browser_use import Agent

agent = Agent(
    task="""
    https://myapp.example.com にアクセスして以下をテスト:
    1. ログインページが表示されるか確認
    2. テストユーザーでログイン（user: test@example.com, pass: test123）
    3. ダッシュボードが正しく表示されるか確認
    4. ログアウトボタンが機能するか確認
    各ステップの結果を報告して。
    """,
    llm=ChatBrowserUse(),
)
```

## アンチパターン・注意点

### 1. LLMコストの見落とし

ブラウザエージェントはページ遷移のたびにLLMを呼び出します。複雑なタスクでは**数十回のAPI呼び出し**になることも。

:::message alert
1タスクあたりのLLMコストを事前に見積もりましょう。Browser UseのChatBrowserUseモデル（$0.20/1M入力トークン）は比較的安価ですが、Claude 4やGPT-4oを使うとコストが跳ね上がります。開発中はローカルモデル（Ollama）でテストし、本番だけ高性能モデルを使う戦略が有効です。
:::

### 2. 認証情報のハードコーディング

```python
# ❌ NG: パスワードをコードに直書き
agent = Agent(task="user: admin, password: P@ssw0rd でログイン")

# ✅ OK: 環境変数から読み込み
import os
agent = Agent(
    task=f"user: {os.environ['APP_USER']}, password: {os.environ['APP_PASS']} でログイン"
)
```

### 3. 無限ループの放置

エージェントがページ遷移を繰り返して止まらないケースがあります。必ずタイムアウトや最大ステップ数を設定しましょう。

### 4. CAPTCHAへの過信

多くのツールがCAPTCHA対応を謳っていますが、完璧ではありません。CAPTCHA頻出サイトを自動化する場合は、APIベースのアプローチを検討してください。

### 5. 利用規約の確認不足

:::message alert
ブラウザ自動化は対象サイトの利用規約に抵触する可能性があります。特にスクレイピング目的の場合、`robots.txt`の確認と利用規約の精読は必須です。
:::

## まとめ

- **AIブラウザエージェント**は、LLMがWebページを意味的に理解し自律操作する新しい自動化パラダイム
- **Browser Use**（Python / 78K+ Stars）はタスク丸投げ型で最速スタート。WebVoyager 89.1%の実績
- **Stagehand**（TypeScript / 21K+ Stars）はact/extract/observeの3プリミティブで精密制御。Playwrightとシームレスに統合
- 選定基準: **Python → Browser Use**、**TypeScript → Stagehand**、精密制御が必要なら Stagehand
- コスト管理（LLM呼び出し回数）とセキュリティ（認証情報の扱い）には特に注意

## 参考リンク

- [Browser Use — GitHub](https://github.com/browser-use/browser-use)
- [Browser Use 公式サイト](https://browser-use.com/)
- [Stagehand — GitHub](https://github.com/browserbase/stagehand)
- [Stagehand 公式ドキュメント](https://docs.browserbase.com/introduction/stagehand)
- [Browserbase](https://www.browserbase.com/)
- [11 Best AI Browser Agents in 2026 — Firecrawl Blog](https://www.firecrawl.dev/blog/best-browser-agents)
- [10 Best Agentic Browsers for AI Automation in 2026 — Bright Data](https://brightdata.com/blog/ai/best-agent-browsers)
- [The State of AI & Browser Automation in 2026 — Browserless](https://www.browserless.io/blog/state-of-ai-browser-automation-2026)

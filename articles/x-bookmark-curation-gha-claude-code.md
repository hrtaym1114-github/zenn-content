---
title: "X.comブックマークをGitHub Actions × Claude Codeで自動キュレーションする"
emoji: "📚"
type: "tech"
topics: ["ClaudeCode", "GitHubActions", "XTwitterAPI", "OAuth", "Python"]
published: true
---

## この記事で分かること

X.comのブックマークが「後で読む」→「永遠に読まない」になっていませんか？

この記事では、**X API v2 + GitHub Actions + Claude Code** を組み合わせて、ブックマークを毎日自動で分類・要約し、Markdownダイジェストとして蓄積する仕組みを紹介します。

具体的には以下を解説します：

- X API v2 Bookmarks エンドポイントの使い方とOAuth2 PKCE認証
- GitHub Actionsでの定期実行とClaude Code SKILLによるAI分類
- **OAuth2トークンリフレッシュの競合問題**とその解決策
- 実際に運用して分かった制約と改善ポイント

:::message
**対象読者**: X API v2の基礎知識がある方、GitHub Actionsを使ったことがある方。OAuth2やClaude Codeは初めてでもOKです。
:::

## 背景：ブックマークが溜まるだけ問題

私のX.comブックマークは週100件を超えるペースで増えていました。AIツールの新機能、気になるOSSの紹介、技術的なTips — 「あとで読もう」と思ってブックマークするものの、振り返る習慣がないまま埋もれていく。

手動で週次レビューを試みたこともありましたが、3週間で挫折しました。100件のブックマークを1つずつ開いて読むのは、単純に退屈すぎます。

**必要だったのは「読む」のではなく「分類して優先度をつける」こと。** それならAIに任せられるのでは、と考えたのがこの仕組みの出発点です。

## 全体アーキテクチャ

```
┌──────────────┐
│  X API v2    │  ← OAuth2 PKCE認証でブックマーク取得
│  Bookmarks   │
└──────┬───────┘
       │ JSON
       ▼
┌──────────────┐
│ GitHub       │  ← cron: 毎日定時実行
│ Actions      │
│              │
│ ┌──────────┐ │
│ │ Claude   │ │  ← SKILL: 分類・要約・ダイジェスト生成
│ │ Code     │ │
│ └──────────┘ │
└──────┬───────┘
       │ Markdown
       ▼
┌──────────────┐
│ Git リポジトリ │  ← ダイジェスト蓄積 + 状態管理
│ (Obsidian等) │
└──────────────┘
```

処理の流れはシンプルです：

1. **取得**: X API v2でブックマークを取得（前回以降の新規のみ）
2. **分類**: Claude Codeが各ブックマークをカテゴリ分類＋1行要約
3. **出力**: Markdownダイジェストを生成してリポジトリにコミット

## X API v2 Bookmarks エンドポイント

### 前提：APIプランについて

X API v2のBookmarksエンドポイントは**無料（Free）プランでは利用できません**。最低でもBasicプラン以上が必要です。

| プラン | 月額（参考） | Bookmarks GET |
|--------|------|:---:|
| Free | $0 | ❌ |
| Basic | $200 | ✅ |
| Pro | $5,000 | ✅ |

:::message alert
Bookmarks APIを使うにはBasicプラン以上への課金が必要です。「とりあえず無料で試す」ということができない点に注意してください。
:::

:::message
**2026年追記**: X APIは従来のサブスクリプション制（Basic/Pro/Enterprise）からPay-Per-Use（従量課金）制へ移行しました。現在はクレジットベースの料金モデル（パイロット期間中・暫定価格）で、月額固定費なし・利用した分だけ課金されます。ブックマーク関連のリソース単価は$0.005/リソース程度です。最新の料金は [X Developer Platform](https://developer.x.com/) の「料金体系」セクションを確認してください。
:::

### エンドポイント仕様

```
GET /2/users/:id/bookmarks
```

| パラメータ | 説明 |
|-----------|------|
| `max_results` | 1-100（デフォルト: 100） |
| `pagination_token` | ページネーション用 |
| `tweet.fields` | 取得するフィールド |
| `expansions` | 展開するオブジェクト |

レート制限は **180リクエスト/15分/ユーザー**。1リクエストで最大100件取得できるので、日次実行なら十分です。

### 必要なOAuthスコープ

```
bookmark.read   # ブックマーク読み取り
tweet.read       # ツイート情報取得
users.read       # ユーザー情報取得
offline.access   # リフレッシュトークン取得（重要）
```

`offline.access` を忘れると、アクセストークンの有効期限（2時間）が切れた後に自動更新できなくなります。

## OAuth2 PKCE 認証の実装

### なぜPKCEが必要か

X API v2のOAuth 2.0は **Authorization Code Flow with PKCE** を採用しています。PKCEは認可コード横取り攻撃（authorization code interception attack）を防ぐための仕組みです。もともとRFC 7636でPublic Client（クライアントサイド）向けに設計されましたが、OAuth 2.1ではConfidential Client（サーバーサイド）を含む全クライアントで推奨されており、X APIもその両方をサポートしています。

### 認証フロー

```
[1] code_verifier（ランダム文字列）を生成
[2] code_verifier → SHA256ハッシュ → Base64URL → code_challenge
[3] 認可URLにcode_challengeを含めてブラウザで開く
[4] ユーザーが「Authorize app」をクリック
[5] リダイレクトURLから認可コード(code)を取得
[6] code + code_verifier でトークンエンドポイントにPOST
[7] access_token + refresh_token を取得
```

### 初回認証の実行

まず、X Developer Portalでアプリを作成し、Callback URLを設定しておきます。

**認可URLの構築：**

```
https://x.com/i/oauth2/authorize
  ?response_type=code
  &client_id=YOUR_CLIENT_ID
  &redirect_uri=http://localhost:3000/callback
  &scope=bookmark.read%20tweet.read%20users.read%20offline.access
  &state=state123
  &code_challenge=YOUR_CODE_CHALLENGE
  &code_challenge_method=S256
```

**トークン取得：**

```bash
curl -s -X POST "https://api.x.com/2/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "CLIENT_ID:CLIENT_SECRET" \
  -d "grant_type=authorization_code\
&code=YOUR_AUTH_CODE\
&redirect_uri=http://localhost:3000/callback\
&code_verifier=YOUR_CODE_VERIFIER"
```

レスポンス：

```json
{
  "token_type": "bearer",
  "expires_in": 7200,
  "access_token": "xxx...",
  "refresh_token": "yyy...",
  "scope": "bookmark.read tweet.read users.read offline.access"
}
```

`refresh_token` は後で使うので安全に保管します。

## GitHub Actionsワークフロー

### ワークフロー構成

```yaml
name: Bookmark Digest
on:
  schedule:
    - cron: '30 22 * * *'  # 毎日 07:30 JST
  workflow_dispatch:         # 手動実行も可能

permissions:
  contents: write

jobs:
  digest:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: pip install requests

      - name: Fetch bookmarks
        env:
          X_CLIENT_ID: ${{ secrets.X_CLIENT_ID }}
          X_CLIENT_SECRET: ${{ secrets.X_CLIENT_SECRET }}
          X_REFRESH_TOKEN: ${{ secrets.X_REFRESH_TOKEN }}
          GH_PAT_FOR_SECRETS: ${{ secrets.GH_PAT_FOR_SECRETS }}
        run: python scripts/bookmark-digest.py

      - name: Run Claude Code for classification
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            03_Input/Bookmarks/data/ にある最新のJSONファイルを読み、
            各ブックマークを分類・要約してダイジェストMarkdownを生成してください。

      - name: Commit results
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add 03_Input/Bookmarks/
          git diff --staged --quiet || git commit -m "bookmark: daily digest $(date +%Y-%m-%d)"
          git push
```

### GitHub Secretsに設定する値

| Secret名 | 内容 |
|-----------|------|
| `X_CLIENT_ID` | X Developer PortalのClient ID |
| `X_CLIENT_SECRET` | X Developer PortalのClient Secret |
| `X_REFRESH_TOKEN` | OAuth2で取得したRefresh Token |
| `GH_PAT_FOR_SECRETS` | Secrets更新用のPAT（後述） |
| `ANTHROPIC_API_KEY` | Claude API Key |

## ブックマーク取得スクリプト

### コア実装

```python
import json
import os
import requests
from datetime import datetime
from pathlib import Path

BASE_URL = "https://api.x.com/2"
DATA_DIR = Path("03_Input/Bookmarks/data")
STATE_FILE = Path("03_Input/Bookmarks/state.json")


def refresh_access_token():
    """refresh_tokenでaccess_tokenを再取得"""
    resp = requests.post(
        f"{BASE_URL.replace('/2', '')}/2/oauth2/token",
        auth=(os.environ["X_CLIENT_ID"], os.environ["X_CLIENT_SECRET"]),
        data={
            "grant_type": "refresh_token",
            "refresh_token": os.environ["X_REFRESH_TOKEN"],
        },
    )
    resp.raise_for_status()
    tokens = resp.json()

    # 新しいrefresh_tokenをGitHub Secretsに保存（後述）
    update_github_secret("X_REFRESH_TOKEN", tokens["refresh_token"])

    return tokens["access_token"]


def fetch_bookmarks(access_token: str, user_id: str) -> list[dict]:
    """ブックマーク一覧を取得"""
    headers = {"Authorization": f"Bearer {access_token}"}
    params = {
        "max_results": 100,
        "tweet.fields": "created_at,public_metrics,entities",
    }

    all_bookmarks = []
    while True:
        resp = requests.get(
            f"{BASE_URL}/users/{user_id}/bookmarks",
            headers=headers,
            params=params,
        )
        resp.raise_for_status()
        data = resp.json()

        if "data" in data:
            all_bookmarks.extend(data["data"])

        # ページネーション
        next_token = data.get("meta", {}).get("next_token")
        if not next_token:
            break
        params["pagination_token"] = next_token

    return all_bookmarks


def filter_new_bookmarks(bookmarks: list[dict]) -> list[dict]:
    """前回取得以降の新規ブックマークのみ抽出"""
    if STATE_FILE.exists():
        state = json.loads(STATE_FILE.read_text())
        last_id = state.get("last_bookmark_id")
    else:
        last_id = None

    if last_id is None:
        return bookmarks

    new_bookmarks = []
    for bm in bookmarks:
        if bm["id"] == last_id:
            break
        new_bookmarks.append(bm)

    return new_bookmarks
```

### 重複排除の仕組み

```python
def save_state(bookmarks: list[dict]):
    """最新のブックマークIDを記録"""
    if bookmarks:
        state = {
            "last_bookmark_id": bookmarks[0]["id"],
            "last_run": datetime.now().isoformat(),
            "count": len(bookmarks),
        }
        STATE_FILE.write_text(json.dumps(state, indent=2))
```

Bookmarks APIは実測上ブックマーク追加日時の降順で返します（公式ドキュメントに明記はありませんが、Developer Communityで多数の開発者が確認しています）。先頭のIDを記録しておけば差分取得が可能です。

## Claude Code SKILLによるAI分類

### 分類プロンプト

Claude Code のSKILLとしてブックマーク分類ロジックを定義します。Claude Codeは取得済みのJSONを読み込み、各ブックマークに対して以下の構造で分類を行います。

```
入力: ツイート本文 + メトリクス（いいね数、RT数、ブックマーク数）

出力:
{
  "category": "AI-Tools | Dev | Productivity | Business | News | Other",
  "content_potential": ["blog", "x-post", "note", "dev-idea", "none"],
  "summary": "1行要約",
  "key_insight": "なぜブックマークしたか推測",
  "priority": "high | medium | low"
}
```

### 分類カテゴリの設計

| カテゴリ | 説明 | 例 |
|---------|------|-----|
| AI-Tools | AIツール・サービス関連 | Claude Code新機能、ChatGPT Tips |
| Dev | 開発技術・ライブラリ | Rust入門、新フレームワーク |
| Productivity | 生産性・ワークフロー | Obsidian術、時間管理 |
| Business | ビジネス・マーケティング | SEO、収益化戦略 |
| News | ニュース・速報 | リリース情報、業界動向 |
| Other | 上記以外 | — |

### ダイジェスト出力フォーマット

生成されるMarkdownダイジェストの例：

```markdown
# Bookmark Digest — 2026-03-20

新規ブックマーク: 12件

## 🤖 AI-Tools (5件)
1. **Claude Code SKILLsの自作方法** ❤️500 🔖154
   → 開発ガイド記事のネタ候補
2. **Gemini 2.5 Pro リリース速報** ❤️1.2k 🔖340
   → ニュースまとめ候補

## 💻 Dev (3件)
1. **Bun v1.3のNode.js互換性が大幅改善** ❤️230 🔖89
   → 比較検証記事のネタ候補

## 🔥 注目ピック
- Claude Code SKILLs → ブログ記事として深掘り推奨
- Bun v1.3 → 実際に移行検証して記事化が有効

## 📊 統計
- 合計: 12件
- カテゴリ別: AI-Tools(5), Dev(3), Productivity(2), News(2)
- コンテンツ候補: blog(3), dev-idea(1)
```

## OAuth2トークンリフレッシュの競合問題

ここが一番ハマったポイントです。

### 問題

X APIのOAuth2リフレッシュトークンは**使い捨て（ローテーション方式）**です。リフレッシュすると新しいトークンが発行され、古いトークンは無効になります。

GitHub Actionsでは複数のジョブが並列実行される場合があります。以下のシナリオで問題が発生しました：

```
Job A: refresh_token_v1 でリフレッシュ → refresh_token_v2 を取得
Job B: refresh_token_v1 でリフレッシュ → 失敗（v1は既に無効）
```

### 解決策：state fileによるロック

```python
import time

LOCK_FILE = Path("03_Input/Bookmarks/.token-lock")
LOCK_TIMEOUT = 300  # 5分


def acquire_lock() -> bool:
    """トークンリフレッシュのロックを取得"""
    if LOCK_FILE.exists():
        lock_data = json.loads(LOCK_FILE.read_text())
        locked_at = datetime.fromisoformat(lock_data["locked_at"])
        elapsed = (datetime.now() - locked_at).total_seconds()
        if elapsed < LOCK_TIMEOUT:
            return False  # ロック中
        # タイムアウト → 古いロックを無視

    LOCK_FILE.write_text(json.dumps({
        "locked_at": datetime.now().isoformat(),
        "job_id": os.environ.get("GITHUB_RUN_ID", "unknown"),
    }))
    return True


def release_lock():
    """ロックを解放"""
    if LOCK_FILE.exists():
        LOCK_FILE.unlink()
```

:::message
この方法はGitリポジトリ内のファイルをロックとして使うため、完全な排他制御ではありません。しかし、日次1回のcron実行であれば実用上は問題ありません。高頻度の並列実行が必要な場合は、外部のロック機構（Redis等）を検討してください。
:::

### GitHub Secretsの自動更新

リフレッシュで取得した新しいトークンをGitHub Secretsに書き戻す必要があります。これには**Personal Access Token（PAT）** が必要です。

```python
import base64
from nacl import encoding, public


def update_github_secret(secret_name: str, secret_value: str):
    """GitHub Secretsを更新"""
    pat = os.environ["GH_PAT_FOR_SECRETS"]
    repo = os.environ.get("GITHUB_REPOSITORY", "owner/repo")
    headers = {
        "Authorization": f"Bearer {pat}",
        "Accept": "application/vnd.github+json",
    }

    # リポジトリの公開鍵を取得
    resp = requests.get(
        f"https://api.github.com/repos/{repo}/actions/secrets/public-key",
        headers=headers,
    )
    resp.raise_for_status()
    key_data = resp.json()

    # 秘密情報を暗号化
    encrypted = encrypt_secret(key_data["key"], secret_value)

    # Secretを更新
    resp = requests.put(
        f"https://api.github.com/repos/{repo}/actions/secrets/{secret_name}",
        headers=headers,
        json={
            "encrypted_value": encrypted,
            "key_id": key_data["key_id"],
        },
    )
    resp.raise_for_status()


def encrypt_secret(public_key: str, secret_value: str) -> str:
    """libsodiumでGitHub Secrets用に暗号化"""
    pk = public.PublicKey(
        public_key.encode("utf-8"), encoding.Base64Encoder
    )
    sealed = public.SealedBox(pk).encrypt(secret_value.encode("utf-8"))
    return base64.b64encode(sealed).decode("utf-8")
```

:::message alert
PATの権限は**最小限**にしてください。必要なのは対象リポジトリの `Secrets: Read and Write` のみです。他の権限は不要です。
:::

## 運用してわかったこと

### うまくいったこと

- **「後で読む」が「週次レビュー素材」に変わった**: ダイジェストを週末にざっと見るだけで、重要なブックマークを見逃さなくなった
- **4回の反復で分類精度が安定**: 初回はカテゴリの粒度が荒かったが、SKILLのプロンプトを調整して改善
- **コンテンツネタの発見効率が上がった**: 「ブログネタ候補」フラグが付いたブックマークから実際に2本記事化できた

### 制約と注意点

| 制約 | 影響 | 対処 |
|------|------|------|
| Bookmarks APIは有料プラン必須 | Pay-Per-Use制（$0.005/リソース〜） | 従量課金なので少量利用なら低コスト |
| 最大800件まで取得可能 | 大量ブックマーク派は取りこぼす | 取得頻度を上げる（週2-3回） |
| リフレッシュトークンの有効期限 | 長期間未使用だと失効 | 最低週1回は実行を維持 |
| Claude API コスト | ダイジェスト1回あたり約$0.02-0.05 | 月$1-2程度で実用的 |

### 改善したいこと

1. **Discord連携**: ダイジェストをDiscordチャネルにも投稿して、モバイルから確認できるようにしたい
2. **インタラクティブな指示**: 「このブックマーク、ブログリサーチに追加して」とDiscord上で指示できるようにしたい
3. **複数アカウント対応**: 別アカウントのブックマークも統合管理したい

## まとめ

- X.comのブックマークは **X API v2 + GitHub Actions + Claude Code** で自動キュレーションできる
- OAuth2 PKCEの認証フローは初回のみ手動、以降はリフレッシュトークンで自動更新
- リフレッシュトークンのローテーション方式には注意が必要 — 並列実行時の競合対策としてロック機構を実装
- GitHub Secretsの自動更新にはPATが必要（最小権限で設定すること）
- Claude Code SKILLで分類ロジックを定義すれば、運用中のチューニングも容易

「ブックマークが溜まるだけ」から「自動で整理されて週次レビューの素材になる」への転換は、体感以上に情報活用の質を変えてくれます。

## 参考リンク

- [X API v2 Bookmarks - 公式ドキュメント](https://developer.x.com/en/docs/x-api/tweets/bookmarks/introduction)
- [OAuth 2.0 Authorization Code Flow with PKCE - X Docs](https://docs.x.com/fundamentals/authentication/oauth-2-0/authorization-code)
- [Claude Code GitHub Actions - 公式ドキュメント](https://code.claude.com/docs/ja/github-actions)
- [anthropics/claude-code-action - GitHub](https://github.com/anthropics/claude-code-action)
- [GitHub Actions シークレット管理 - GitHub Docs](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions)

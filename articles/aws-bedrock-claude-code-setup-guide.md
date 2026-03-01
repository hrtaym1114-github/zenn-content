---
title: "【2026年最新】AWS Bedrock × Claude Codeセットアップ完全ガイド — 認証・料金・プロンプトキャッシュまで"
emoji: "☁️"
type: "tech"
topics: ["ClaudeCode", "AmazonBedrock", "AWS", "AI", "エンタープライズ"]
published: true
---

## この記事で分かること

Claude Codeを企業で使いたいけれど、Anthropic APIキーを全員に配布するのはセキュリティ的に不安——そんなときの選択肢が **Amazon Bedrock経由でのClaude Code利用**です。

AWS IAMの認証基盤に乗せることで、既存のセキュリティポリシー・コスト管理・監査ログがそのまま使えます。本記事では、2026年2月時点の最新情報をもとに以下を解説します。

- Bedrock経由でClaude Codeを動かすまでの **ステップバイステップ手順**
- IAMポリシー・認証方式の選び方（個人〜エンタープライズ）
- モデルバージョンの **ピン留め**（本番運用で必須）
- **プロンプトキャッシュ** によるコスト90%・レイテンシ85%削減
- 料金体系の全容と **Anthropic API直接利用との比較**
- Guardrails（コンテンツフィルタリング）の設定
- よくあるトラブルと解決法

:::message
**対象読者**: Claude Codeを業務利用したいエンジニア・インフラ担当者。AWSアカウントの基本操作（IAM、CLI）ができる前提で進めます。
:::

## なぜBedrock経由で使うのか？

Claude Codeには2つの利用形態があります。

| 項目 | Anthropic API直接 | Amazon Bedrock経由 |
|------|-------------------|-------------------|
| 認証 | APIキー | AWS IAM（SSO/OIDC対応） |
| コスト管理 | Anthropicダッシュボード | AWS Cost Explorer + CloudWatch |
| セキュリティ | APIキー管理が必要 | VPCエンドポイント・KMS暗号化 |
| 監査ログ | なし | CloudTrail自動記録 |
| コンテンツフィルタ | なし | Bedrock Guardrails |
| トークン単価 | 同一 | 同一（リージョナルは+10%） |
| 新モデルの利用開始 | 即日 | ほぼ同日（※） |
| セットアップ | 5分 | 30分〜1時間 |

※ 2026年2月時点、Claude Opus 4.6（2/5）・Sonnet 4.6（2/17）はいずれもAnthropicの発表と同日にBedrockで利用可能でした。かつては数週間の遅延がありましたが、最近のモデルではほぼ解消されています。

**結論**: 個人利用ならAnthropic API直接が手軽。**チーム・企業利用**ではBedrock経由のメリットが大きい。

## 前提条件

- AWSアカウント（Bedrockが有効化されたリージョン）
- AWS CLI v2 インストール済み
- Node.js 18以上
- Claude Codeインストール済み（`npm install -g @anthropic-ai/claude-code`）

## Step 1: Bedrockでモデルアクセスを有効化する

2026年現在、Bedrockの多くのモデルは自動的にアクセス可能になりましたが、**Anthropicモデルは初回のみユースケース申請が必要**です。

1. [Amazon Bedrockコンソール](https://console.aws.amazon.com/bedrock/)にアクセス
2. 左メニューから **Chat/Text playground** を選択
3. Anthropicモデル（例: Claude Sonnet 4.6）を選択
4. ユースケースフォームが表示されるので記入・送信

:::message
これは **1アカウントにつき1回** の作業です。送信後すぐにアクセスが有効になります。
:::

### モデルの利用可能状況を確認する

```bash
aws bedrock list-inference-profiles --region us-east-1
```

Claudeモデルが一覧に含まれていればOKです。

## Step 2: IAMポリシーを作成する

Claude Codeに必要な最小権限のIAMポリシーです。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowModelAndInferenceProfileAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ListInferenceProfiles"
      ],
      "Resource": [
        "arn:aws:bedrock:*:*:inference-profile/*",
        "arn:aws:bedrock:*:*:application-inference-profile/*",
        "arn:aws:bedrock:*:*:foundation-model/*"
      ]
    },
    {
      "Sid": "AllowMarketplaceSubscription",
      "Effect": "Allow",
      "Action": [
        "aws-marketplace:ViewSubscriptions",
        "aws-marketplace:Subscribe"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:CalledViaLast": "bedrock.amazonaws.com"
        }
      }
    }
  ]
}
```

:::message alert
**本番運用のヒント**: `Resource`を特定のInference Profile ARNに絞ると、より安全です。たとえば`arn:aws:bedrock:us-east-1:123456789012:inference-profile/us.anthropic.claude-sonnet-4-6`のように指定できます。
:::

このポリシーをIAMユーザーまたはIAMロールにアタッチしてください。

## Step 3: AWS認証情報を設定する

Claude CodeはAWS SDKの標準的な認証チェーンを使います。環境に応じて5つの方法から選べます。

### 方法A: AWS CLIプロファイル（個人向け・最も簡単）

```bash
aws configure
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: ****
# Default region: us-east-1
```

### 方法B: 環境変数（CI/CD・コンテナ向け）

```bash
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export AWS_SESSION_TOKEN=your-session-token  # STSの場合
```

### 方法C: AWS SSO（チーム向け・推奨）

```bash
# SSOログイン
aws sso login --profile=my-team-profile

# プロファイルを環境変数に設定
export AWS_PROFILE=my-team-profile
```

### 方法D: aws loginコマンド（AWSコンソール認証）

```bash
aws login
# ブラウザが開き、AWSコンソールの認証情報でログイン
```

### 方法E: Bedrock APIキー（2025年7月リリース・最もシンプル）

```bash
export AWS_BEARER_TOKEN_BEDROCK=your-bedrock-api-key
```

Bedrock APIキーはフルのAWS認証情報なしで利用できる簡易認証です。

:::message
**どれを選ぶ？**
- 個人開発 → **方法A**（aws configure）
- チーム利用 → **方法C**（SSO）が管理しやすい
- エンタープライズ → **OIDC連携**（後述の高度な設定を参照）
- 素早く試したい → **方法E**（Bedrock APIキー）
:::

## Step 4: Claude CodeをBedrock接続に設定する

ここが核心です。2つの環境変数を設定するだけで、Claude CodeがBedrock経由に切り替わります。

```bash
# Bedrock統合を有効化
export CLAUDE_CODE_USE_BEDROCK=1

# リージョン指定（必須）
export AWS_REGION=us-east-1
```

:::message alert
`AWS_REGION`は**必須**です。`.aws/config`のリージョン設定は読み込まれません。明示的に環境変数で指定してください。
:::

### 動作確認

```bash
claude
# Claude Codeが起動し、Bedrock経由でモデルにアクセスできれば成功
```

Bedrock接続時は `/login` と `/logout` コマンドは無効化されます（認証はAWS側で管理）。

## Step 5: モデルバージョンをピン留めする（本番必須）

:::message alert
**これを忘れるとチーム全体が止まります。** Anthropicが新モデルをリリースした際、ピン留めしていないとClaude Codeがデフォルトモデルを自動更新し、Bedrockアカウントでの利用準備が整っていないモデルを呼び出してエラーになる可能性があります。
:::

```bash
# モデルバージョンを固定
export ANTHROPIC_DEFAULT_OPUS_MODEL='us.anthropic.claude-opus-4-6-v1'
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'
```

`us.`プレフィックスは**Cross-Region Inference Profile**を意味し、USリージョン全体で負荷分散されます。他のリージョンプレフィックスやApplication Inference Profileを使う場合は適宜変更してください。

### ピン留めしない場合のデフォルト

| モデルタイプ | デフォルト値 |
|-------------|-------------|
| Primary model | `global.anthropic.claude-sonnet-4-6` |
| Small/fast model | `us.anthropic.claude-haiku-4-5-20251001-v1:0` |

### カスタムモデル設定

```bash
# Inference Profile IDで指定
export ANTHROPIC_MODEL='global.anthropic.claude-sonnet-4-6'
export ANTHROPIC_SMALL_FAST_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'

# Application Inference Profile ARNで指定（高度）
export ANTHROPIC_MODEL='arn:aws:bedrock:us-east-2:123456789012:application-inference-profile/your-profile-id'

# Haikuのリージョンを別に指定（任意）
export ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION=us-west-2
```

## まとめ: 最小構成の.bashrc/.zshrc

ここまでの設定をまとめると、最小構成は以下の4行です。

```bash
# ~/.bashrc or ~/.zshrc に追加
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'
```

これでClaude CodeはBedrock経由で動作します。以降のセクションでは、さらに踏み込んだ設定を解説します。

## 料金体系を理解する

### Bedrockでのトークン単価（2026年2月時点）

Bedrock経由の料金はAnthropic API直接と**同一**です。

| モデル | 入力トークン | 出力トークン |
|--------|-------------|-------------|
| Claude Opus 4.6 | $5 / MTok | $25 / MTok |
| Claude Sonnet 4.6 | $3 / MTok | $15 / MTok |
| Claude Haiku 4.5 | $1 / MTok | $5 / MTok |

（MTok = 100万トークン）

:::message
**リージョナルエンドポイント（特定リージョン固定）** を使う場合、グローバルエンドポイントに対して **+10%** の追加料金がかかります。Claude Sonnet 4.5/Haiku 4.5以降のモデルが対象です。
:::

### プロンプトキャッシュの料金

| 操作 | 倍率 | Sonnet 4.6の実額 |
|------|------|-----------------|
| 通常入力 | 1.0x | $3 / MTok |
| 5分キャッシュ書込み | 1.25x | $3.75 / MTok |
| 1時間キャッシュ書込み | 2.0x | $6 / MTok |
| キャッシュ読込み | 0.1x | $0.30 / MTok |

**キャッシュヒット時は通常入力の10%**——これが後述する大幅なコスト削減の源泉です。

### Bedrock利用時の追加コスト

トークン単価は同一ですが、AWS側で以下のコストが発生する可能性があります。

- データ転送料金（AWSサービス間）
- S3ストレージ（ログ保存時）
- CloudWatch（モニタリング有効化時）
- VPCエンドポイント（プライベートアクセス時）

大半のケースではトークンコストが支配的なので、これらは無視できるレベルです。

## プロンプトキャッシュで最大90%コスト削減

Claude Codeは大規模なコードベースを繰り返し読み込みます。プロンプトキャッシュを使うと、一度読み込んだコンテキストを再利用でき、**コスト最大90%、レイテンシ最大85%削減**できます。

### Claude Codeでのキャッシュの仕組み

Claude Codeがプロンプトキャッシュを利用する際の流れ:

1. Claude Codeがコードベースを初回読み込み → キャッシュポイントが自動的に設定される
2. 次のリクエストで同じコンテキストがある場合 → キャッシュヒットで高速・低コスト処理
3. キャッシュは5分間（デフォルト）または1時間（設定変更時）有効

### Bedrockでの対応状況

- **5分TTL**: デフォルトで有効（追加設定不要）
- **1時間TTL**: 2026年1月から利用可能。Claude Sonnet 4.5、Haiku 4.5、Opus 4.5で対応

:::message
プロンプトキャッシュはすべてのリージョンで利用できるわけではありません。利用不可の場合は以下で無効化できます。

```bash
export DISABLE_PROMPT_CACHING=1
```
:::

### 試算例: 1日50回のコーディングセッション

| 項目 | キャッシュなし | キャッシュあり |
|------|-------------|-------------|
| 1リクエストあたり入力 | 50,000トークン | 5,000（新規）+ 45,000（キャッシュヒット） |
| 日次入力コスト（Sonnet 4.6） | $7.50 | $0.75 + $0.0135 = **$0.76** |
| 月間コスト（20営業日） | $150 | **$15.20** |
| 削減率 | — | **約90%** |

## 認証の高度な設定

### 自動クレデンシャルリフレッシュ（SSO向け）

AWS SSOを使っている場合、セッションの有効期限切れで作業が中断されることがあります。Claude Codeの設定ファイルに以下を追記すると、自動でリフレッシュされます。

```json
{
  "awsAuthRefresh": "aws sso login --profile myprofile",
  "env": {
    "AWS_PROFILE": "myprofile"
  }
}
```

Claude Codeがクレデンシャルの期限切れを検知すると、`awsAuthRefresh`コマンドを自動実行します。ブラウザベースのSSOフロー（URLが表示されブラウザで認証完了）に対応しています。

### カスタムクレデンシャルエクスポート

`.aws`ディレクトリを変更できない環境では、`awsCredentialExport`を使って直接クレデンシャルを返すことができます。

```json
{
  "awsCredentialExport": "your-custom-credential-command"
}
```

コマンドは以下のJSON形式で出力する必要があります:

```json
{
  "Credentials": {
    "AccessKeyId": "ASIA...",
    "SecretAccessKey": "...",
    "SessionToken": "..."
  }
}
```

### OIDC連携（エンタープライズ向け）

大規模組織ではOkta、Azure AD、Auth0、AWS Cognito User Poolsとの直接OIDC連携が推奨されます。開発者は企業認証情報でBedrock経由のClaude Codeを使えるようになり、個別のAWSアクセスキー配布が不要になります。

詳細はAWSの公式ソリューション [Guidance for Claude Code with Amazon Bedrock](https://aws.amazon.com/solutions/guidance/claude-code-with-amazon-bedrock/) を参照してください。

## Guardrails: コンテンツフィルタリング

[Amazon Bedrock Guardrails](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)を使えば、Claude Codeの出力にコンテンツフィルタリングを適用できます。

### 設定手順

1. Bedrockコンソールで **Guardrail** を作成
2. バージョンをパブリッシュ
3. Claude Codeの設定ファイルにヘッダーを追加:

```json
{
  "env": {
    "ANTHROPIC_CUSTOM_HEADERS": "X-Amzn-Bedrock-GuardrailIdentifier: your-guardrail-id\nX-Amzn-Bedrock-GuardrailVersion: 1"
  }
}
```

:::message alert
**Cross-Region Inference Profileを使っている場合**は、Guardrailにも Cross-Region inferenceを有効化する必要があります。
:::

## チーム展開のベストプラクティス

### 1. 専用AWSアカウントを作成する

Claude Code用の専用AWSアカウントを用意すると、コスト追跡・アクセス制御がシンプルになります。AWS Organizationsで請求を統合しつつ、IAMポリシーはアカウントレベルで分離できます。

### 2. 設定ファイルで環境変数を管理する

環境変数を`.bashrc`に書く代わりに、Claude Codeの設定ファイル（`~/.claude/settings.json`）を使うと、**AWS_PROFILEなどの機密情報が他のプロセスに漏れない**という利点があります。

```json
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1",
    "AWS_PROFILE": "claude-code-team",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "us.anthropic.claude-sonnet-4-6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "us.anthropic.claude-haiku-4-5-20251001-v1:0"
  }
}
```

### 3. CloudWatchでコスト監視

Bedrock Model Invocation Loggingを有効化して、チームメンバーごと・プロジェクトごとのトークン消費量を可視化しましょう。異常な利用パターンの早期発見にも役立ちます。

## トラブルシューティング

### "on-demand throughput isn't supported" エラー

モデルIDではなく**Inference Profile ID**を使う必要があります。

```bash
# NG: モデルIDを直接指定
export ANTHROPIC_MODEL='anthropic.claude-sonnet-4-6'

# OK: Inference Profile IDを使用
export ANTHROPIC_MODEL='us.anthropic.claude-sonnet-4-6'
```

### リージョンでモデルが見つからない

```bash
# 利用可能なInference Profileを確認
aws bedrock list-inference-profiles --region us-east-1

# リージョンを変更
export AWS_REGION=us-east-1
```

Cross-Region Inference Profile（`us.`プレフィックス）を使えば、リージョン固有の問題を回避できます。

### クレデンシャルの有効期限切れ

SSOやSTSの一時クレデンシャルが期限切れになった場合:

```bash
# SSO再認証
aws sso login --profile your-profile

# または自動リフレッシュを設定（前述の awsAuthRefresh）
```

### Bedrockへの接続テスト

```bash
# CLIでBedrock APIを直接呼び出してテスト
aws bedrock-runtime invoke-model \
  --model-id us.anthropic.claude-haiku-4-5-20251001-v1:0 \
  --region us-east-1 \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}' \
  --content-type application/json \
  output.json
```

このコマンドが成功すれば、IAM権限とモデルアクセスは問題ありません。

## Anthropic API直接 vs Bedrock: どちらを選ぶべきか

| 判断基準 | Anthropic API直接 | Amazon Bedrock |
|---------|-------------------|----------------|
| 利用者が1-3人 | **推奨** | オーバーキル |
| 既存のAWSインフラがある | 可 | **推奨** |
| SOC2/ISO27001準拠が必要 | 個別対応 | **AWS準拠で対応** |
| VPC内でのアクセスが必要 | 不可 | **VPCエンドポイント対応** |
| 最新モデルをすぐ使いたい | 即日利用 | **ほぼ同日**（※） |
| コスト監査が必要 | 限定的 | **CloudTrail/CloudWatch** |
| セットアップの手軽さ | **5分** | 30分〜1時間 |

※ Opus 4.6は2026年2月5日、Sonnet 4.6は2月17日にそれぞれ発表と同日にBedrock対応。以前のような数週間の遅延はなくなっています。

## まとめ

- Claude CodeのBedrock接続は **環境変数2つ**（`CLAUDE_CODE_USE_BEDROCK=1` + `AWS_REGION`）で有効化
- **モデルバージョンのピン留め** はチーム利用で必須。忘れると新モデルリリース時に全員がエラーに
- トークン単価はAnthopic API直接と**同一**。プロンプトキャッシュで**最大90%削減**可能
- 認証はSSO/OIDC/Bedrock APIキーなど柔軟。エンタープライズにはOIDC連携を推奨
- Guardrailsでコンテンツフィルタリング、CloudWatchでコスト監視を追加可能

## 参考リンク

- [Claude Code on Amazon Bedrock - 公式ドキュメント](https://code.claude.com/docs/en/amazon-bedrock)
- [Guidance for Claude Code with Amazon Bedrock - AWSソリューション](https://aws.amazon.com/solutions/guidance/claude-code-with-amazon-bedrock/)
- [Claude Code deployment patterns and best practices with Amazon Bedrock](https://aws.amazon.com/blogs/machine-learning/claude-code-deployment-patterns-and-best-practices-with-amazon-bedrock/)
- [Supercharge your development with Claude Code and Amazon Bedrock prompt caching](https://aws.amazon.com/blogs/machine-learning/supercharge-your-development-with-claude-code-and-amazon-bedrock-prompt-caching/)
- [Amazon Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [Claude API Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Prompt caching for faster model inference - Amazon Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-caching.html)
- [Amazon Bedrock 1-hour prompt caching (2026年1月)](https://aws.amazon.com/about-aws/whats-new/2026/01/amazon-bedrock-one-hour-duration-prompt-caching/)

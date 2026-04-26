---
title: "【2026年最新】Alibaba OpenSandbox完全ガイド — AIエージェントのコード実行を安全に隔離する"
emoji: "🏖️"
type: "tech"
topics: ["OpenSandbox", "Docker", "AIAgent", "Python", "Kubernetes"]
published: false
---

## この記事で分かること

AIエージェント（Claude Code、Codex、Gemini CLI等）が生成するコードを、安全に隔離実行できる環境が必要になってきました。Alibaba が 2026年3月にオープンソース公開した **OpenSandbox** は、Docker/Kubernetes ベースの汎用サンドボックスプラットフォームです。

この記事では、OpenSandbox の**アーキテクチャ設計**から**実際のセットアップ手順**、**Python SDK を使った実装例**、**競合サービスとの比較**まで、実務で使えるレベルで解説します。

:::message
**対象読者**: AIエージェントの開発・運用に携わるエンジニア（中級〜上級）。Docker の基本操作ができることを前提とします。
:::

## なぜ AIエージェントにサンドボックスが必要なのか

LLM が生成するコードには、意図しない副作用のリスクが常につきまといます。

- **ファイルシステムの破壊**: `rm -rf /` のような危険なコマンドの実行
- **情報漏洩**: 環境変数やシークレットの外部送信
- **無限ループ**: リソースを食い潰す暴走コード
- **外部通信**: 意図しないAPIコールやデータ送信

これまでは E2B（Firecracker microVM）や Modal（gVisor）といった選択肢がありましたが、いずれもクラウドSaaS前提であったり、セルフホストが困難という制約がありました。

OpenSandbox は **Apache-2.0 ライセンスで完全にセルフホスト可能**、かつ **Kubernetes ネイティブ対応** という点で、オンプレミス環境やプライベートクラウドでの運用を想定した設計になっています。

## OpenSandbox のアーキテクチャ

### Control Plane / Data Plane 分離

OpenSandbox の最大の設計特徴は、**ライフサイクル管理（Control Plane）** と **実行処理（Data Plane）** を明確に分離していることです。

```
┌─────────────────────────────────────┐
│          Client SDKs                │
│  (Python / Java / JS / C# / ...)   │
└──────┬──────────────┬───────────────┘
       │              │
       ▼              ▼
┌──────────┐   ┌──────────────┐
│ Control  │   │  Data Plane  │
│  Plane   │   │   (execd)    │
│ (Server) │   │  Port 44772  │
│ FastAPI  │   │  Go HTTP     │
└──────────┘   └──────────────┘
       │              │
       ▼              ▼
┌─────────────────────────────────────┐
│     Runtime (Docker / Kubernetes)   │
└─────────────────────────────────────┘
```

**Control Plane**（FastAPI / Python）:
- サンドボックスの作成・一時停止・再開・削除
- TTL（有効期限）管理
- REST API を提供

**Data Plane**（`execd` / Go）:
- 各サンドボックス内にインジェクトされるデーモン
- コマンド実行・ファイル操作・コードインタープリタを処理
- SDK から直接通信し、Control Plane を経由しない → **低レイテンシ**

この分離により、サンドボックスの管理APIと実際のコード実行が独立してスケールします。

### サンドボックスのライフサイクル

```
Pending → Running → [Paused ↔ Running] → Stopping → Terminated
```

TTL ベースの自動期限管理があり、`renew-expiration` API で延長可能です。一時停止（Pause）と再開（Resume）にも対応しているため、リソースを節約しながら長時間のタスクを管理できます。

### 主要コンポーネント

| コンポーネント | 言語 | 役割 |
|:-------------|:-----|:-----|
| `server/` | Python (FastAPI) | ライフサイクル管理サーバー |
| `components/execd/` | Go | 実行デーモン（コマンド/ファイル/コード） |
| `components/ingress/` | Go | トラフィックプロキシゲートウェイ |
| `components/egress/` | Go | ネットワーク Egress 制御 |
| `sdks/` | 多言語 | クライアントライブラリ群 |
| `sandboxes/` | 各種 | ランタイムイメージ |

## セットアップ

### 前提条件

- Docker Engine がインストール済みであること
- Python 3.10+ と `uv`（推奨）または `pip`

### 方法1: pip でサーバーをインストール（推奨）

```bash
# サーバーをインストール
uv pip install opensandbox-server

# 設定ファイルを初期化（Docker用テンプレート）
opensandbox-server init-config ~/.sandbox.toml --example docker

# サーバー起動
opensandbox-server
```

### 方法2: ソースからビルド

```bash
git clone https://github.com/alibaba/OpenSandbox.git
cd OpenSandbox/server
uv sync
cp example.config.toml ~/.sandbox.toml
uv run python -m src.main
```

### Docker イメージのプル

コードインタープリタイメージを事前に取得します。

```bash
# Docker Hub から取得
docker pull opensandbox/code-interpreter:v1.0.1

# Alibaba Cloud レジストリ（中国からは高速）
docker pull sandbox-registry.cn-zhangjiakou.cr.aliyuncs.com/opensandbox/code-interpreter:v1.0.1
```

### Python SDK のインストール

```bash
# サンドボックス SDK
uv pip install opensandbox

# コードインタープリタ（追加パッケージ）
uv pip install opensandbox-code-interpreter
```

### 設定ファイル（~/.sandbox.toml）の主要項目

```toml
[server]
host = "0.0.0.0"
port = 8080
log_level = "info"
api_key = ""  # 任意: API認証キー

[runtime]
type = "docker"  # "docker" または "kubernetes"
execd_image = "opensandbox/execd:latest"

[docker]
network_mode = "bridge"  # "host" or "bridge"
drop_capabilities = true
pids_limit = 256

[egress]
image = "opensandbox/egress:latest"  # Egress制御用イメージ

[storage]
allowed_host_paths = ["/data/opensandbox"]  # ボリュームマウント許可パス
```

:::message
`network_mode = "bridge"` に設定しないと、Egress ネットワーク制御が使えません。単一サンドボックスでパフォーマンス重視の場合は `"host"` も選択可能です。
:::

## 実装例: Python SDK

### 基本的な使い方

```python
import asyncio
from datetime import timedelta
from opensandbox import Sandbox
from opensandbox.models import WriteEntry

async def main() -> None:
    # サンドボックスを作成（10分のTTL）
    sandbox = await Sandbox.create(
        "opensandbox/code-interpreter:v1.0.1",
        entrypoint=["/opt/opensandbox/code-interpreter.sh"],
        timeout=timedelta(minutes=10),
    )

    async with sandbox:
        # シェルコマンドを実行
        execution = await sandbox.commands.run("echo 'Hello OpenSandbox!'")
        print(execution.logs.stdout[0].text)
        # => Hello OpenSandbox!

        # ファイルを書き込み
        await sandbox.files.write_files([
            WriteEntry(path="/tmp/hello.txt", data="Hello World", mode=644)
        ])

        # ファイルを読み取り
        content = await sandbox.files.read_file("/tmp/hello.txt")
        print(f"Content: {content}")
        # => Content: Hello World

    # サンドボックスを破棄
    await sandbox.kill()

if __name__ == "__main__":
    asyncio.run(main())
```

### コードインタープリタの利用

`opensandbox-code-interpreter` パッケージを使うと、Jupyter カーネル経由でコードを実行できます。

```python
import asyncio
from datetime import timedelta
from code_interpreter import CodeInterpreter, SupportedLanguage
from opensandbox import Sandbox

async def main() -> None:
    sandbox = await Sandbox.create(
        "opensandbox/code-interpreter:v1.0.1",
        entrypoint=["/opt/opensandbox/code-interpreter.sh"],
        env={"PYTHON_VERSION": "3.11"},
        timeout=timedelta(minutes=10),
    )

    async with sandbox:
        interpreter = await CodeInterpreter.create(sandbox)

        # Python コードを実行
        result = await interpreter.codes.run(
            """
import numpy as np
arr = np.random.randn(1000)
print(f"Mean: {arr.mean():.4f}")
print(f"Std:  {arr.std():.4f}")
""",
            language=SupportedLanguage.PYTHON,
        )

        for line in result.logs.stdout:
            print(line.text)

    await sandbox.kill()

asyncio.run(main())
```

対応言語は **Python, Java, Go, JavaScript, TypeScript, Bash** の6言語です。

### ネットワークポリシーの適用

サンドボックスごとに外向き通信を制御できます。

```python
from opensandbox.models import NetworkPolicy

sandbox = await Sandbox.create(
    "opensandbox/code-interpreter:v1.0.1",
    entrypoint=["/opt/opensandbox/code-interpreter.sh"],
    network_policy=NetworkPolicy(
        defaultAction="deny",  # デフォルト: 全外部通信を拒否
        egress=[
            {"action": "allow", "target": "pypi.org"},
            {"action": "allow", "target": "*.python.org"},
        ]
    ),
    timeout=timedelta(minutes=10),
)
```

この設定では、サンドボックス内のコードは `pypi.org` と `*.python.org` にのみ接続可能です。その他の外部通信はすべてブロックされます。

内部実装は DNS プロキシ + nftables による動的 IP フィルタリングで、FQDN レベルのルール定義が可能です。

### ボリュームマウント（ホストディレクトリ共有）

```python
from opensandbox.models import Volume, HostVolume

sandbox = await Sandbox.create(
    "opensandbox/code-interpreter:v1.0.1",
    volumes=[
        Volume(
            name="data",
            host=HostVolume(path="/data/opensandbox"),
            mount_path="/workspace",
            read_only=False,
        )
    ],
)
```

:::message alert
ボリュームマウントを使用するには、設定ファイルの `storage.allowed_host_paths` にホワイトリストの登録が必要です。任意のパスをマウントできないよう制限されています。
:::

## REST API リファレンス

SDK を使わずに直接 API を叩くことも可能です。

### Control Plane API（ライフサイクル管理）

| エンドポイント | メソッド | 説明 |
|:-------------|:--------|:-----|
| `/v1/sandboxes` | POST | サンドボックス作成 |
| `/v1/sandboxes/{id}` | GET | ステータス取得 |
| `/v1/sandboxes/{id}` | DELETE | サンドボックス削除 |
| `/v1/sandboxes/{id}/pause` | POST | 一時停止 |
| `/v1/sandboxes/{id}/resume` | POST | 再開 |
| `/v1/sandboxes/{id}/renew-expiration` | POST | TTL延長 |

### Data Plane API（実行操作）

| エンドポイント | メソッド | 説明 |
|:-------------|:--------|:-----|
| `/command` | POST | シェルコマンド実行 |
| `/code` | POST | Jupyter カーネルでコード実行 |
| `/files/upload` | POST | ファイル書き込み |
| `/files/read` | GET | ファイル読み取り |
| `/directories/list` | GET | ディレクトリ一覧 |
| `/metrics` | GET | リソース使用量ストリーミング |

## ユースケース

### 1. Coding Agent のサンドボックス実行

Claude Code、Codex、Gemini CLI などのコーディングエージェントをサンドボックス内で動かすことで、ファイルシステムやネットワークへの影響を隔離できます。

```bash
# Claude Code をサンドボックス内で実行する公式サンプル
export SANDBOX_DOMAIN=localhost:8080
export ANTHROPIC_AUTH_TOKEN=sk-ant-xxxxx
export SANDBOX_IMAGE=opensandbox/code-interpreter:v1.0.1

uv run python examples/claude-code/main.py
```

このスクリプトは内部で `npm i -g @anthropic-ai/claude-code@latest` を実行し、サンドボックス内に Claude CLI をインストールした後、タスクを実行します。

### 2. GUI Agent（ヘッドレスブラウザ）

ヘッドレス Chrome + VNC + DevTools の構成で、ブラウザ自動化エージェントを安全に実行できます。

### 3. Agent 評価（ベンチマーク）

SWE-bench や WebArena などのベンチマークを標準化された環境で実行し、エージェントの性能を公平に評価できます。

### 4. 強化学習のトレーニング

`examples/dqn-cartpole/` には DQN CartPole のサンプルがあり、RL 環境のサンドボックス化にも対応しています。

## 競合サービスとの比較

| 項目 | **OpenSandbox** | **E2B** | **Daytona** | **microsandbox** | **Modal** |
|:-----|:---------------|:--------|:------------|:-----------------|:---------|
| 分離技術 | Docker / K8s | Firecracker microVM | Docker (Kata optional) | libkrun microVM | gVisor |
| セキュリティ | コンテナレベル | **ハードウェアレベル** | コンテナレベル | **ハードウェアレベル** | アプリカーネル |
| セルフホスト | **完全対応** | クラウドのみ | 対応 | **完全対応** | 不可(SaaS) |
| SDK | **5言語** (Py/Java/JS/C#/Kt) | 2言語 (Py/JS) | 3言語 (Py/JS/Go) | 2言語 (Py/JS) | Python |
| K8s対応 | **ネイティブ(CRD/Helm)** | なし | なし | なし | 独自クラスタ |
| Egress制御 | **FQDN/IPレベル** | 限定的 | 限定的 | なし | 限定的 |
| ライセンス | Apache-2.0 | Apache-2.0 | AGPL-3.0 | Apache-2.0 | プロプライエタリ |
| 価格 | **無料(セルフホスト)** | Hobby無料/$150月 | $200無料クレジット | **無料(セルフホスト)** | $0.047/vCPU-h |

### OpenSandbox を選ぶべきケース

- **Kubernetes クラスタでの大規模運用**: K8s ネイティブ対応は現時点で OpenSandbox のみ
- **マルチ言語 SDK が必要**: Java/Kotlin, C#/.NET のサポートは他にない
- **Egress ネットワーク制御が必須**: FQDN レベルの詳細な制御が可能
- **Apache-2.0 が必要**: Daytona の AGPL-3.0 が問題になる場合
- **オンプレミス/プライベートクラウド運用**: 完全セルフホストが前提

### OpenSandbox を避けるべきケース

- **最高レベルの分離が必要**: 真に信頼できないコード（一般ユーザーからの任意コード）を実行する場合、microVM ベース（E2B, microsandbox）の方が安全
- **マネージドサービスが欲しい**: セルフホストの運用負荷を避けたい場合は E2B や Modal
- **すぐに本番投入したい**: まだ新しいプロジェクト（2025年12月作成）であり、本番実績は限定的

## アンチパターン・注意点

### 1. host ネットワークモードで Egress 制御を期待する

:::message alert
`network_mode = "host"` 設定では Egress 制御が機能しません。ネットワークポリシーを使う場合は必ず `"bridge"` モードを使用してください。
:::

### 2. コンテナ = 完全な隔離だと誤解する

Docker コンテナはホスト OS のカーネルを共有しています。コンテナエスケープの脆弱性が発見された場合、ホストに影響が及ぶ可能性があります。OpenSandbox は `drop_capabilities` や `pids_limit` でリスクを軽減していますが、**microVM レベルの隔離ではない**ことを理解した上で使用してください。

### 3. Docker Desktop のライセンスを見落とす

OpenSandbox はローカル実行に Docker Engine を必要とします。企業環境で Docker Desktop を使う場合、従業員数によってはライセンス費用が発生します（Docker Engine 自体は無料）。

### 4. 中国リージョンのレジストリに依存する

デフォルトのイメージレジストリは Alibaba Cloud の中国リージョン（`cn-zhangjiakou`）です。日本からは Docker Hub (`opensandbox/code-interpreter`) を使う方がプルが高速です。

## Kubernetes デプロイ

Kubernetes での運用は Helm Chart v0.1.0 が 2026年3月2日にリリースされました。

```bash
# Helm Chart のインストール（GitHub Releases から取得）
helm install opensandbox ./opensandbox-helm-chart
```

設定ファイルの Kubernetes セクション:

```toml
[runtime]
type = "kubernetes"

[kubernetes]
kubeconfig_path = "~/.kube/config"
namespace = "opensandbox"
workload_provider = "batchsandbox"  # or "agent-sandbox"
```

:::message
Kubernetes Runtime はまだ発展途上です。本番環境での採用は、Docker Runtime での十分な検証後に段階的に進めることを推奨します。
:::

## プロジェクトの現状と今後

### GitHub メトリクス（2026年3月3日時点）

- **Stars**: 4,117（公開数日で急速に成長中）
- **Forks**: 285
- **主要コントリビューター**: 5名（Alibaba 主導）
- **最終コミット**: 2026年3月2日（非常にアクティブ）

### ロードマップ

- Go SDK の開発
- 永続ストレージの本格対応
- マルチネットワーク Ingress 戦略
- 軽量ローカルサンドボックス（Docker 不要の軽量版?）
- Kubernetes Helm Charts の拡充

## まとめ

- **OpenSandbox** は Alibaba 発の Apache-2.0 オープンソースサンドボックスプラットフォーム
- **Control Plane / Data Plane 分離** により、ライフサイクル管理と実行処理が独立してスケール
- **5言語 SDK**（Python, Java/Kotlin, JS/TS, C#/.NET）は競合中で最多
- **Kubernetes ネイティブ対応** はオンプレミス/大規模運用の強力な差別化要素
- **FQDN レベルの Egress 制御** で、サンドボックスの外部通信を厳密に管理可能
- **コンテナベースの制約**: microVM（E2B, microsandbox）と比較して分離レベルは低い。セキュリティ要件に応じて使い分けが必要
- 2025年12月作成の新しいプロジェクトであり、本番実績はこれから蓄積される段階

AIエージェントの実行環境に「Kubernetes 上でのスケーラブルな隔離」が求められるなら、現時点で最も有力な選択肢です。

## 参考リンク

- [alibaba/OpenSandbox - GitHub](https://github.com/alibaba/OpenSandbox)
- [Alibaba Open-Sources OpenSandbox: Production-Ready Sandbox for AI Agents - Medium](https://ai-engineering-trend.medium.com/alibaba-open-sources-opensandbox-production-ready-sandbox-for-ai-agents-fdefb8e7c61a)
- [alibaba/OpenSandbox - DeepWiki](https://deepwiki.com/alibaba/OpenSandbox)
- [10 Best Sandbox Runners in 2026 - Better Stack](https://betterstack.com/community/comparisons/best-sandbox-runners/)
- [Top AI Sandbox Platforms in 2026 - Northflank](https://northflank.com/blog/top-ai-sandbox-platforms-for-code-execution)

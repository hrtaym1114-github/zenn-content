---
title: "【2026年最新】pyenv・rye・poetry・uvを整理する完全ガイド — Python 5ツール戦国時代を終わらせる"
emoji: "📦"
type: "tech"
topics: ["Python", "uv", "pyenv", "Poetry", "Rye"]
published: true
---

## この記事で分かること

- **pyenv / pyenv-win / rye / poetry / uv** — この5つの違いを1枚の表で整理します
- **どれを使えばいいのか** の2026年時点の最終結論（結論: uv一択ですが、理由が重要です）
- **既存プロジェクトから uv への移行手順** を5パターン（pyenv-win / pyenv / rye / poetry / pipenv）すべてカバー
- **やりがちなアンチパターン7選** と回避策
- **Windows環境での uv 運用** の落とし穴

:::message
**対象読者**: Pythonで「pyenvを使うべきか、poetryを使うべきか」で迷っている人、pyenv-win で Windows 環境構築したが最近「uvに乗り換えた方がいい」と聞いた人、Rye を使っているが将来が気になる人。
:::

---

## 「pyenv・rye・poetry・uv…結局どれを使えばいいの？」を整理する

Pythonのパッケージ管理ツールは、2024〜2026年の間に劇的に再編されました。結論を先に言うと、**2026年4月時点では uv 一択**です。ただし「なぜ uv なのか」を理解せずに乗り換えると、後述のアンチパターンにハマります。

まず、5つのツールの立ち位置を1枚の表で整理します。

| ツール | 現在の状態 | 責任範囲 | 2026年の推奨度 |
|--------|-----------|---------|---------------|
| **pyenv** | 活動継続中 | Pythonバージョン管理のみ（macOS/Linux） | 🟡 保守的選択肢 |
| **pyenv-win** | 活動継続中（別プロジェクト） | rbenv-winからフォークしたWindows向けポート（バッチスクリプト中心） | 🔴 uv へ移行推奨 |
| **Rye** | **2026年2月に公式アーカイブ** | プロジェクト管理統合ツール（Astral製） | 🔴 **uv へ移行必須** |
| **Poetry** | 活動継続中 | プロジェクト管理・パッケージ公開 | 🟡 ライブラリ配布なら選択肢 |
| **uv** | 急成長中（v0.11.7, 2026-04-15リリース） | Pythonバージョン + 仮想環境 + パッケージ + ツール | 🟢 **2026年の第一選択** |

### なぜ「戦国時代」だったのか

Pythonのツールは歴史的に **単一責任** で分割されていました。

```text
Pythonバージョン管理    → pyenv（macOS/Linux） / pyenv-win（Windows）
仮想環境              → venv / virtualenv
パッケージインストール  → pip
依存解決・ロック      → pip-tools / poetry / pipenv
プロジェクト管理      → poetry / rye / pipenv
ツール配布           → pipx
ビルド・公開         → twine / build
```

**8個のツールを組み合わせて使う**のが当たり前でした。しかも macOS/Linux と Windows で作法が違うという地獄。

uv はこれら **全てを1つのバイナリに統合** します。しかも Rust 実装で 10-100倍高速です。

### Rye はなぜ"卒業"になったのか（重要）

:::message alert
Rye は 2026年2月5日にリポジトリが公式アーカイブされました。開発は停止しています。メンテナは uv への移行を公式推奨しています。
:::

Rye の作者 Armin Ronacher 氏は、Rye のステワードシップ（メンテナンス主導権）を Astral（uvの開発元）に移譲しました。本人は Astral には参加していませんが、「Rye Grows With UV」というブログ記事で、今後の Python エコシステムの一本化方針として Rye → uv への統合を公式推奨しています。現在も Rye を使っているプロジェクトは、**早めに uv へ移行する**必要があります（記事後半で手順を解説）。

---

## 前提知識：2026年時点で uv が「ほぼ唯一の答え」になった理由

### 1. Python公式標準に準拠している

uv は PEP 517 / 518 / 621 などの Python 公式パッケージング標準を実装しています。`pyproject.toml` を正として扱うため、他ツールとの相互運用性が高く、プロジェクトの将来的な移植性も担保されます。

### 2. 速度が桁違い

uv 公式が発表している速度指標と、第三者調査の採用動向：

- **pip との比較**: uv は **10-100倍高速**（[公式README](https://github.com/astral-sh/uv)）
- **仮想環境作成**: 公式ベンチマークでは `uv venv` が pip 系ツールより大幅に速く、コミュニティ検証では `python -m venv` と比べて80倍程度高速との報告もある
- **採用率（JetBrains Python Developers Survey 2024）**:
  - uv: **0% → 12%**（2024年に初登場で1年でシェア1位級の普及）
  - Poetry: 19% → 20%
  - Pipenv: 9% → 8%
  - Rye: 調査対象外

### 3. Windows が"ファーストクラス"

pyenv は macOS/Linux ネイティブで、Windowsはコミュニティ移植の **pyenv-win** を別途インストールする必要がありました。uv は **1つのバイナリで3OS同じ挙動**。

---

## uv のセットアップ — 3OS 共通手順

### インストール

**macOS / Linux:**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows（PowerShell）:**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

:::message
Windows でも **pyenv-win のようなシェル初期化コードを `.bashrc` / `.zshrc` / PowerShell プロファイルに書き込む必要はありません**。uv はシムを使わないため、PATHに通すだけで動作します。
:::

### コアコマンド早見表

| コマンド | 旧ツール相当 | 説明 |
|---------|------------|------|
| `uv python install 3.12` | `pyenv install 3.12` | Python本体をインストール |
| `uv python pin 3.12` | `pyenv local 3.12` | `.python-version` を作成 |
| `uv init myproj` | `poetry new myproj` | 新規プロジェクト作成 |
| `uv add requests` | `poetry add requests` | 依存追加 |
| `uv remove requests` | `poetry remove requests` | 依存削除 |
| `uv sync` | `poetry install` | 仮想環境を lockfile に同期 |
| `uv run script.py` | `poetry run python script.py` | プロジェクト環境でスクリプト実行 |
| `uv lock` | `poetry lock` | lockfileを更新 |
| `uv tool install ruff` | `pipx install ruff` | グローバルツール導入 |
| `uv pip install requests` | `pip install requests` | pip互換モード（最終手段） |

### 典型的な新規プロジェクト立ち上げ

```bash
# プロジェクト作成（.python-version / pyproject.toml / .gitignore 等を自動生成）
uv init hello-world
cd hello-world

# Python 3.12 を使うように固定
uv python pin 3.12

# 依存追加（仮想環境は自動作成・同期される）
uv add requests httpx

# 実行
uv run main.py
```

`poetry` を使っていた人なら違和感ゼロで移行できます。`pyenv + venv + pip` を使っていた人にとっては **3ステップが1ステップに集約**されます。

---

## 既存プロジェクトから uv への5つの移行パターン

ここからが本題。自分の現在の環境に応じて該当パターンを選んでください。

### パターン1: pyenv-win（Windows）から uv へ

**最も強く移行を推奨するケース**です。pyenv-win は rbenv-win からフォークされた Windows 向けのコミュニティ製ポート（実装はバッチスクリプト中心）で、Windows のシェル環境差によって動作不安定になる既知の問題があります。

```powershell
# 1. uv インストール
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# 2. 既存の .python-version はそのまま使える（uvも読み取る）
#    プロジェクトディレクトリに移動
cd C:\path\to\project

# 3. Python 本体を uv 側で再インストール
uv python install

# 4. 動作確認
uv run python --version

# 5. pyenv-win を削除（動作確認後）
#    環境変数 PYENV, PYENV_HOME, PYENV_ROOT を削除
#    PATHから C:\Users\<user>\.pyenv\pyenv-win\shims を削除
```

:::message
`.python-version` ファイルは pyenv と uv で互換なので、**削除せずそのまま**使えます。
:::

### パターン2: pyenv（macOS/Linux）から uv へ

```bash
# 1. uv インストール
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Python を uv 側に再インストール
uv python install 3.12

# 3. シェル設定から pyenv 初期化を削除
#    ~/.zshrc や ~/.bashrc から以下を削除:
#    export PYENV_ROOT="$HOME/.pyenv"
#    eval "$(pyenv init -)"

# 4. uv python pin で .python-version 確定
cd ~/myproject
uv python pin 3.12

# 5. pyenv 削除（オプション）
rm -rf ~/.pyenv
```

### パターン3: Rye から uv へ

Rye はAstralが作者なので、移行は最もスムーズです。

```bash
# pyproject.toml の以下を変更:
# [tool.rye]         → [tool.uv]
# dev-dependencies    → [dependency-groups] の dev セクションへ移動
# virtual = true     → package = false （論理が反転）
# lock-with-sources = false → no-sources = true （論理が反転）

# コマンド置換
# rye sync           → uv sync
# rye add X          → uv add X
# rye run X          → uv run X
# rye fmt / rye lint → uv run ruff format / uv run ruff check
```

:::message alert
Rye の `[tool.rye.scripts]` に相当する機能は、2026年4月時点で uv に未実装です（Issue astral-sh/uv#5903 で議論中）。スクリプトが多い場合は `justfile` や `taskipy` で代替してください。
:::

### パターン4: Poetry から uv へ

Poetry の `pyproject.toml` は PEP 621 に完全準拠していないため、変換が必要です。

```bash
# 1. uv を使って一括変換
uv init --no-readme  # pyproject.toml のテンプレートが生成される

# 2. [project] セクションに依存を移行
#    Poetry の [tool.poetry.dependencies] →
#    PEP 621 の [project.dependencies] へ

# 3. poetry.lock を削除し、uv sync で uv.lock を生成
rm poetry.lock
uv sync
```

Poetry の lockfile（poetry.lock）と uv の lockfile（uv.lock）は互換性がないため、**CI含めて一括切り替え**が必要です。段階的移行は推奨しません。

**例外**: **PyPI にライブラリを公開する場合**、Poetry の `poetry publish` は現状 uv よりスムーズです。uv は `uv publish` を 2024年9月（v0.4.16）に追加しましたが、成熟度では Poetry が若干上です。

### パターン5: pipenv から uv へ

```bash
# 1. 現在の依存を requirements.txt にエクスポート
pipenv requirements > requirements.txt

# 2. uv プロジェクト初期化
uv init
uv add -r requirements.txt

# 3. Pipfile, Pipfile.lock を削除
rm Pipfile Pipfile.lock
```

pipenv は **採用率が減少傾向**（JetBrains 2024調査で 9% → 8%）ですが、開発は継続しています。2026年4月には CLI を argparse に書き換える大規模リファクタリングを含む 2026.5.x 系がリリースされており、保守は活発です。ただし「2026年からの新規プロジェクト」の選択肢としては uv を推奨します。

---

## Astral 公式が推奨するベストプラクティス

uv の開発元 Astral が公式ドキュメントで推奨している指針です。

> uv replaces pip, pip-tools, pipx, poetry, pyenv, twine, virtualenv, and more.
>
> — [uv公式ドキュメント](https://docs.astral.sh/uv/)

### 推奨1: プロジェクト管理は uv sync + uv lock を主軸に

`pip install` を直接叩くのではなく、`uv add` → `uv sync` のフローを徹底。lockfileがあれば「他環境でも同じ結果になる」再現性が得られます。

### 推奨2: グローバルツールは uv tool install で

`ruff`, `black`, `pytest` などのCLIツールは `uv tool install <name>` でグローバル導入する。

```bash
uv tool install ruff
uv tool install black
uv tool run pytest  # 一時的に実行するだけならinstall不要
```

`pipx` の置き換えになります。

### 推奨3: 単発スクリプトは inline dependencies で管理

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
import httpx
print(httpx.get("https://example.com").status_code)
```

`uv run script.py` で実行すれば、依存を自動解決して実行してくれます。一時的な検証スクリプトに便利。

---

## やりがちなアンチパターン 7選

### 1. `uv pip install` を日常的に使う

:::message alert
`uv pip install` は「pip互換モード」で、プロジェクトの `uv.lock` や `pyproject.toml` を更新しません。lockfileの再現性が失われるため、**移行初期の応急処置以外では使わないこと**。
:::

正しくは `uv add <pkg>` を使う。

### 2. Poetry と uv を同一プロジェクトで併用する

どちらもlockfileを生成するため、片方で依存を追加するともう片方の整合性が崩れます。**プロジェクト全体を一気に切り替える**のが鉄則。

### 3. `pyenv-win` を残したまま uv を追加インストール

Windowsで両方入っていると、`python` コマンドがどちらの Python を指すか不定になります。PATH優先度の問題でハマりやすい。uv 導入後は **pyenv-win を完全アンインストール**する。

### 4. `.venv` を git にコミットする

uv は `uv.lock` を git にコミットしておけば、`uv sync` で誰でも同じ環境を再現できます。`.venv` はローカル生成物なので `.gitignore` に必ず追加。

```gitignore
.venv/
__pycache__/
*.pyc
```

### 5. `uv init` 後すぐに `uv add` せず、pip で依存を追加する

`uv init` で生成された `pyproject.toml` は `[project.dependencies]` セクションが空です。ここに `uv add` で入れることで lockfile が更新されます。`pip install` で直接入れるとpyproject.toml と実環境がズレる。

### 6. CI で `uv lock` を毎回走らせる

CI では `uv lock` ではなく `uv sync --frozen`（lockfileを更新せず既存通りにインストール）を使う。毎回 lock を更新すると意図しない依存バージョン変更が入るリスクがあります。

```yaml
# GitHub Actions 例（2026年4月時点の公式推奨は v7 系）
- uses: astral-sh/setup-uv@v7
- run: uv sync --frozen
- run: uv run pytest
```

### 7. Python バージョンを `.python-version` で固定し忘れる

`uv init` は自動で `.python-version` を作りますが、既存プロジェクトへ uv 導入した際は忘れがち。これを git にコミットしないと、チームで Python バージョンがバラつきます。

```bash
uv python pin 3.12
git add .python-version
```

---

## 推奨バージョン・設定の最適値

| 状況 | 推奨 | 理由 |
|------|------|------|
| **Python バージョン** | 3.12 系 | 2026年時点で最も安定、主要ライブラリ対応済み |
| **uv バージョン** | 0.11.x 以上 | 0.11系でCLI仕様が概ね固まった |
| **lockfile コミット** | 必ずコミット | `uv.lock` が再現性の核 |
| **CI コマンド** | `uv sync --frozen` | 勝手なバージョン変更を防ぐ |
| **Python インストール方式** | `uv python install`（managed） | システム依存から独立 |
| **グローバルツール数** | 5個以内目安 | 多すぎるとアップデート管理が煩雑 |

---

## 2026年時点のツール比較表

| ツール | 速度 | Pythonバージョン管理 | プロジェクト管理 | lockfile | Windows対応 | ライブラリ公開 | 2026年推奨 |
|--------|------|---------------------|----------------|---------|------------|--------------|-----------|
| **uv** | 🟢🟢🟢 超高速 | 🟢 あり | 🟢 あり | 🟢 uv.lock | 🟢 ネイティブ | 🟡 `uv publish`（成熟中） | ★★★ |
| Poetry | 🟡 普通 | 🔴 なし | 🟢 あり | 🟢 poetry.lock | 🟡 可 | 🟢 成熟 | ★★（公開用途） |
| pyenv/-win | 🟡 普通 | 🟢 あり | 🔴 なし | 🔴 なし | 🟡 要pyenv-win | 🔴 なし | ★（過去資産向け） |
| Rye | 🟢 速い | 🟢 あり | 🟢 あり | 🟢 あり | 🟢 あり | 🟢 あり | **使用停止**（アーカイブ済） |
| pipenv | 🔴 遅い | 🔴 なし | 🟢 あり | 🟢 Pipfile.lock | 🟡 可 | 🔴 なし | ★（保守のみ） |
| pip + venv | 🔴 遅い | 🔴 なし | 🔴 なし | 🔴 なし | 🟢 あり | 🔴 なし | ★（最小構成） |

---

## 実践チェックリスト

### 新規プロジェクト開始時

- [ ] `uv init <project-name>` でプロジェクト作成
- [ ] `uv python pin 3.12` で Pythonバージョン固定
- [ ] `.python-version` を git コミット
- [ ] `uv.lock` を git コミット
- [ ] `.venv/` は `.gitignore` に追加

### 既存プロジェクト移行時

- [ ] 現在のツール特定（pyenv-win / pyenv / rye / poetry / pipenv）
- [ ] 該当するパターン（1〜5）を上から実行
- [ ] `uv sync` が通ることを確認
- [ ] `uv run pytest`（テストがあれば）でCI相当動作確認
- [ ] 旧ツール（pyenv-win / poetry 等）をアンインストール

### 日常運用

- [ ] 依存追加は `uv add <pkg>`（`uv pip install` は使わない）
- [ ] lockfile は常に最新をコミット
- [ ] CI では `uv sync --frozen` を使用
- [ ] Python バージョンアップ時は `uv python install <new-version>` → `uv python pin <new-version>`

---

## まとめ

- **2026年のPython環境構築は uv 一択**（Rye は2026年2月にアーカイブ、pyenv-winは非推奨、pipenvは採用減）
- **uv は `pip + venv + pyenv + pipx + poetry` を1つに統合** — ツール数が8個から1個に減る
- **速度は pip 比で 10-100倍**（公式）
- **Windows がファーストクラス**（pyenv-win のような別実装が不要）
- **移行パターンは5通り** — pyenv-win / pyenv / rye / poetry / pipenv すべて手順化済み
- **Poetry は「ライブラリ公開用途のみ」残す**選択もアリだが、新規は uv 推奨

この記事は「どれを使うべきか」の迷いを終わらせるために書きました。迷う時間があれば、`uv init` を1回叩いてみる方が100倍早く答えが出ます。

---

## 参考リンク

- [uv 公式ドキュメント](https://docs.astral.sh/uv/)
- [uv GitHub リポジトリ](https://github.com/astral-sh/uv)
- [Rye → uv 移行ガイド（Astral公式）](https://rye.astral.sh/guide/uv/)
- [uv Python バージョン管理](https://docs.astral.sh/uv/concepts/python-versions/)
- [uv ベンチマーク（GitHub）](https://github.com/astral-sh/uv/blob/main/BENCHMARKS.md)
- [pyenv から uv への移行（pydevtools）](https://pydevtools.com/handbook/how-to/how-to-switch-from-pyenv-to-uv-for-managing-python-versions/)

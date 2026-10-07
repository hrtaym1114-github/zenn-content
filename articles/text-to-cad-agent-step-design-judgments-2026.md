---
title: "text-to-cadを整理する — エージェントにSTEPを書かせるとき設計側に残る判断"
emoji: "📐"
type: "tech"
topics: ["CAD", "AIエージェント", "ClaudeCode", "Cursor", "製造業"]
published: true
---

## この記事で分かること

エージェントに「ブラケットをSTEPで出して」と頼むと、ローカルでモデルが生成され、壁厚やオーバーハングのチェックまで走る——そういう経路が2026年秋時点で公開されている。[earthtojake/text-to-cad](https://github.com/earthtojake/text-to-cad)（MIT、公式サイト [texttocad.dev](https://www.texttocad.dev)）がその代表だ。

本記事で整理するのは次の4点。

1. **下回りカーネル**（build123d / CadQuery / OpenSCAD）の違いと、text-to-cadがどれに載っているか
2. **Claude Code / Cursor などへの入れ方**の差（プラグイン経路と skills 単独）
3. **製造向けチェック**（壁厚・オーバーハング・板金/CNC/射出）がどこまで機械で測れ、どこからがレビュー手順か
4. **寸法・公差・図面承認**が設計側に残る線

宣伝や導入CTAは置かない。主役は「課題と既存手段の整理」である。

:::message
**対象読者**: エージェントにCADを触らせたい機械設計・製造寄りエンジニア。CADカーネルと「人が残る判断」の境界を先に知りたい人。
:::

:::message
**時点**: 2026-10-07（JST）。text-to-cad の最新リリースは **v0.7.15**（GitHub Releases 公開日時 2026-10-06 05:45 UTC ≒ 同日 14:45 JST）。cadgen 0.7.15 の PyPI 依存は `build123d>=0.11.1,<0.12`。リポジトリの README・スキル定義・PyPI メタデータを一次情報として読む。**筆者はこの記事執筆時点で text-to-cad を未インストール・未実行**のため、実測表は載せない。
:::

---

## 何が新しかったか — 「チャットで形を描く」ではなく「STEPを渡せる経路」

テキストから3Dを起こす話自体は以前からある。OpenSCADにスクリプトを書かせる、クラウドの生成CAD APIに投げる、メッシュだけ出して終わる、といった手段だ。現場で詰まるのはだいたい次のどれかである。

| 詰まりどころ | 典型的な既存手段 | 残る痛み |
|-------------|----------------|---------|
| 下流がB-repを要求する | STL/GLB生成 → 人手でSTEP再構築 | 寸法が崩れる・公差が載らない |
| エージェントがCADソフトを知らない | 「手順をMarkdownで教える」 | 手順が腐る・再現性がエージェント依存 |
| 印刷前チェックが目視 | スライサー画面を人が見る | 壁厚・オーバーハングの根拠が残らない |
| 図面が別ツール | CADから手動で2D化 | モデル更新と図面が乖離する |

text-to-cad の自己申告（README / 公式サイト）は、この隙間を **ローカルのスキル群 + cadgen（PyPI）** で埋める、という位置づけだ。

- 主出力は **STEP**（ほか STL / 3MF / GLB）
- 製造チェック（DfAM / DFM）、エンジニアリング図面PDF、板金向けDXF、URDF などもスキルとして同梱
- Claude Code / Codex / Cursor / Gemini / Grok など、プラグインまたは [skills](https://skills.sh) 枠を持つエージェント向け

GitHub API上のリポジトリ作成は **2026-04-22**。2026-10-07時点の公開メタデータでは **スター約18,236・フォーク約1,816・ライセンス MIT**（数値は時点依存）。「話題の新リポジトリ」ではなく、すでに広く参照されている経路、という読み方が妥当だろう。

> 📌 本記事の主軸は「text-to-cadの機能一覧」ではない。**エージェントにSTEPを書かせたあと、設計側がまだ自分で決めなければならない線**を比較表で固定すること。

---

## 下回りカーネルを整理する — build123d / CadQuery / OpenSCAD

エージェントが「CADできる」と言っても、下に何があるかで **渡せるファイルの意味**が変わる。ここを混同すると「STEPが欲しいのにメッシュしか出ない」事故が起きる。

| 項目 | build123d | CadQuery | OpenSCAD |
|------|-----------|----------|----------|
| 一次情報 | [gumyr/build123d](https://github.com/gumyr/build123d) README・docs | [CadQuery/cadquery](https://github.com/CadQuery/cadquery) | [openscad/openscad](https://github.com/openscad/openscad) |
| 幾何の型 | **B-rep**（境界表現） | **B-rep** | **CSG**（構成的立体幾何）寄り。B-repカーネルではない |
| 幾何カーネル | Open CASCADE（OCP 経由） | Open CASCADE（OCCT / cadquery-ocp） | 独自のCSG評価 → メッシュ化が主戦場 |
| 言語 | Python | Python | OpenSCAD言語（専用DSL） |
| ライセンス（自己申告） | Apache-2.0 | リポジトリ表示は NOASSERTION（利用時はリポジトリの LICENSE を確認） | 同上（GPL系の歴史。利用時は LICENSE を確認） |
| STEPとの相性 | ネイティブに近い（export_step 等） | 同様 | 直接の「設計意図つきSTEP」運用とは別物になりやすい |
| 2026-10-07時点のスター（GitHub API） | 3,332 | 5,892 | 10,376 |
| PyPI最新（同日確認） | build123d **0.13.0** | CadQuery **2.8.0** | （デスクトップアプリ中心。PyPIの「openscadパッケージ」とは別議論） |

### text-to-cad との関係（公式バッジと依存で確認）

READMEのバッジは明示的に **build123d 0.11** と **Open CASCADE 7.9** を掲げている。cadgen 0.7.15 の PyPI `requires_dist` も次で一致する（自己申告・パッケージメタデータ）。

- `build123d>=0.11.1,<0.12`
- `cadquery-ocp-novtk>=7.9,<8`

つまり **モデル記述のAPIは build123d**、**幾何の実体は Open CASCADE（cadquery-ocp 系ホイール）** である。CadQuery本体をエージェントが直接叩く構成ではない。build123d 自身のREADMEも「CadQuery由来の部分を持ちつつ、独立したフレームワークとして再構成した」と書いており、家系図上は近いが、**text-to-cadのピンは build123d 0.11系**（2026-10-07時点の build123d 最新 0.13.0 より一段古いレンジ）と読んでおく。

| 誤解しやすい点 | 実態（一次情報ベース） |
|---------------|----------------------|
| 「CadQueryで動いている」 | 依存に見えるのは **cadquery-ocp**（OCCTバインディング）。CadQuery DSLそのものではない |
| 「OpenSCADの上位互換」 | 幾何モデルが違う。OpenSCAD経路の資産をそのままSTEP運用に載せ替えられるわけではない |
| 「最新build123dならそのまま」 | cadgen 0.7.15 は **`<0.12`**。上位版を勝手に上げるとスキルが想定するAPIとずれる可能性がある |

OpenSCADは今でも「エージェントにスクリプトを書かせてプレビューする」用途では強い。ただし本記事の主題である **STEP引き渡し** では、B-rep系（build123d / CadQuery）と土俵が違う、と先に切っておくのが安全だ。

---

## エージェントへの入れ方 — Claude Code / Cursor / その他

公式インストール手順（[texttocad.dev](https://www.texttocad.dev) / README、2026-10-07確認）はエージェントごとに分岐する。共通前提は **uv が入っていること**（CADランタイムが uv / uvx 経由）。

| エージェント | 入れ方の要約（公式） | ビューア周り（公式の自己申告） |
|-------------|---------------------|-------------------------------|
| **Claude Code** | marketplace に `earthtojake/text-to-cad#latest` を追加 → `text-to-cad@earthtojake` を install | プラグインがCADサーバも起動。アプリビュー対応環境ではビューアカード |
| **Cursor** | Claude Codeプラグインが入っていれば **追加不要**。単独なら `latest` ブランチを `~/.cursor/plugins/local/text-to-cad` に clone | Claude Code経路と共有できる |
| **Codex** | プラグインディレクトリ経由、または marketplace add → plugin add | サイドバー/スレッド横のCADタブなど（公式README） |
| **Gemini** | `gemini extensions install ... --ref latest` | ツール結果はテキスト寄り。ビューアはリンク提示 |
| **Grok Build** | `grok plugin install ...@latest`。Claude Codeプラグインがあればスキップ可 | 同上（リンク提示） |
| **その他** | `npx skills add earthtojake/text-to-cad#latest`（skillsのみ） | プラグイン無し＝CADサーバ無し。ブラウザのCAD Viewerで開く |

運用上の注意はREADMEが先に書いている。

1. **`latest` と `main` を混同しない** — インストールは `latest`（リリース後のプラグイン枝）。`main` は開発中で未リリース変更を含むことがある
2. **プラグインと skills の二重入れをしない** — 同じスキルが二重登録される
3. **Windows 11 Smart App Control** — OCPの未署名ネイティブモジュールがブロックされ、`import build123d` が失敗しうる（公式が Event ID 3077 まで明記）。回避は SACオフ（再インストールまで戻せない制約あり）か WSL

```bash
# Claude Code（公式）
claude plugin marketplace add earthtojake/text-to-cad#latest
claude plugin install text-to-cad@earthtojake

# Cursor（Claude Code未導入時・公式）
git clone --depth 1 --branch latest \
  https://github.com/earthtojake/text-to-cad \
  ~/.cursor/plugins/local/text-to-cad
```

CADスキル側のモデル契約（`skills/cad/SKILL.md`）はざっくりこうだ。

- 1エントリポイント＝パラメータ無しのデコレート関数が build123d 形状を返す
- `@step(out="...")` などで成果物パスを宣言し、`python src/xxx.py` で再生成
- 検査は保存済み成果物に対して行い、パスの git status を幾何の証拠にしない

つまりエージェントにやらせる本体は「チャットの一発生成」ではなく、**再生可能なPythonモデルの編集と再実行**である。

---

## 製造チェックの自動化範囲 — 測れるもの / レビュー手順 / 人が決めるもの

ここが本記事の核心に近い。text-to-cadは「製造OKを保証するエンジン」ではなく、**計測とチェックリスト駆動のレビュー**をスキルとして渡す。公式スキル定義をそのまま読むと境界がはっきりする。

### DfAM Check（積層向け・メッシュ計測）

一次情報: [`skills/dfam-check/SKILL.md`](https://github.com/earthtojake/text-to-cad/blob/latest/skills/dfam-check/SKILL.md)

| できること（公式） | できない・注意（公式） |
|-------------------|----------------------|
| 壁厚・オーバーハング・サポート体積・ビルド姿勢候補などを **ローカル計測** | ツール自体は **fact-only**（pass/failを出さない）。合否はスキル手順が process-limits と比較する |
| FDM / SLS / SLA 等プロセス別の限度表と比較 | STEPを直接メッシュ計測しない。STL等へ落としてから測る |
| 再設計指示を具体的な数値付きで返す（例: ある座標の壁を 0.6mm→≥1.2mm） | 粉末プロセスの「閉じた空洞のパウダー逃げ」は未計測 → `❓ need more info` |
| | 単位スケール不審時は比較を止める（`scale.units_suspect`） |

### DFM（板金 / CNC / 射出）

一次情報: [`skills/dfm/SKILL.md`](https://github.com/earthtojake/text-to-cad/blob/latest/skills/dfm/SKILL.md)

| プロセス | 計測スクリプト | 公式の位置づけ |
|---------|---------------|---------------|
| 板金 | **なし**（CAD検査 or 提示寸法） | ガイド付きレビュー。自動特徴認識・製造認証エンジンではない |
| CNC | **なし** | 同上 |
| 射出 | `mold_tool.py`（抜き勾配・アンダーカット・投影面積） | 計測は fact-only。樹脂/金型限度との比較はレビュー側 |

明示されている原則:

- サプライヤ実仕様を一般論より優先する
- 証拠が無ければ **unverified** とし、発明しない
- 「所見ゼロ」＝製造承認、ではない

### 自動化範囲の比較表（読み方の提案）

| チェック項目 | 自動計測に寄せられるか | text-to-cad上の置き場 | 設計側に残る判断 |
|-------------|----------------------|----------------------|----------------|
| 壁厚・オーバーハング（積層） | **高い**（メッシュ計測） | DfAM Check | どのプロセス限度表を採用するか／実機データシートの上書き |
| サポート量・姿勢 | **中〜高**（上限寄りのコスト信号） | DfAM Check | コスト予算・後処理方針 |
| 板金の曲げ・逃げ | **低い**（計測スクリプト無し） | DFM参照チェックリスト | ブランク・金型・工程設計 |
| CNCの工具アクセス・段取り | **低い** | 同上 | 治具・工具・公差方針 |
| 射出の勾配・アンダーカット | **中**（メッシュ計測あり） | DFM + mold_tool | パーティング・樹脂・シボ |
| 寸法公差の採否 | **ほぼ人手** | 図面スキルは値を発明しない | 機能公差・フィット・規格 |
| 図面承認・出図 | **人手** | PDFは生成できても承認権限は外 | 改訂・責任分界 |

---

## 図面は出せる — だが公差と承認は人が書く

一次情報: [`skills/engineering-drawing/SKILL.md`](https://github.com/earthtojake/text-to-cad/blob/latest/skills/engineering-drawing/SKILL.md)

エンジニアリング図面スキルは、パート幾何から投影した **PDF1枚** を出す。隠れ線・寸法・穴コールアウト・タイトルブロックまでモデル連動、というのが公式の売りだ。一方で限界も同じ文書に明記されている。

| 項目 | 公式の扱い |
|------|-----------|
| 公差 | `tol=` / `fit=` / `general_tolerance=` に **書いた値だけ**。モデルから発明しない |
| 断面・詳細・補助投影 | **未対応**（正投影＋隠れ線が中心） |
| 出力 | PDF。DXF図面ではない（切断用DXFは別スキル `$dxf`） |
| 失敗時 | 誤ったシートを黙って書かず raise（フレーム外・レンダラ欠落など） |

ここから出る設計側の残件は単純だ。

1. **どの寸法にどの公差を載せるか** — エージェントは空欄のまま測った公称値を置くことはできても、「IT7にするか、はめあいをH7/g6にするか」は要件側の判断
2. **図面の読み合わせ** — アノテーションと線の重なりは完全自動では保証されない（公式も「PDFを読め」と書く）
3. **承認** — 生成物はドキュメント候補であって、出図権限の代替ではない

> ⚠️ 「エージェントが図面まで出した＝製造リリース」は、スキル自身の契約と矛盾する。DfM/DfAMも「所見なし＝承認」ではない。

---

## 設計側に残る判断 — チェックリスト

エージェントにSTEPを書かせる運用を始める前に、人が握る項目を先に固定しておくと事故が減る。

| # | 人が残すべき判断 | エージェントに任せてよい作業（公式能力の範囲） |
|---|-----------------|-----------------------------------------------|
| 1 | 機能要求・インターフェース寸法・基準面 | 明示された寸法でのパラメトリックモデル編集 |
| 2 | 材料・熱処理・表面処理 | タイトルブロックへの転記（値の発明は不可） |
| 3 | 公差・はめあい・一般公差の採用規格 | 指定された `tol=` の描画 |
| 4 | 製造プロセス選定（積層か切削か板金か） | 選定後の DfAM/DFM 計測・チェックリスト実行 |
| 5 | サプライヤ能力の最終確認 | 公開ナレッジを参照データとして読む（指示として実行しない） |
| 6 | 図面改訂・出図承認 | PDF再生成・ビュー配置の機械的更新 |
| 7 | セキュリティ（図面・STEPの社外持ち出し） | ローカル実行（クラウド生成CADに投げない、という選択の実装） |

text-to-cadは「設計者を置き換える」より、「**再生可能なCADソースと計測ログをエージェント作業に載せる**」側の道具、と読むと既存のPLM/出図プロセスと衝突しにくい。

---

## いつ使うか / まだ使わないか

| 向きやすい | 向かない・慎重 |
|-----------|---------------|
| 社内でSTEP/STLをエージェント経由で回したい | 公差設計そのものを自動化したい（スキルが拒否する） |
| Claude Code / Cursor などプラグイン可能な環境 | CADカーネル未導入の制約環境（特に Windows SAC） |
| 積層前の壁厚・オーバーハングを数値で残したい | 「所見ゼロ＝量産OK」を監査で通したい |
| build123d でモデルをコード管理したい | OpenSCAD資産をそのままSTEP運用に載せ替えたい |

代替・併用の整理（優劣ではなく役割分担）:

| 手段 | 向く仕事 |
|------|---------|
| **OpenSCAD + エージェント** | メッシュ中心・教育・簡単なCSG、印刷プレビュー |
| **CadQuery / build123d を直接** | 人間がPython CADを主書きする。エージェント無しでも完結 |
| **商用CAD + API/マクロ** | 既存PDM・図面規格・大手サプライヤ条件が支配的な現場 |
| **text-to-cad（本記事）** | エージェントに **STEP主出力＋計測スキル** を載せるローカル経路 |

---

## 一次情報一覧

| 種別 | URL | 日付・版 | 備考 |
|------|-----|---------|------|
| 公式リポジトリ | https://github.com/earthtojake/text-to-cad | 作成 2026-04-22 / 本稿確認 2026-10-07 | MIT。スター等は時点依存 |
| 公式サイト | https://www.texttocad.dev | 2026-10-07確認 | インストール手順の集約 |
| リリース | https://github.com/earthtojake/text-to-cad/releases/tag/v0.7.15 | published_at 2026-10-06 05:45 UTC | 本稿の版ピン |
| PyPI cadgen | https://pypi.org/project/cadgen/0.7.15/ | 0.7.15 | `build123d>=0.11.1,<0.12` 等 |
| build123d | https://github.com/gumyr/build123d | README確認 2026-10-07 | Apache-2.0。CadQuery由来の再構成を自己申告 |
| CadQuery | https://github.com/CadQuery/cadquery | API確認 2026-10-07 | OCCTベースのPython CAD |
| OpenSCAD | https://github.com/openscad/openscad | API確認 2026-10-07 | CSG系。B-repの対比用 |
| スキル: CAD | `skills/cad/SKILL.md`（latest） | cadgen==0.7.15 をピン | モデル契約 |
| スキル: DfAM | `skills/dfam-check/SKILL.md` | 同上 | 壁厚・オーバーハング計測 |
| スキル: DFM | `skills/dfm/SKILL.md` | 同上 | 板金/CNC/射出レビュー |
| スキル: 図面 | `skills/engineering-drawing/SKILL.md` | 同上 | 公差は手入力のみ |

公式・パッケージメタデータは一次、スター数や「話題」は時点付きの二次指標として扱った。

---

## まとめ

- text-to-cadは、エージェント向けに **STEP主出力のローカルCAD経路** と製造チェック／図面スキルをまとめたプラグイン／skills群である（v0.7.15時点）
- 下回りは **build123d 0.11系 + Open CASCADE 7.9（cadquery-ocp）**。CadQuery DSLそのものでも OpenSCADでもない
- Claude Code / Cursor などは公式インストールが分かれる。CursorはClaude Codeプラグイン共有が基本ルート
- 壁厚・オーバーハングは計測に寄せられる。板金/CNCの多くと、**公差・出図承認**は設計側に残る
- 未体験の実測は書いていない。入れるならインストール条件・OS・版を明示した表を末尾に足すのが正しい

公開前に人間側で見たい点: (1) 自環境で `cadgen doctor` が通るか (2) 社内の図面規格と `engineering-drawing` のシート前提が噛むか (3) Windowsを使うなら Smart App Control 方針。

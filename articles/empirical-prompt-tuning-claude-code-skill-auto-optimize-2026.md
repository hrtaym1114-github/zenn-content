---
title: "【2026年最新】Claude Code Skillsを「経験的に最適化する」完全ガイド — empirical-prompt-tuningとSkill Creatorの違いから収束判定まで"
emoji: "🔬"
type: "tech"
topics: ["ClaudeCode", "Skills", "Prompt", "AI", "LLM"]
published: false
---

## この記事で分かること

2026年4月19日、mizchi氏が公開したClaude Code Skill **[`empirical-prompt-tuning`](https://github.com/mizchi/chezmoi-dotfiles/blob/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md)** がX.comで約11,000ブックマークを集めました（2026-04-21時点）。内容は「**Skillの品質は書いた本人には分からない。だから別エージェントに実行させて計測し、書き換え続けろ**」という経験的最適化の方法論です。

一方でAnthropic公式の `skill-creator` も **Create/Eval/Improve/Benchmark** の4モードを持ち、最近リリースされた `Skill Creator v2`、`writing-skills`、`retrospective-codify`、`prompt-optimizer` など **「Skillを作る・評価する・育てる」系ツールが急増** しています。どれをいつ使えばいいのか混乱しているはず。

この記事では:

- mizchi版 `empirical-prompt-tuning` と公式 `skill-creator` の役割分担を表で整理
- 8ステップワークフロー（Iter 0 + 本編7ステップ）を実行可能な粒度まで分解
- `tool_uses` の偏在から構造欠陥を読む「質的メトリクス解釈」
- 収束判定・過適合チェック・発散シグナルの具体値
- やりがちなアンチパターン8選

を、SKILL.md原典を引用しながら解説します。

:::message
**対象読者**: Claude Code Skillsを5個以上運用していて、「なんとなく効いてる気がするが本当に効いているのか計測できていない」状態の中級者
:::

---

## Skills最適化ツールは4系統ある — まず整理しよう

同じ「Skill改善」という言葉が、実は4つの別目的で使われています。ここが最大の混乱ポイントです。

| 系統 | 代表ツール | 目的 | いつ使うか | 実行者 |
|------|-----------|------|-----------|--------|
| **作成系** | `skill-creator`（Anthropic公式） | ゼロからSkillを作る | 新規作成時 | Claude自身 |
| **経験的計測系** | `empirical-prompt-tuning`（mizchi） | **書いた直後 / 既存の品質保証** | 作成・改訂直後 | 別subagent |
| **静的品質系** | `writing-skills`（superpowers） | TDD的にSkillを書く方法論 | 執筆中 | 書き手自身 |
| **学び固定化系** | `retrospective-codify` | タスク完了後の教訓をSkill化 | タスク完了後 | タスク実行者 |

**一番誤解されやすいポイント**: `skill-creator` は「作ってくれる」ツール、`empirical-prompt-tuning` は「**作った後に計測して書き換え続ける**」ツール。役割が競合しません。

### 誤解パターン1: 「Skill Creatorで作ったから十分」

Skill Creatorは5〜6個の質問からSkillを自動生成します。v2でEvalも搭載されましたが、**Evalは「作者が定義したテストケース」で評価する枠組み**です。作者のバイアスが入ります。

一方 `empirical-prompt-tuning` は「**書いた本人はバイアスから逃れられない**」という前提に立ち、**新規dispatchしたsubagent**に実行させて、その**自己申告レポート**を評価材料にします。

### 誤解パターン2: 「自分で読み返せば同じこと」

原典が明確に否定しています:

> 「自分で読み直せば同じ効果がある」 → 直前に書いた文章を "客観視" はできない。必ず新規 subagent を dispatch する。

:::message alert
**自己再読は評価として成立しません**。書き手は「こう読むはず」という前提で読むため、詰まる箇所を検出できません。
:::

### コマンド衝突に注意

Skills 2.0 環境下で `skill-creator` の Improve モードを使うと、内部で似た計測を行うことがあります。**`empirical-prompt-tuning` と同時に走らせない**でください。両者は独立した評価サイクルなので、混ぜると「どの修正が効いたか」追跡不能になります。

---

## 前提知識：なぜ「経験的」でなければダメなのか

従来のSkill品質管理は3つの罠を抱えていました。

1. **書き手の盲点**: 「これで分かるはず」と書いた説明が、文脈を共有しない別エージェントには曖昧に見える
2. **テストケース作者バイアス**: 作者が想定した入力でしか評価できない（= 作者が想定できなかった失敗を捉えられない）
3. **静的レビューの限界**: 文法チェックは通っても、実行すると詰まる箇所がある

`empirical-prompt-tuning` はこれを **「別のエージェントに本当に実行させ、**自己申告と計測の両面**で評価する」** という TDD 的アプローチで解決します。プロンプトを「一度書いたら完成」ではなく「**継続チューニング対象のプロダクト**」として扱うパラダイムシフトです。

---

## `empirical-prompt-tuning` のセットアップと使い方

### インストール

mizchi氏の dotfiles から該当Skillだけコピーします。

```bash
# 必要なSKILL.mdだけダウンロード
mkdir -p ~/.claude/skills/empirical-prompt-tuning
curl -o ~/.claude/skills/empirical-prompt-tuning/SKILL.md \
  https://raw.githubusercontent.com/mizchi/chezmoi-dotfiles/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md
```

### 起動

Claude Code セッション内で以下のように依頼します:

```
/skill empirical-prompt-tuning を使って、
`.claude/skills/my-skill/SKILL.md` を評価・改善してください。
シナリオは中央値1本、エッジ1本でお願いします。
```

### 8ステップワークフロー（Iteration 0 + 本編7ステップ）

| ステップ | 内容 | キー成果物 |
|---------|------|----------|
| **0（前処理）** | description と body の整合チェック（静的・dispatch不要） | 差異レポート |
| 1 | ベースライン準備（シナリオ2-3 + チェックリスト） | シナリオ定義 |
| 2 | バイアス排除読み（新規subagent dispatch） | 白紙実行者 |
| 3 | 実行（subagent起動契約に従って） | 成果物+レポート |
| 4 | 両面評価（自己申告 + 計測） | 評価軸表 |
| 5 | 差分適用（1イテレーション1テーマ） | 修正済Skill |
| 6 | 再評価（**新しいsubagentで**再度2→5） | Iter N レポート |
| 7 | 収束判定 | 停止 or 継続 |

---

## empirical-prompt-tuning を動かす5つのワークフロー

### パターン1: 新規Skillの「出生検査」

新規作成直後の Skill に対し、最初に1サイクル回します。**description と body の整合チェック（Iter 0）だけ先行**するのがコツ。ここが乖離していると、subagent が description に合わせて body を再解釈してしまい、**実質Skillが要件を満たしていないのに精度が出る false positive** を踏みます。

```bash
# シナリオファイルの雛形
cat > scenarios.md <<'EOF'
## シナリオA（中央値）
<よくある使用場面>

## 要件チェックリスト
1. [critical] <最低ライン>
2. <通常項目>
3. <通常項目>

## シナリオB（エッジ）
<異常系・境界値>
...
EOF
```

:::message
`[critical]` タグは **最低1つ必須**。0件だと成功判定が vacuous（真空）になり、全部 × でも「critical は全て ○」と判定されてしまいます。
:::

### パターン2: 並列dispatchでシナリオ同時評価

シナリオ2-3本を `superpowers:dispatching-parallel-agents` と組み合わせ、**単一メッセージ内で複数 Agent 呼び出しを並べて並列実行**します。逐次だと10-15分かかるところが3-5分に短縮されます。

### パターン3: `tool_uses` の偏在から構造欠陥を読む

精度100%でも `tool_uses` が偏っていたら **iter 2 発動の根拠**になります。原典より:

> シナリオ間で他シナリオ比 **3-5 倍以上** なら、その skill は **decision-tree index 寄りで自己完結性が低い** サイン。

典型例: 全シナリオ `tool_uses` が 1-3 なのに 1 シナリオだけ 15+ → そのシナリオ用の recipe が skill 内に無く、references/ を横断探索している証拠。

**対処**: SKILL.md 冒頭に「最小完成例 inline」と「いつ references を読むかの指針」を追加すると `tool_uses` は大幅低下します。

### パターン4: hold-out シナリオで過適合チェック

収束判定のタイミングで、**これまで使っていない hold-out シナリオ 1 本を追加**します。精度が直近平均から 15 ポイント以上落ちたら過適合。baseline シナリオ設計に戻って edge を足します。

「連続2回クリアで収束」だけ見ていると、**シナリオに過適合したSkillを "完成" と誤判定**しがちです。

### パターン5: 既存Skillの定期的「健康診断」

3ヶ月ごとに既存Skillを hold-out シナリオで再評価するルーチンを組みます。モデルバージョン更新（Opus 4.6 → 4.7 等）でSkill挙動が変わることがあり、**気づかないうちに精度が落ちている**ケースを検出できます。

---

## mizchi氏本人のベストプラクティス

SKILL.md原典より、特に重要な4つの原則:

### 推奨1: 質的フィードバックを主、量的を補助とする

> **重み付け**: 質的（不明瞭点・裁量補完）を主、量的（時間・ステップ数）を補助とする。時間短縮だけ追いかけるとプロンプトが痩せすぎる。

### 推奨2: 1イテレーション1テーマ、ただし関連微修正は束ねる

> 1 イテレーション 1 テーマ（関連する複数修正は OK、無関係な修正は次回に回す）。

**落とし穴**: 「関連する微修正も1件ずつ別iterに分けよう」は逆方向の罠。分けすぎると iter 数が爆発します。

### 推奨3: 修正前に「判定文言のどれを満たすか」を明示

> 差分適用前に subagent に「この修正が判定文言のどれを満たすか」を言語化させる。閾値文言レベルで紐付けないと見積もり精度が出ない。

軸名から推測した修正は判定文言に届かない（**ゼロ振れ**）ケースが多発します。

### 推奨4: 同一subagentを再利用しない

> 同じ subagent を使い回そう → 前回の改善を学習している。毎回新規に dispatch する。

毎回新規dispatchするのは、**前回subagentが「暗黙に改善点を覚えている」ため**。再利用すると評価が甘くなります。

---

## やりがちなアンチパターン 8選（Red flags）

SKILL.md原典の Red flags テーブルから8項目、そして別セクション「よくある失敗」から1項目を紹介します。

### 1. 自己再読で済ませる
:::message alert
直前に書いた文章を客観視することは **構造的に不可能**。必ず新規subagentをdispatch。dispatch不能環境（既にsubagentとして動作中、Task tool無効）では「**empirical evaluation skipped**」とユーザーに明示報告し、本Skill適用を諦めること。
:::

### 2. 1シナリオで評価
1シナリオは過適合します。**最低2、できれば3**。中央値1本 + エッジ1-2本。

### 3. 不明瞭点ゼロが1回出たから終了
偶然なこともあります。**連続2回クリアで確定判定**（重要プロンプトは3連続）。

### 4. 複数の不明瞭点を一気に潰す
何が効いたか分からなくなります。1イテレーション1テーマを守る。

### 5. 関連する微修正を1件ずつ別iterに分ける（逆方向の罠）
:::message alert
分けすぎると **iter数が爆発** します。「1テーマ」は意味単位であり、**関連する2-3件の微修正は1 iterにまとめて良い**。無関係な修正のみ次回に回す。
:::

### 6. メトリクスが良いから質的フィードバック無視
時間短縮は **痩せすぎのサイン** にもなります。削りすぎて脆くなった可能性を疑う。

### 7. 書き直した方が早いと判断
**3回以上**不明瞭点が減らないなら正解。それ以前の段階では逃げです。

### 8. 同じsubagentを使い回す
:::message alert
**前回subagentは改善を学習している**ため、再利用すると評価が甘くなります。毎回新規dispatch必須。
:::

### ボーナス: シナリオを修正に合わせて簡単化（「よくある失敗」より）
不明瞭点が潰れたように見せるためにシナリオ側を簡単にする → **本末転倒**。シナリオは baseline で固定し、修正はプロンプト側に入れる。

---

## 収束判定・発散判定の具体値

| 判定 | 条件 | アクション |
|------|------|-----------|
| **収束（停止）** | 連続2回で: 新規不明瞭点0件 + 精度改善 ≤ +3pt + steps変動 ±10%以内 + duration変動 ±15%以内 | hold-outで過適合チェックして完了 |
| **発散（設計見直し）** | 3回以上イテレーションしても新規不明瞭点が減らない | **修正パッチをやめ、構造を書き直す** |
| **リソース打ち切り** | 重要度と改善コストが釣り合わない | 80点で出す判断 |
| **過適合** | hold-out精度が直近平均から -15pt以上 | baseline設計に戻ってedge追加 |

:::message
**過適合チェックは収束判定のタイミングで必ず実施**。これをサボると、「連続2回クリアしたのに実運用で壊れる」現象が起きます。
:::

---

## 関連ツール比較

| ツール | 強み | 弱み | 向いている人 |
|-------|------|------|-------------|
| **empirical-prompt-tuning**（mizchi） | 運用中Skillの継続改善に最適・TDD的 | subagent dispatch必須・コスト高 | Skillを10個以上運用する中級者 |
| **skill-creator**（Anthropic公式） | ゼロから生成、Evalまで一気通貫 | 作者バイアスを排除できない | 新規Skillを大量に作りたい人 |
| **writing-skills**（superpowers） | 静的ルールベース、執筆中に参照可 | 実行結果での計測はしない | Skill設計の作法を学びたい人 |
| **retrospective-codify** | タスク完了後の学びをSkill化 | 新規Skill作成には使わない | 定常タスクを自動化したい人 |
| **prompt-optimizer**（chujianyun） | 単発プロンプトのテキスト最適化 | Skill全体の構造改善はしない | プロンプト単体を磨きたい人 |

**使い分けの指針**: 新規作成は `skill-creator` → 作った直後に `empirical-prompt-tuning` で品質保証 → 運用中も3ヶ月ごとに `empirical-prompt-tuning` で健康診断 → タスク完了時の学びは `retrospective-codify` でSkill化。

---

## 実践チェックリスト

### セットアップ時
- [ ] `SKILL.md` を `~/.claude/skills/empirical-prompt-tuning/` に配置した
- [ ] 対象Skillの description と body の乖離を確認した（Iter 0）
- [ ] シナリオ2-3本と要件チェックリストを事前に固定した
- [ ] `[critical]` タグ付き要件を最低1つ含めた

### 実行時
- [ ] **毎回新規subagentをdispatch**している（再利用していない）
- [ ] 1イテレーション1テーマを守っている
- [ ] 差分適用前に「どの判定文言を満たすか」を subagent に言語化させた
- [ ] 提示フォーマット（Iteration N テーブル）で記録している

### 収束時
- [ ] 連続2回の停止条件を全て満たしているか確認した
- [ ] hold-out シナリオで過適合チェックを実施した
- [ ] 3回以上進まない場合は「書き直し」に切り替えた

---

## まとめ

- **要点1**: `empirical-prompt-tuning` は「**書き手バイアスを排した経験的計測**」で Skill を育てるTDD的方法論
- **要点2**: `skill-creator` とは役割が競合しない（作成 vs 品質保証）
- **要点3**: **質的フィードバック（不明瞭点・裁量補完）を主、メトリクスを補助**として扱う
- **要点4**: `tool_uses` の偏在は「精度100%でも構造欠陥あり」のシグナル
- **要点5**: 収束判定には **hold-out シナリオでの過適合チェック** を必ず含める

Skills運用は「インストール→固定運用」から「**継続チューニング**」へ転換する段階に入りました。10個以上 Skill を運用している人は、今日から1つでも `empirical-prompt-tuning` サイクルを回してみてください。

---

## 参考リンク

- [mizchi/chezmoi-dotfiles — empirical-prompt-tuning SKILL.md](https://github.com/mizchi/chezmoi-dotfiles/blob/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md)
- [元ツイート（@mizchi, 2026-04-19）](https://x.com/mizchi/status/2045501078574350450)
- [Skill Creator — Anthropic公式プラグイン](https://claude.com/plugins/skill-creator)
- [SKILL.md: Treating Prompts as First-Class Artifacts (Towards AI, 2026-04)](https://pub.towardsai.net/skill-md-treating-prompts-as-first-class-artifacts-in-production-llm-systems-b566efbea613)
- [What's New in Claude Code Skills 2.0 — Pere Villega](https://perevillega.com/posts/2026-04-01-claude-code-skills-2-what-changed-what-works-what-to-watch-out-for/)

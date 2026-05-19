---
title: "【2026年5月】AI業界3名の批判発言が同じ週にRedditで同時バズした理由 — Linus・元MS VP・Schmidt完全整理"
emoji: "💥"
type: "tech"
topics: ["AI", "Linux", "Microsoft", "OSS", "セキュリティ"]
published: true
---

## この記事で分かること

2026年5月15〜17日の同じ週に、AI業界を代表する3人のキーパーソンによる「AI推進への不満」が Reddit r/technology で**同時に大バズし、72時間以内に計30,000ups超**を獲得しました（発言時期はそれぞれ異なります — 詳細は後述）。

- **Linus Torvalds**: AIバグハンターが Linux セキュリティMLを「ほぼ管理不能」化（10,974 ups / 5/17発言・5/17-18バズ）
- **元 Microsoft VP Mat Velloso**: 「Microsoftは AI 波もインターネット・モバイル同様に逃した」（10,144 ups / 4/9投稿・5/17 Windows Latest 再注目でバズ）
- **元 Google CEO Eric Schmidt**: アリゾナ大卒業式 AI 発言にブーイング（9,400 ups / 5/15発言・5/17-18バズ）

この記事を読めば、3件を**別々のニュースではなく1つの世論反応潮流**として理解でき、AI を使う側として明日から取るべき行動が見えてきます。

:::message
**対象読者**: AI ツールを業務で使うエンジニア、OSS メンテナ、社内 AI 推進担当者、コンテンツ発信者
:::

## 【混乱整理】3件は別事件ではない — 同じ週に世論が同時反応した俯瞰

日本語メディアでは3件はバラバラの速報として扱われていますが、実は3件とも **2026年5月15-17日の同じ週に発言され、Reddit でも72時間以内に同時バズ**しました。それぞれが「AI 推進派の語り口」に対する反発という共通構造を持っています。

| 事件 | 発言日 | Reddit バズ時期 | 発言者 | 場所/媒体 | 反発の対象 | Reddit反響※ |
|------|--------|---------------|--------|-----------|-----------|-----------|
| AIバグレポート過剰問題 | 2026-05-17 | 5/17-18 | Linus Torvalds | LKML（Linux 7.1-rc4 告知） | AI生成の低品質バグレポート | 10,974 ups |
| Microsoft AI波逃したと | 2026-04-09 | 5/17-18 | Mat Velloso（元MS / 元Meta） | SNS（X）→ 5/17 Windows Latest 再注目 | Win11 Copilot 縮小・3.3%採用率 | 10,144 ups |
| 卒業式AI発言ブーイング | 2026-05-15 | 5/16-18 | Eric Schmidt | アリゾナ大卒業式 | 楽観的 AI 雇用論 | 9,400 ups |

※Reddit upvote 数は 2026-05-18 時点。

### なぜ「同時多発」と呼べるのか

3件の共通点は時期だけではありません。

1. **発言者の立場が異なる**: Torvalds = OSS現場最前線 / Velloso = Microsoft 内部経験者 / Schmidt = AI 推進派の象徴
2. **反発のベクトルが異なる**: 品質問題 / 戦略失敗 / 雇用不安
3. **聴衆の反応が一致**: 全件 Reddit大バズ（計30,000ups超）が**72時間以内に集中** = 多くの人が「自分も同じ違和感を持っていた」と共感
4. **Velloso 発言は4月9日投稿だが**、5月17日の Windows Latest 報道で再注目されてバズに参加 — つまり**蓄積された懐疑が同じ週に火を吹いた**

これは個別ニュースではなく、**「AI 推進バブル」への懐疑が現場・内部・利用者の三方向から同じ週に可視化された転換週**として読み解くべき事象です。

:::message
本記事はこの3件を **ニュース整理 + 共通構造の解説** として扱います。各事件の詳細な一次情報は本文中の引用元を参照してください。
:::

## 前提: なぜ今、AI現場の本音が爆発したのか

2024〜2025年は「AI への期待値」が一方的に高まった時期でした。GPT-4・Claude 3・Gemini 1.5 などモデル性能の急進、エージェント技術の登場、企業の AI 投資ブーム — すべてが「AI が世界を変える」というナラティブを補強しました。

しかし2026年に入ってから、いくつかの **現実とのギャップ** が表面化します。

- **使用品質の格差**: AI を使う側のリテラシー差が顕在化
- **コスト/効果の検証期入り**: 企業の AI 投資 ROI が問われ始める
- **雇用への影響データ**: AI 影響を受ける米国の仕事の実消失データが公表
- **OSS への副作用**: AI 生成コード/レポートが既存エコシステムを圧迫

5月15-17日に発言・バズが集中した3件は、こうした「AI への期待値と現実のギャップ」が **特定の臨界点を超えた瞬間** だったと考えられます。

## 事件1: Linus Torvalds の警告 — AIバグハンターの何が問題か

### 発言の文脈

2026年5月17日、Linus Torvalds は Linux カーネル 7.1-rc4 のリリース告知（LKML 上の週次 state-of-the-kernel post）の中で、AI ツールによる重複バグレポートが Linux セキュリティ メーリングリストを「ほぼ管理不能」にしたと明言しました。

### 原文引用

> "The continued flood of AI reports has basically made the security list **almost entirely unmanageable**, with enormous duplication due to different people finding the same things with the same tools."
>
> — Linus Torvalds, Linux 7.1-rc4 release announcement (2026-05-17)

「AI レポートの連続的な洪水が、同一ツールで同じものを発見する重複によりセキュリティリストをほぼ管理不能にした」という発言です。

### 定量データ: 受信量は5-10倍に膨張

HAProxy 作者・Linux カーネル stable maintainer の **Willy Tarreau** が証言した数字:

| 時期 | セキュリティリスト受信量 |
|------|----------------------|
| 2024年（2年前） | **週2-3件** |
| 2026年5月（現在） | **1日5-10件** |

単純計算で **約15-25倍**。これがメンテナのレビュー時間を圧迫しています。

### Torvalds は AI そのものを否定していない

重要なのは、Torvalds が AI ツール全体を否定していないことです。

> "If you found a bug using AI tools, the chances are somebody else found it too. If you actually want to add value, **read the documentation, create a patch too, and add some real value on top of what the AI did**."
>
> "AI tools are great, but only if they actually help, rather than cause unnecessary pain and pointless make-believe work."

つまり「AI 検出 → 投げっぱなし」ではなく、「**AI 検出 → ドキュメント読解 → パッチ作成 → 価値の上乗せ**」を求めているのです。

### 対照的な動き: Greg Kroah-Hartman の Clanker T1000

同じ Linux カーネル開発の中心人物である **Greg Kroah-Hartman** は、自作の AI バグハンティングシステム「Clanker T1000」で「脆弱性発見 → パッチ作成 → 責任引受 → 公開提出」を実践しており、Torvalds が求める「価値の上乗せ」の手本を示しています。

これは「Torvalds vs AI推進」という単純構図ではなく、「**価値の上乗せがある AI 使用** vs **投げっぱなしの AI 使用**」という質的な対比です。

## 事件2: 元Microsoft VP の自己批判 — Microsoftが逃した3つの波

### 発言者は誰か

**Mat Velloso** は元 Microsoft で Satya Nadella の Technical Advisor を4年務め、その後 Google DeepMind（Gemini API、AI Studio、Gemma 担当 VP）、Meta Superintelligence Labs の Product VP を経て、**2026年4月にMetaを退職**。現在は Revelo の Strategic Advisor を務める人物です。Microsoft 内部から OpenAI / Google DeepMind / Meta への AI 人材移動を体現する経歴と言えます。

### 衝撃の発言

> "Microsoft missed the internet wave, the mobile wave and **now it missed the AI wave**."
>
> — Mat Velloso, X（旧Twitter）投稿（[2026-04-09 12:07 PM](https://x.com/matvelloso/status/2042318623122079943)）

「Microsoftはインターネット波・モバイル波同様、AI 波も逃した」という発言。Win11 Copilot 縮小・Microsoft Build の戦略修正に絡めた投稿でした。**Reddit 大バズは1ヶ月以上経った 5月17日**、[Windows Latest](https://www.windowslatest.com/2026/05/17/former-microsoft-vp-says-microsoft-missed-the-ai-wave-like-the-internet-and-mobile-as-copilot-scales-back-in-windows-11/) が再注目記事として取り上げたことがトリガーです。つまり**4月時点から燻っていた懐疑が、5月17日に火を吹いた**構造です。

### 衝撃の数字: Copilot 採用率 3.3%

Velloso の発言の根拠となる数字:

| 指標 | 数値 |
|------|------|
| M365 ユーザー総数 | **4.5億** |
| 有料 Copilot シート | **1,500万** |
| **採用率** | **3.3%** |
| Microsoft の四半期総 Capex（Q2 FY2026） | **約 $375億**（うち「**roughly two thirds**」がAI関連インフラ） |

Microsoft 自身が 2026-02 に開示したこの「3.3%」という数字が、$375億/四半期の総 Capex（うち約2/3 = 約 $250億がAI関連）という巨額投資と対比されて「採算が取れていない」という見方を強化しました。

### Velloso の指摘: 「価値あるユースケース」がない

> "Less than 3% of paying users actively use Copilot" — Win11 タスクバー・Office 全面に事前展開したにもかかわらず。
>
> OEM が NPU 搭載ノートに投資したが「**not a single valuable usecase was built**」

Microsoft は技術的下地（NPU・Copilot UI・OS 統合）は揃えたが、**ユーザーが日常的に価値を感じるユースケースが構築できていない** というのが Velloso の主張です。

### 構造的問題: OpenAI 直販リスク

Velloso が指摘するもう一つの問題は、**OpenAI が「Forward Deployed Engineers」による DeployCo 事業で企業と直接契約**し始めたこと。これにより Microsoft の Azure OpenAI 経由の「中抜き仲介モデル」が崩壊する危機にあります。

Satya Nadella は別途「Copilot は true daily habit になりつつある」と反論姿勢ですが、3.3% という数字は反論を許しません。

## 事件3: Schmidt ブーイング事件 — 推進派 vs 若者世代

### 発言の文脈

2026年5月15日（金）、元 Google CEO Eric Schmidt がアリゾナ大学の第162回卒業式で AI と雇用について語った瞬間からブーイングが起こり、スピーチ全体を通じて継続。"Please let me finish speaking" と懇願する場面もありました。

### 原文引用（NBC News 経由）

> "There is a fear in your generation that the future has already been written, that the machines are coming, that the jobs are evaporating, that the climate is breaking, that politics is fractured, and that you are inheriting a mess that you did not create."
>
> （要旨: 機械は来る、仕事は消える、気候は悪化する、政治は分裂する、あなた方は自分が作ったわけではない混乱を受け継ぐ — その恐怖は合理的だ）
>
> "The question is not whether AI will shape the world. It will. **The question is whether you will have shaped artificial intelligence**."
>
> — Eric Schmidt, アリゾナ大学第162回卒業式（[2026-05-15 / NBC News](https://www.nbcnews.com/tech/tech-news/former-google-ceo-booed-graduation-speech-ai-rcna345585)）

Schmidt 自身は学生の恐怖を「rational（合理的）」と認めつつ、「あなたたちが AI を形作るのだ」と楽観論で締めるという構成でしたが、学生はこの「楽観的着地」を受け入れませんでした。

### 学生側のデータ

なぜ学生がここまで反発したのか。背景データ:

| 指標 | 数値 |
|------|------|
| 新入生で「AI が将来のキャリアに影響する」と回答 | **42%** |
| AI を理由に既に専攻変更済み | **約10%** |
| Schmidt 招待への反対署名 | **1,200筆以上** |

42% / 10% / 1,200筆 という三つ組数字は、学生側の AI 不安が **抽象的な恐怖ではなく具体的な意思決定行動** になっていることを示しています。

### 反対署名 1,200筆以上の重み

実際には [Tucson.com](https://tucson.com/news/local/education/college/article_ab7ed72c-4efb-4b2c-a46e-7afe81e15949.html) 報道で**卒業式前の水曜時点で1,260+筆**に達しており、卒業式までに更に増えました。Students for Socialism、Women and Gender Resource Center 等の学生団体が組織的に取り組んだ結果です。

### 複合トリガー: AI 単独の反発ではない

ブーイングは「AI 単独」ではなく、複数の不満が積み重なった結果でした。

1. **AI 雇用不安**: 上記データ
2. **Schmidt の性的暴行訴訟**: 2025年11月、元ビジネスパートナー Michelle Ritter が「2021年メキシコ沖ヨット上で強姦」を提訴。2026年3月にLA判事が arbitration（仲裁）送致
3. **名誉博士号への反発**: Students for Socialism、Women and Gender Resource Center 等が招待反対を組織

アリゾナ大学側は Steward Observatory・Lazuli 望遠鏡プロジェクトへの寄付を理由に招待を擁護しましたが、学生の反発を抑えきれませんでした。

### 類似事件: 全米連鎖の兆候

これは単独事件ではありません。**2026-05-08 にはセントラルフロリダ大（UCF）** でも、不動産業の Gloria Caulfield が AI を「次の産業革命」と称してブーイングを受けています（[New York Times 2026-05-14報道](https://www.nytimes.com/2026/05/14/style/ucf-commencement-ai-booed-gloria-caulfield.html)）。「AI 推進派が学生に拒絶される」現象が **全米で連鎖** している兆候です。

## 3件を貫く共通構造 — AI推進バブルの転換点

ここまでの3事件を別々のニュースとして見れば、それぞれ「OSS の運用問題」「企業の戦略失敗」「学生の感情論」と読めます。しかし**同じ週に世論反応（Reddit バズ）が72時間以内に集中**したという事実は、より深い構造を示唆します。

### 共通構造1: 「品質を伴わない AI 利用」への許容度ゼロ化

3件全件で、**「AI を使う/語る側の付加価値の希薄さ」** が拒絶されています。

| 事件 | 拒絶された「付加価値の希薄さ」 |
|------|------------------------|
| Torvalds | 重複・浅い AI レポート = 価値の上乗せがない |
| Velloso | Copilot 採用 3.3% = 価値が伝わっていない |
| Schmidt | 「あなたが AI を形作る」という抽象論 = 学生の具体不安に答えていない |

2024〜2025年は「AI 関連であれば許容された」時期でしたが、2026年は **「AI を使えば/語れば OK」という時代の終わり** を示している可能性があります。

### 共通構造2: 反発が「沈黙」→「可視化」フェーズへ

従来は ML フィルター / 退会 / 退席で済んでいた反応が、Torvalds の公式ポスト、Velloso の SNS 発信、卒業式ブーイングという **可視化形式** に変化しています。

AI への失望は「個人的諦め」から **「集団的シグナリング」** フェーズへ移行したと言えます。

### 共通構造3: 「AI推進派の語り口」と現場の乖離

3事件すべてが「AI 推進エリート」への反発という共通項を持っています。

- **Torvalds**: AI ツールを「投げっぱなしで使う人々」への反発
- **Velloso**: Microsoft 内部の「Copilot を全面展開すれば採用される」という戦略への反発
- **Schmidt**: 「AI は怖いが、あなたが形作れる」という楽観論への反発

これらは技術 vs 反技術の対立ではなく、**「現場感を持たない推進派の語り口」への拒絶** です。

## やりがちな誤解5選

3件のニュースを読んだとき、こう誤解しがちです。

### 1. 「Torvalds は AI を否定している」

:::message alert
原文を読めば、Torvalds は AI ツール **の便利さ** を認めています。問題視しているのは「AI 検出 → 投げっぱなし」という **使い方** であり、AI そのものではありません。Greg Kroah-Hartman の「Clanker T1000」が好例として並列存在することがそれを証明しています。
:::

### 2. 「Microsoft が AI に投資不足だった」

:::message alert
四半期 $375億 を投じている Microsoft は、投資不足ではなく **ユースケース構築の失敗** が問題です。技術下地（NPU・Copilot UI・OS 統合）は揃えたが、ユーザーが日常的に価値を感じる体験設計に到達できていません。
:::

### 3. 「学生は AI への理解が浅いから反発した」

:::message alert
学生の42%が「AI が将来のキャリアに影響する」と答え、10%が AI を理由に専攻変更している事実は、**むしろ理解が深いからこそ反発した** ことを示します。漠然とした感情論ではなく、具体的な進路選択を変えるレベルの危機認識です。
:::

### 4. 「3件は単発の偶然」

:::message alert
発言時期は異なる（Velloso は4月9日、Schmidt は5月15日、Torvalds は5月17日）ものの、**Reddit での世論反応が72時間以内に同時バズした**事実と、共通する「付加価値の希薄さへの拒絶」構造は偶然ではありません。AI 推進バブルへの懐疑が複数チャネルから**同じ週に**噴出した **転換週** として読むべきです。
:::

### 5. 「日本には関係ない海外ニュース」

:::message alert
- Torvalds の警告は、AI でコード生成して OSS に投げる日本のエンジニアにも直接該当
- Microsoft Copilot 3.3% は日本企業の Copilot 導入判断にも影響
- 学生の AI 不安は日本の新卒採用市場でも顕在化しつつある

日本のエンジニア・経営者・学生にとっても無関係ではありません。
:::

## 各事件の数値比較表

3件のインパクトを数値で並べると、共通の規模感が見えてきます。

| 指標 | 事件1: Torvalds | 事件2: Velloso/Microsoft | 事件3: Schmidt |
|------|---------------|----------------------|--------------|
| 発言日 | 2026-05-17 | 2026-04-09（SNS投稿） | 2026-05-15 |
| Reddit バズ時期 | 5/17-18 | 5/17-18（Windows Latest 再注目で） | 5/16-18 |
| Reddit r/tech 反響※ | 10,974 ups / 719 comments | 10,144 ups / 978 comments | 9,400 ups / 341 comments |
| 主要数字 | バグレポート 15-25倍 | Copilot採用率 3.3% | 学生AI不安 42% |
| 反発の対象 | AI使用の質 | AI戦略の質 | AI語り口の質 |
| 含意 | 現場崩壊 | ROI崩壊 | 信頼崩壊 |

※Reddit upvote 数は 2026-05-18 時点。

## 関連事件・前兆ニュース

5月15-17日の3件は突発的ではなく、**それ以前から複数の前兆** がありました。

- **2026-04-09**: Mat Velloso が X に「Microsoft missed the AI wave」投稿（5/17 Windows Latest が再注目）
- **2026-05-08**: セントラルフロリダ大卒業式でも AI 発言にブーイング（Schmidt事件の前哨）
- **2026-05 前半**: GitHub Copilot の信頼性 SLA 90%以下に低下報道
- **2026-04**: MIT データで「AI PoC 95%失敗」レポート（企業のAI ROI懐疑の根拠）
- **2026 通年**: OpenAI が「Forward Deployed Engineers」による直販事業を拡大、Microsoft 中抜きモデル危機

つまり3件は「**蓄積した懐疑が72時間の Reddit バズで一斉に可視化された**」と読むのが妥当です。

## AIを使う側のチェックリスト

3件の共通構造から、AI を使う側として明日から取れる行動を整理します。

### OSS / 個人開発者として

- [ ] AI で発見したバグを Issue/PR で出す前に、ドキュメントを読みパッチ案まで添えているか
- [ ] AI 生成コードを業務で使うとき、レビュー責任を **「人間が」** 引き受ける体制があるか
- [ ] AI ツールで重複した既知バグを報告していないか確認したか
- [ ] OSS メンテナへの「投げっぱなし Issue」を量産していないか

### 社内 AI 推進担当として

- [ ] 「AI ツール導入」を目標にしていないか（手段の目的化）
- [ ] 実際の業務フローで AI が「価値ある日常使用」になっているか定量計測しているか
- [ ] Copilot 3.3% 採用率の現実を踏まえ、自社の真の利用率を測っているか
- [ ] AI 投資の ROI を四半期ごとに数字で検証する仕組みがあるか

### コンテンツ発信者として

- [ ] 「AI で〇〇しました」という発信が、**読者の具体的不安** に答えているか
- [ ] 「AI が世界を変える」という抽象論ではなく、現場感を持って語れているか
- [ ] 自分の発信が「推進エリート」の語り口になっていないか
- [ ] 読者の AI への不安・違和感に **耳を傾ける姿勢** があるか

## まとめ

- **要点1**: 2026年5月15-17日の同じ週に Torvalds・Velloso・Schmidt の AI 推進批判発言が**Reddit で72時間以内に同時バズ**し、計30,000ups超を獲得（Velloso 発言は4月9日投稿だが5月17日の Windows Latest 再注目で参戦）
- **要点2**: 3件は別事件ではなく、「**AI を使う/語る側の付加価値の希薄さ**」への拒絶という共通構造を持つ
- **要点3**: 「Torvalds vs AI」「Velloso vs Microsoft」「学生 vs Schmidt」ではなく、**「現場感のある AI 利用」vs「投げっぱなしの AI 推進」** という質的対立
- **要点4**: 反発が「沈黙」→「可視化」フェーズへ。AI への失望が集団的シグナリングに転じている
- **要点5**: 日本のエンジニア・推進担当・発信者にも該当する構造。チェックリストで明日からの行動を見直すべき

3件のニュースを「速報」として消費するか、**「AI 推進バブル転換週」のシグナルとして整理する** か — 後者の視点でこそ、来月以降の AI ニュースの読み方が変わります。

## 参考リンク

### 事件1: Linus Torvalds

- [The Register: Linus Torvalds says AI-powered bug hunters have made Linux security mailing list almost entirely unmanageable](https://www.theregister.com/security/2026/05/18/linus-torvalds-says-ai-powered-bug-hunters-have-made-linux-security-mailing-list-almost-entirely-unmanageable/5241633)
- [gHacks: AI-Generated Bug Reports Have Made Linux Security Mailing List Unmanageable](https://www.ghacks.net/2026/05/18/linus-torvalds-says-ai-generated-bug-reports-have-made-linux-security-mailing-list-unmanageable/)
- [Tom's Hardware: Flood of duplicate vulnerability reports](https://www.tomshardware.com/software/linux/linus-torvalds-says-ai-bug-reports-have-made-the-linux-security-mailing-list-almost-entirely-unmanageable)
- [Reddit r/technology 元投稿](https://www.reddit.com/r/technology/comments/1tgewe8/linus_torvalds_says_aipowered_bug_hunters_have/)

### 事件2: Mat Velloso / Microsoft

- [Windows Latest: Former Microsoft VP says Microsoft missed the AI wave](https://www.windowslatest.com/2026/05/17/former-microsoft-vp-says-microsoft-missed-the-ai-wave-like-the-internet-and-mobile-as-copilot-scales-back-in-windows-11/)
- [The Register: Microsoft reveals just 3.3% of Copilot Chat users pay for it](https://www.theregister.com/2026/02/02/microsoft_ai_spend_copilot/)
- [Reddit r/technology 元投稿](https://www.reddit.com/r/technology/comments/1tg8uvr/former_microsoft_vp_says_microsoft_missed_the_ai/)

### 事件3: Eric Schmidt / アリゾナ大

- [NBC News: Former Google CEO Eric Schmidt booed during graduation speech about AI](https://www.nbcnews.com/tech/tech-news/former-google-ceo-booed-graduation-speech-ai-rcna345585)
- [The College Investor: Class of 2026 Boos Eric Schmidt at Arizona Graduation](https://thecollegeinvestor.com/80813/eric-schmidt-booed-at-university-of-arizona-graduation-over-ai-and-jobs/)
- [GIGAZINE: アリゾナ大学の学生たちが卒業式でAIの話を始めたエリック・シュミットにブーイング](https://gigazine.net/news/20260518-university-arizona-boo-eric-schmidt-ai/)
- [Reddit r/technology 元投稿](https://www.reddit.com/r/technology/comments/1tgn94p/exgoogle_ceo_eric_schmidt_booed_after_ai_remarks/)

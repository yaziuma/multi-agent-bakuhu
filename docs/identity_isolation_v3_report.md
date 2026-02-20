# Identity分離 v3 経緯・実装・検証 正式報告書

> 作成日: 2026-02-20
> 作成者: 足軽2号（ashigaru2, pane %3）、cmd_311 Part2
> レビュー対象: 殿（Lord）
> ステータス: **完了**（動的検証まで実施済み）

---

## 目次

1. [事象 — 何が起きたか](#1-事象)
2. [原因分析 — なぜ起きたか](#2-原因分析)
3. [対応策 — 何をしたか](#3-対応策)
4. [確認内容 — 何を検証したか](#4-確認内容)
5. [結果 — 最終状態](#5-結果)
6. [残存リスクと今後の課題](#6-残存リスクと今後の課題)

---

## 1. 事象

### 1.1 発覚日時と症状

2026-02-20、殿の命令により全エージェントの「名乗り」検証（cmd_302）を実施したところ、深刻なIdentity汚染バグが発覚した。

**検証コマンド**: 各エージェントに `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` を実行させ、自分の役職名と pane ID の一致を確認させた。

**名乗り結果（cmd_302時点）**:

| pane | 本来のロール | 自称ロール | 判定 |
|------|------------|----------|------|
| %0   | shogun（将軍） | karo（家老） | ❌ 誤認 |
| %1   | karo（家老）   | karo（家老） | ✅ 正常 |
| %2   | ashigaru（足軽） | karo（家老） | ❌ 誤認 |
| %3   | ashigaru（足軽） | karo（家老） | ❌ 誤認 |
| %4   | ashigaru（足軽） | shogun（将軍） | ❌ 誤認 |
| %5   | denrei（伝令）  | denrei2（伝令2） | ✅ 正常 |

> **注記**: pane %6（denrei2）は cmd_302 実施時点では存在しなかった。Identity分離v3実装（cmd_305）においてpane %6（伝令2号）が追加されたため、本テーブルはv3実装前のpane構成（%0〜%5の6pane）を反映している。

**症状のまとめ**: 6エージェント中4エージェントが誤ったロールを自称。うち3エージェントが「家老（karo）」、1エージェントが「将軍（shogun）」を自称しており、指揮系統が根底から崩壊していた。

### 1.2 発覚の経緯

殿が cmd_302 として「全エージェントに名乗らせよ」と命令。各エージェントが自分の識別子（@agent_id）と役割を報告した結果、上記の誤認が明らかになった。なお、pane1（karo本人）とpane5（denrei2）の2エージェントのみが正常に自認していた。

### 1.3 バグの深刻性

このバグが放置された状態では：
- 足軽が自分を「家老」と思い込み、家老の権限で行動する
- 将軍が「家老」と思い込み、殿に直接報告しないなどの異常行動が起きる
- 役職別の禁止行動（コード実装禁止、ソースコード閲覧禁止等）が機能しない
- マルチエージェント指揮系統が完全に崩壊する

---

## 2. 原因分析

### 2.1 汚染源の特定

バグの根本原因は **「共有persistent storage（MEMORY.md、Memory MCP graph）に identity 情報が格納されており、全エージェントが同じ情報を参照してしまう」** 構造的欠陥であった。

具体的な汚染源は3つ確認された：

#### 汚染源1: MEMORY.md の role: karo 記載

MEMORY.md（全エージェントのセッション開始時に自動注入されるファイル）に、以下のような identity 情報が書き込まれていた：

```
role: karo
```

全エージェントは session start 手順で MEMORY.md を読み込む。このファイルに `role: karo` と書かれていたため、将軍・足軽を含む全エージェントが「自分はkaroである」と認識してしまった。

#### 汚染源2: Memory MCP graph の shogun_role エンティティ

Memory MCP graph（永続的な知識グラフ、全セッション共有）に `shogun_role` というエンティティが存在し、「自分はshogunである」という identity 情報が格納されていた。pane4（本来は足軽）がこのエンティティを読み込み、「将軍」を自称した。

#### 汚染源3: CLAUDE.md Session Start Step1 の @agent_id WRITE

CLAUDE.md の Session Start 手順（全エージェント共通）において、Step1 が以下のように記述されていた：

```
# 旧来の誤った記述
tmux set-option -p -t "$TMUX_PANE" @agent_id {role_name}
```

これは identity を「WRITE（書き込む）」手順だった。MEMORY.md や Memory graph の誤った role 情報を読み込んだエージェントが、その誤認ロールで `@agent_id` を上書き設定してしまい、誤認が固定化された。

### 2.2 根本原因

```
根本原因:
共有 persistent storage（MEMORY.md、Memory MCP graph）に identity 情報を格納していた。
これらは全エージェント・全セッションで共有されるため、
1人のエージェントが誤った identity 情報を書き込むと
他の全エージェントに汚染が伝播する。
```

この構造では、セッション再起動のたびに汚染が繰り返す「自己増殖するバグ」となっていた。

---

## 3. 対応策

### 3.1 設計書の策定経緯

バグ発覚直後に殿の命令により対策設計を開始。以下の順序で設計書を策定・改訂した：

```
v1設計書（cmd_303発令前）
    ↓ 軍師（Codex）レビュー（cmd_303）— 15件の指摘
v2設計書（軍師7件採用、8件却下・殿裁定済み）
    ↓ 忍び（Gemini）レビュー（cmd_304）— 7件の指摘
v3設計書（忍び7件全採用）← 最終版
    ↓ 実装（cmd_305）
```

#### v1 → v2 の変更（軍師レビュー採用7件）

軍師（Codex, gpt-5.3-codex）は15件の問題を指摘。殿裁定により以下7件を採用：

| 軍師# | Severity | 内容 | v2での対応 |
|-------|---------|------|-----------|
| #1 | Critical | pane_role_map.yaml の整合性保護が不十分 | sha256sum 記録・読み取り時検証・改ざん検出でexit 2 |
| #3 | Critical | tmux外でhookがallow（fail-open）になる可能性 | fail-closed原則を明文化。tmux外/メタデータ失敗でexit 2 |
| #4 | High | TOCTOU競合（map生成と読み取りの競合） | atomic書き込み（tmp→mv）、flockによるロック |
| #5 | High | パス正規化未実施 | write-guard全般でrealpath正規化を追加 |
| #7 | High | 足軽→将軍inboxの直接書き込みガード未実装 | ashigaru-write-guard.sh で queue/inbox/shogun.yaml をブロック |
| #9 | Medium | hook実行順序の明文化不足 | settings.json の配列順で制御、文書化 |
| #10 | Medium | デバッグ支援不足 | Policy-as-Data（YAML管理）、共有ライブラリ、構造化ログ |

却下された8件（#2,#6,#8,#11〜#15）は後述「残存リスク」セクションを参照。

#### v2 → v3 の変更（忍びレビュー全7件採用）

忍び（Gemini）は7件の問題を指摘。全7件を採用：

| 忍び# | 内容 | v3での対応 |
|-------|------|-----------|
| #1 Trust Anchor不一致 | @agent_idとpane_role_map.yamlで判定根拠が異なる | `get_role()`関数でpane_role_map.yaml一本化。@agent_idは補助cross-checkのみ |
| #2 hook_common.sh保護不備 | 共有ライブラリが改ざん可能 | shutsujin_departure.sh で chmod 444 設定 + hook_common.sh.sha256 生成。ロード時に整合性検証 |
| #3 epoch比較対象未定義 | pane_role_map.yamlのepochを何と比較するか不明 | config/session.epoch を独立ファイルとして書き出し。Hookが両者の一致を verify_epoch() で検証 |
| #4 無関係hookの非効率 | 全hookが全paneで実行されるため無駄が多い | check_role_match() 関数を共通化。非担当ロールのpaneでは即exit 0 |
| #5 Policy YAMLスキーマ未定義 | ポリシーYAMLの構造が保証されない | policy_schema.json 定義。セルフテストにスキーマ検証ステップ追加 |
| #6 セルフテスト失敗時の復旧手順なし | 異常時の対処が不明確 | フォールバック戦略を明文化: git自動ロールバック → 失敗時安全停止 |
| #7 shogun-guard.sh役割曖昧 | 将軍ガードが将軍専用か全ロール共通か不明 | shogun-guard/write-guard をshogunロール専用に再定義。全ロール共通のglobal-guard.sh を新設 |

### 3.2 実装内容の全体像

cmd_305 として Identity分離v3 を実装。新規作成・修正ファイルは合計30ファイルに及ぶ。

#### 主要ファイル一覧

**コアスクリプト（新規）**:

| ファイル | 役割 |
|---------|------|
| `scripts/lib/hook_common.sh` | 全hook共有ライブラリ。ロール解決・パス正規化・ログ・整合性検証の共通関数 |
| `scripts/get_pane_id.sh` | 現在のtmux pane ID（%N形式）を返す汎用スクリプト |
| `scripts/get_agent_role.sh` | pane_role_map.yaml参照でロール名を取得 |
| `scripts/selftest_hooks.sh` | 全hookの存在・権限・整合性を自動検証するセルフテストスクリプト |

**役職別Hookスクリプト（新規）**:

| ファイル | 役割 |
|---------|------|
| `.claude/hooks/karo-guard.sh` | 家老の実行コマンド制限（python/pytest/npm等の実装コマンド禁止） |
| `.claude/hooks/karo-write-guard.sh` | 家老の書き込み制限（ソースコード禁止・メモリ保護） |
| `.claude/hooks/ashigaru-guard.sh` | 足軽の実行制限（将軍inbox直接連絡禁止） |
| `.claude/hooks/ashigaru-write-guard.sh` | 足軽の書き込み制限（システム設定・instructions禁止・メモリ保護） |
| `.claude/hooks/denrei-guard.sh` | 伝令の実行制限（実装コマンド禁止・Gemini/Codex許可） |
| `.claude/hooks/denrei-write-guard.sh` | 伝令の書き込み制限（ソースコード禁止・デフォルトブロック） |
| `.claude/hooks/shogun-guard.sh` | 将軍の実行制限（v3でshogunロール専用に再定義） |
| `.claude/hooks/shogun-write-guard.sh` | 将軍の書き込み制限（v3でshogunロール専用に再定義） |
| `.claude/hooks/global-guard.sh` | 全ロール共通のガード（v3新規。旧将軍ガードの汎用機能を移管） |

> **注記（v3範囲外の既存hook）**: `gitignore-guardian-bash.sh` と `gitignore-guardian-write.sh` もsettings.local.jsonに登録されているが、これらはIdentity分離v3以前から存在する既存hookであり、.gitignore保護を目的とする。v3の設計・実装範囲外。

**ポリシーYAML（新規）**:

| ファイル | 内容 |
|---------|------|
| `.claude/hooks/policies/shogun_policy.yaml` | 将軍ロールのポリシー定義（21 rules） |
| `.claude/hooks/policies/karo_policy.yaml` | 家老ロールのポリシー定義（14 rules） |
| `.claude/hooks/policies/ashigaru_policy.yaml` | 足軽ロールのポリシー定義（7 rules） |
| `.claude/hooks/policies/denrei_policy.yaml` | 伝令ロールのポリシー定義（15 rules） |
| `.claude/hooks/policies/global_policy.yaml` | 全ロール共通ポリシー定義（10 rules） |
| `.claude/hooks/policies/policy_schema.json` | ポリシーYAMLのJSON Schemaスキーマ定義 |

**設定・マップ（新規/修正）**:

| ファイル | 役割 |
|---------|------|
| `config/pane_role_map.yaml` | セッション起動時に自動生成。pane ID（%N）→ロール名の対応表 |
| `config/pane_role_map.yaml.sha256` | pane_role_map.yamlの改ざん検出用ハッシュ |
| `config/session.epoch` | セッション固有のエポック番号（改ざんリプレイ検出用） |
| `.claude/settings.local.json` | PreToolUse hookの登録設定（修正） |

**メモリファイル（新規）**:

| ファイル | 役割 |
|---------|------|
| `memory/shogun.md` | 将軍専用メモリファイル |
| `memory/karo.md` | 家老専用メモリファイル |
| `memory/ashigaru.md` | 足軽専用メモリファイル |
| `memory/denrei.md` | 伝令専用メモリファイル |

**修正ファイル**:

| ファイル | 修正内容 |
|---------|---------|
| `MEMORY.md` | identity情報を削除。ロール→メモリファイルパスのルックアップテーブルのみに縮小。identity書き込み禁止を明文化 |
| `CLAUDE.md` | Session Start Step1を「@agent_id WRITEからREAD FIRST」に変更。identity汚染バグの根本原因を除去 |
| `shutsujin_departure.sh` | pane_role_map.yaml自動生成・sha256記録・session.epoch書き出し・hook_common.sh chmod 444 設定を追加 |

### 3.3 主要設計判断とその理由

#### ① pane_role_map.yaml による pane ID → role 解決

**判断**: identity の唯一の根拠を「tmux pane ID → pane_role_map.yaml 参照」に統一した。

**理由**: pane ID はセッション内でユニークかつ不変。shutsujin_departure.sh（起動スクリプト）がセッション起動時に自動生成するため、ヒューマンエラーが入り込まない。`@agent_id`（tmux変数）は補助的な cross-check にのみ使用し、権限判定の根拠にしない（Trust Anchor 統一）。

#### ② hook_common.sh の共有ライブラリ化と chmod 444 保護

**判断**: 全hook共通の処理（ロール解決・パス正規化・ログ出力・整合性検証）を `hook_common.sh` に集約。セッション起動時に `chmod 444`（全ユーザー読み取り専用）に設定し、sha256ハッシュで改ざん検出。

**理由**: 各hookに同じ処理を散在させると「ポリシードリフト（スクリプト間の不整合）」が生じる。共有ライブラリ化により一貫性を確保。444権限は事故による改ざんを防止する（攻撃前提の完全保護ではなく、運用上の安全確保）。

#### ③ session.epoch によるセッション整合性保証

**判断**: セッション起動時のエポック番号（UNIXタイムスタンプ）を pane_role_map.yaml と config/session.epoch の両方に記録。各hookはロード時に両者の一致を検証し、不一致の場合は exit 2（deny）。

**理由**: 旧セッションの pane_role_map.yaml が残存していた場合の誤動作を防止。「現在のセッションで生成された正しいマップを使っているか」を機械的に検証できる。

#### ④ MEMORY.md のルックアップテーブル化

**判断**: MEMORY.md から identity 情報を完全削除。ロール名→メモリファイルパスの対応表（ルックアップテーブル）のみを残した。identity 情報の書き込みを禁止として明文化。

**理由**: MEMORY.md は全エージェント・全セッションで共有される。ここに identity を書くと汚染が全体に伝播する（今回のバグの直接原因）。

#### ⑤ 役職別メモリファイル分離

**判断**: shogun.md・karo.md・ashigaru.md・denrei.md を独立ファイルとして作成。各ロールは自分のファイルのみ読み書き可能。他ロールのメモリファイルへの書き込みはhookがブロック。

**理由**: メモリファイルを分離することで、誤ったロールのエージェントが他ロールのメモリを汚染することを防止。hookによるアクセス制御と組み合わせることで多層防御を実現。

#### ⑥ fail-open 設計の理由（奉行チーム互換性）と設計書v3との矛盾経緯

**判断**: tmux 環境外（IDE統合、Cursor等）での実行時、役職別hookは `exit 0`（allow/スキップ）を返す。これはあえて fail-open（許可方向）に設計した。

**理由**: `bugyo`（奉行）・`ashigaru`（Task tool経由）・`goikenban`（御意見番）等のAgent Team（`.claude/agents/`）はtmux外で動作する。これらのエージェントに不要な制限をかけないよう、tmux外はガードをスキップする設計とした。tmux前提の本番運用環境（現在）では問題ない。

**設計書v3との矛盾と経緯（cmd_309動的検証で発覚）**:
- 設計書v3はセクション1およびセクション7に「tmux環境外では役職特化hookは全てexit 2（deny）」というfail-closed原則を明記していた
- しかしcmd_305実装時、`check_role_match()` がtmux外で `exit 0`（スキップ）を返す実装になっていた
- cmd_309動的検証のPart Bでこの乖離が検出された（FAIL判定: exit 0 = fail-open）
- 殿の裁定: 「奉行チームはtmux外で動作するため、exit 2にすると奉行チームが全滅する。ならば0でよい」→ fail-open維持に方針変更
- **注意**: 設計書v3はfail-closedを明記したままであり、実装との乖離が残存する。設計書の改訂は今後の課題（詳細はセクション6.1参照）

---

## 4. 確認内容

### 4.1 cmd_306: 全員名乗り検証

**実施日**: 2026-02-20
**内容**: システム全体の7エージェント（将軍・家老・足軽1〜3・伝令1〜2）のうち、将軍（pane %0）を除く6エージェントが各自の @agent_id を読み取り、pane_role_map.yaml のエントリと一致するかを確認。（将軍は本cmd_306に直接参加せず）

**結果**: 参加した6エージェントが全員、正しい役職名を名乗り、pane_role_map.yaml との一致率 **100%**。Identity分離v3 実装後のバグ解消を確認。

### 4.2 cmd_307: 静的検証 15 項目（全PASS）

**実施日**: 2026-02-20 16:29〜16:32
**検証者**: 足軽1号（項目1〜8）+ 足軽2号（項目9〜15）
**取りまとめ**: 足軽3号

**結果一覧**:

| # | 検証項目 | 判定 | エビデンス概要 |
|---|---------|------|-------------|
| 1 | 役職別メモリファイル分離 | **PASS** | shogun.md(201B)/karo.md(2063B)/ashigaru.md(142B)/denrei.md(140B) 全ファイル存在 |
| 2 | MEMORY.mdクリーン確認 | **PASS** | ルックアップテーブルのみ。identity情報ゼロ |
| 3 | get_pane_id.sh動作 | **PASS** | `%2` を正しいpane ID形式で返却 |
| 4 | get_agent_role.sh動作 | **PASS** | `ashigaru` を正しく返却 |
| 5 | pane_role_map.yaml構造 | **PASS** | epoch(1771569661)/generated(2026-02-20 15:41:01)/panes(%0〜%6)全フィールド存在 |
| 6 | SHA256整合性チェック | **PASS** | `sha256sum -c pane_role_map.yaml.sha256` → OK |
| 7 | session.epoch一致 | **PASS** | session.epoch = pane_role_map epoch = 1771569661（完全一致）|
| 8 | hook_common.sh存在・権限 | **PASS** | 7405bytes、パーミッション444（read-only）確認 |
| 9 | 役職別guardフック6本 | **PASS** | karo/ashigaru/denrei各guard+write-guard、全ファイル実行権限付き |
| 10 | global-guard.sh | **PASS** | 3708bytes、実行権限付き |
| 11 | shogunフック2本 | **PASS** | shogun-guard.sh(3024B)/shogun-write-guard.sh(1309B) 実行権限付き |
| 12 | ポリシーYAML | **PASS** | 5役職YAML + policy_schema.json。role/version/rulesフィールド全確認 |
| 13 | settings.local.json登録 | **PASS** | PreToolUse(Bash): 5hook登録 / PreToolUse(Write\|Edit): 4hook登録 |
| 14 | selftest_hooks.sh実行 | **PASS** | Test1〜7全通過、エラー0・警告0 |
| 15 | shutsujin_departure.sh | **PASS** | pane_role_map/session.epoch/sha256 の3キーワード全確認 |

**総合判定: 全15項目 PASS**

### 4.3 cmd_308: 軍師（Codex）による静的検証報告書レビュー

**実施日**: 2026-02-20
**レビュアー**: 軍師（Codex, gpt-5.3-codex）
**指摘件数**: 9件（C1 / H4 / M3 / L1）

**指摘一覧**:

| # | Severity | 内容 | 殿裁定 |
|---|---------|------|-------|
| 1 | **Critical** | 検証の中心が「存在確認」で、実効的な防御検証になっていない | **前提違い**（cmd_309動的検証で対処） |
| 2 | High | pane_role_map.yaml + sha256 同置き方式を「改ざん耐性」と断定するのは過大評価 | **前提違い**（設計上の限界として認識済み。信頼アンカーは運用上確保） |
| 3 | High | hook_common.sh の chmod 444 を改ざん防止とみなすのは不十分 | **前提違い**（事故防止として有効。攻撃者がroot権限を得た場合は別問題） |
| 4 | High | エッジケース検証不足（pane再生成・再利用・セッション再起動） | **前提違い**（pane再利用は設計上排除済み。shutsujin_departure.sh起動のみのため） |
| 5 | High | hookチェーンの実行順序・競合・fail-closed連鎖の実証不足 | **cmd_309 Part A で実施** |
| 6 | Medium | tmux外実行時 fail-closed の明示検証不足 | **cmd_309 Part B で実施** |
| 7 | Medium | パス正規化（realpath）のバイパステスト不足 | **cmd_309 Part C で実施** |
| 8 | Medium | get_agent_role.sh の検証が単一pane・単一結果のみ | **前提違い**（cmd_306全員名乗りで全pane確認済み） |
| 9 | Low | エビデンスの再現性が弱い | **cmd_309 Part D要件として対処**（全エビデンスにコマンド全文・出力・終了コード・pane ID を必須化） |

**採用**: #5, #6, #7, #9 の4件 → cmd_309 で動的検証実施
**却下（前提違い）**: #2, #3, #4, #8 の4件
**対処方針明示**: #1（「存在確認中心」の指摘に対してcmd_309動的検証として対処。分類上は「前提違い」としたが実質採用）

### 4.4 cmd_309: 動的機能検証（11PASS / 1FAIL）

**実施日**: 2026-02-20 17:42〜17:50
**検証者**: 足軽1号(Part A/B/E/F) + 足軽2号(Part C/E) + 家老(Part E/F) + 伝令1・2号(Part E) + 足軽3号(Part E/報告書)

**検証結果**:

| Part | 検証項目 | 担当 | 判定 |
|------|---------|------|------|
| A | Hookチェーン実行順序 | 足軽1号 | **PASS** |
| B | tmux外fail-closed | 足軽1号 | **FAIL** |
| C-1 | realpathバイパス: symlink | 足軽2号 | **PASS** |
| C-2 | realpathバイパス: ../パス | 足軽2号 | **PASS** |
| C-3 | realpathバイパス: 相対パス | 足軽2号 | **PASS** |
| C-4 | realpathバイパス: 存在しないパス | 足軽2号 | **PASS（注）** |
| C-5 | 正当書き込み対照実験 | 足軽2号 | **PASS** |
| E | メモリ書き込み: karo.md（家老） | 家老 | **PASS** |
| E | メモリ書き込み: ashigaru.md（足軽1/2/3） | 足軽1/2/3号 | **PASS** |
| E | メモリ書き込み: denrei.md（伝令1/2） | 伝令1/2号 | **PASS** |
| F | 他ロール拒否: 足軽→karo.md | 足軽1号 | **PASS** |
| F | 他ロール拒否: 家老→ashigaru.md | 家老 | **PASS** |

**Part A（hookチェーン）詳細**:
- PreToolUse(Bash)登録順: shogun-guard.sh → karo-guard.sh → ashigaru-guard.sh → denrei-guard.sh → global-guard.sh → gitignore-guardian-bash.sh（v3範囲外の既存hook）
- PreToolUse(Write|Edit)登録順: shogun-write-guard.sh → karo-write-guard.sh → ashigaru-write-guard.sh → denrei-write-guard.sh → gitignore-guardian-write.sh（v3範囲外の既存hook）
- 正常なコマンドに対して全hookが exit 0（allow）を返すことを確認

**Part B（tmux外）詳細 — FAIL（= 殿裁定による意図的設計）**:
- `env -u TMUX_PANE -u TMUX bash hook.sh` でtmux環境変数を除去して実行
- 全hookが exit 0（スキップ = fail-open）を返した
- **原因**: `check_role_match()` 内でtmux外を検出した場合 `exit 0`（スキップ）を返す設計
- **これは殿裁定による意図的な設計**（奉行チーム互換のため）。経緯・設計書v3との矛盾・殿裁定の詳細はセクション6.1参照

**Part C（realpathバイパス）詳細**:

> **測定方法の注意**: `printf '...' | bash hook.sh` パイプライン形式では、Claude Code Bash ツール固有の挙動により終了コードが常に0となる。`bash hook.sh <<< '...'`（herestring形式）を使用すると正確な終了コードが取得できる。

| テスト | 手法 | hook出力 | exit | 判定 |
|--------|------|---------|------|------|
| C-1: symlink | `/tmp/symlink → karo.md` | `rule=ASHIGARU_WRITE_DENY_OTHER_MEMORY` / `足軽は他役職のメモリファイルを編集できません。` | 2 | PASS |
| C-2: ../パス | `memory/../memory/karo.md` | 同上、realpathで解決 | 2 | PASS |
| C-3: 相対パス | `../../.../karo.md` | 同上、realpathで解決 | 2 | PASS |
| C-4: 存在しないパス | `nonexistent_role.md` | （なし） | 0 | PASS with note |
| C-5: 正当書き込み | `ashigaru.md` | （なし） | 0 | PASS |

C-4は `nonexistent_role.md` の basename が保護対象リスト（shogun.md/karo.md/denrei.md）に含まれないため allow となる。これは設計通りの動作（足軽の主務はソースコード編集であり、基本許可）。

**Part E（メモリ書き込み）詳細**:

全6エージェントが自ロールのメモリファイルに書き込み成功。hookによるブロックなし：

| エージェント | ファイル | 結果 |
|------------|---------|------|
| 家老（karo, %1） | karo.md | 書き込み成功 |
| 足軽1号（ashigaru1, %2） | ashigaru.md | 書き込み成功 |
| 足軽2号（ashigaru2, %3） | ashigaru.md | 書き込み成功 |
| 足軽3号（ashigaru3, %4） | ashigaru.md | 書き込み成功 |
| 伝令1号（denrei1, %5） | denrei.md | 書き込み成功 |
| 伝令2号（denrei2, %6） | denrei.md | 書き込み成功 |

**Part F（クロスロール拒否）詳細**:

| 試行者 | 対象ファイル | hookルール | 判定 |
|--------|------------|-----------|------|
| 足軽1号（%2） | karo.md | `ASHIGARU_WRITE_DENY_OTHER_MEMORY` / exit 2 | PASS |
| 家老（%1） | ashigaru.md | `KARO_WRITE_DENY_OTHER_MEMORY` / exit 2 | PASS |

---

## 5. 結果

### 5.1 最終状態

**静的検証**: 15項目 全PASS
**動的検証**: 11項目PASS / 1項目FAIL（Part B: tmux外fail-open — 殿裁定により意図的設計。詳細はセクション6.1参照）

### 5.2 解消されたもの

- **Identity汚染バグの完全解消**: cmd_306で全6エージェントが正しいロールを名乗ることを確認
- **メモリ分離の実現**: 各ロールが自ロールのメモリファイルのみ読み書き可能。クロスロール書き込みはhookでブロック
- **MEMORY.md のクリーン化**: identity情報ゼロ。ルックアップテーブルのみ
- **Trust Anchor 統一**: 全hookが `pane_role_map.yaml` を唯一の権限判定根拠として使用
- **改ざん検出基盤**: pane_role_map.yaml（sha256）、hook_common.sh（sha256・444権限）、session.epoch（セッション整合性）の三重防御

### 5.3 検証で確認された堅牢性

- **symlink・../・相対パスによるバイパス攻撃を全て検出・ブロック**（Part C 全PASS）
- **クロスロール書き込みを確実にブロック**（Part F PASS）
- **hookチェーンが設計通りの順序で動作**（Part A PASS）
- **セルフテストが全項目クリア**（selftest_hooks.sh エラー0・警告0）

---

## 6. 残存リスクと今後の課題

### 6.1 既知のリスク

#### tmux外 fail-open（意図的設計 — 設計書v3との矛盾と殿裁定の経緯）

- **現象**: tmux環境変数（$TMUX, $TMUX_PANE）が未設定の場合、役職別hookは `exit 0`（スキップ）を返す
- **影響範囲**: tmux外のClaude Code実行環境（IDEプラグイン、Cursor、VSCode統合等）でIdentity分離が無効化される
- **経緯**: 設計書v3はfail-closed（tmux外でexit 2）を原則として明記していた。しかしcmd_305実装時に `check_role_match()` がtmux外でexit 0を返す実装になり、cmd_309 Part Bの動的検証でこの乖離が発覚（FAIL判定）。殿に報告したところ「奉行チームはtmux外で動作するため、exit 2にすると奉行チームが全滅する。ならば0でよい」と裁定。fail-open維持に方針変更となった
- **設計書との矛盾**: 設計書v3は引き続きfail-closedを記述しており、実装との乖離が残存。設計書の改訂は今後の課題（セクション6.3参照）
- **現在の判断**: 本システムはtmux前提で設計されており、現在の運用（tmux内）では問題なし
- **将来の対応**: IDE統合（Cursor/VSCode連携）を本格導入する際には、global-guard.sh または check_role_match() にtmux必須チェックを追加することを検討。その際に設計書の改訂も合わせて実施

#### pane_role_map.yaml + sha256 同置き方式の限界

- **指摘**: 同一権限ドメインでmap本体とhashの両方が更新可能なため、両方を書き換えることで整合性チェックを通過できる
- **現在の判断**: 本システムの脅威モデルは「エージェント間の誤動作防止」であり、root権限を持つ外部攻撃者を対象としていない。同一オーナーによる意図的な改ざんは別の問題（ログイン認証等で対処）
- **現状の効果**: 事故による改ざんや、セッション間でのファイル混在を検出するには十分な仕組みである

#### hook_common.sh chmod 444 の限界

- **指摘**: 同一オーナー/同一実行主体なら `chmod 644` → 改変 → `chmod 444` の操作が可能
- **現在の判断**: 上記と同様、意図的な攻撃ではなく「うっかり改ざん」を防ぐための仕組みとして有効。sha256検証との組み合わせで事故検出も可能

### 6.2 却下済み指摘（軍師レビュー）

以下の指摘は設計上の前提の違いにより採用しなかった：

| 軍師# | 内容 | 却下理由 |
|-------|------|---------|
| #2 | Pane ID再利用対策 | shutsujin_departure.shの1起動で全paneを同時生成するため、再利用は構造的に発生しない |
| #6 | コマンドブロックリスト脆弱性 | 対応不要と殿裁定 |
| #8 | Hook chain SPOF | 対応不要と殿裁定 |
| #11 | パフォーマンス影響 | 測定・対応不要と殿裁定 |
| #12 | メモリ分離多孔性 | 対応不要と殿裁定 |
| #13 | 帯域外操作の抜け穴 | 対応不要と殿裁定 |
| #14 | pane動的追加/削除 | shutsujin_departure.sh再起動で全pane再生成するため非該当 |
| #15 | tmux外の明示的ポリシー | fail-open設計として意図的（奉行チーム互換性） |

### 6.3 今後の改善候補

1. **tmux外ポリシーの明確化**: IDE統合を検討する際、tmux外での Identity 分離をどう扱うか設計を再検討する
2. **信頼アンカーの強化**: pane_role_map.yaml のハッシュをセッション外の別ファイルシステムやread-only記憶域に保存することで、改ざん耐性を高めることができる
3. **全pane横断のロール一致検証自動化**: selftest_hooks.sh を拡張し、全paneの @agent_id と pane_role_map.yaml の一致を機械的に検証するステップを追加することが望ましい

---

## 付録: アーキテクチャ概要図

```
セッション起動（shutsujin_departure.sh）
    ↓
[STEP 5.2] pane_role_map.yaml 生成
    - %0:shogun, %1:karo, %2:ashigaru, %3:ashigaru, %4:ashigaru, %5:denrei, %6:denrei
    - sha256sum → pane_role_map.yaml.sha256
    - epoch → config/session.epoch
    - chmod 444 hook_common.sh
    - sha256sum hook_common.sh → hook_common.sh.sha256
    ↓
[各エージェント Session Start]
    Step1: tmux display-message → @agent_id を READ（WRITEしない）
    Step2: Memory MCP graph READ
    Step3: instructions/{role}.md READ
    ↓
[Claude Code ツール実行時 (PreToolUse)]
    hook_common.sh:
        verify_hook_common_integrity() → sha256自己検証
        verify_epoch() → session.epoch一致確認
        get_role() → pane ID → pane_role_map.yaml → role解決
        check_role_match("役職") → 担当外ならexit 0
    役職別guard（Bash):
        karo-guard.sh / ashigaru-guard.sh / denrei-guard.sh / shogun-guard.sh
    役職別write-guard（Write|Edit）:
        karo-write-guard.sh / ashigaru-write-guard.sh / denrei-write-guard.sh / shogun-write-guard.sh
    global-guard.sh（全ロール共通）
    ↓ exit 0: 許可 / exit 2: 拒否

[メモリアクセス]
    各ロールは自ロールのメモリファイルのみ読み書き可:
        shogun → memory/shogun.md のみ
        karo   → memory/karo.md のみ
        ashigaru → memory/ashigaru.md のみ
        denrei → memory/denrei.md のみ
    他ロールのファイルへの書き込みはwrite-guardがexit 2でブロック

[MEMORY.md]（全エージェントに自動注入）
    内容: ロール→メモリファイルパスのルックアップテーブルのみ
    identity情報: ゼロ（書き込み禁止）
```

---

*本報告書は足軽2号（ashigaru2, pane %3）が cmd_311 Part2 として作成。*
*参照資料: design_identity_isolation_v1/v2/v3.md, cmd_307_identity_v3_verification.md, cmd_309_dynamic_verification.md, report_cmd_308_verification_review.md, Memory MCP entity: identity_contamination_bug_20260220*

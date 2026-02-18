# Context Usage Reporting Rules

All agents must follow these rules when reporting context usage.

## Measurement

- Context % MUST come from `/context` command output or `scripts/check_context.sh` (when available)
- Guessing, estimating, or "feeling" is FORBIDDEN
- If neither method is available, report "未測定" (not measured) — never fabricate a number

## Reporting Format

Always include both percentage AND token count:

```
57% (114k/200k tokens)
```

Never write just "57%" without token numbers.

## Thresholds and Actions

| Usage | Status | Required Action |
|-------|--------|-----------------|
| 0-60% | Healthy | Continue normal work |
| 60-75% | Warning | /compact after current task |
| 75-85% | Danger | /compact immediately |
| 85%+ | Critical | /clear immediately |

## Dashboard Header

The dashboard header `家老コンテキスト` field must use the exact format:

```
> **家老コンテキスト**: 🟡 57% (114k/200k tokens、注意域)
```

Status indicators:
- 🟢 0-60% (healthy)
- 🟡 60-75% (warning)
- 🔴 75-85% (danger)
- ⚫ 85%+ (critical)

## Mandatory Check Timing（運用ルール — 殿の厳命）

### コンテキスト測定の原則（殿の厳命）

**エージェントは自身のコンテキストを正確に測れない。測定は必ず上位者が外部から行う。**

| 測定対象 | 測定者 | 方法 |
|---------|--------|------|
| 家老 | 将軍 | `check_context.sh karo` / tmux capture-pane右下表示 |
| 足軽 | 家老 | `check_context.sh ashigaru{N}` / tmux capture-pane右下表示 |

- **自己申告・自己測定は禁止**（不正確なため）
- 測定結果に基づき、上位者が/compact or /clearを指示する
- ダッシュボードのコンテキスト欄は、将軍の測定結果を家老が転記する

### 将軍（Shogun）の確認タイミング（家老の測定義務）

| タイミング | 確認方法 | 必須アクション |
|------------|---------|---------------|
| ダッシュボード確認時 | `check_context.sh karo` 実行 | 結果を家老に伝達 |
| 家老pane確認時 | 右下の残量表示チェック | 🟡以上で家老に/compact指示 |
| cmd発令前 | 家老の残量を確認 | 60%超なら先に/compact指示 |

### 家老（Karo）の確認タイミング（足軽の測定義務）

| タイミング | 確認方法 | 必須アクション |
|------------|---------|---------------|
| タスク完了報告受信時 | `check_context.sh ashigaru{N}` | 閾値超えなら/clear送信 |
| 長時間タスク中(30分+) | tmux capture-pane右下表示 | 閾値超えなら対応判断 |
| 次タスク割当前 | 残量を確認 | 60%超なら先に/clear |

## Strict Thresholds（厳格化された閾値）

| Usage | Status | Required Action | 猶予 |
|-------|--------|-----------------|------|
| 0-50% | 🟢 Healthy | 通常作業 | — |
| 50-60% | 🟢 Healthy | 通常、ただし意識 | — |
| 60-70% | 🟡 Warning | 現タスク完了後に/compact | タスク1件分 |
| 70-80% | 🔴 Danger | /compact即時実行（タスク中断してでも） | 猶予なし |
| 80%+ | ⚫ Critical | まず/compact実行。効果なしなら/clear | 猶予なし |

## /compact Execution Rules

- 60%到達で現タスク後すぐ/compact
- /compact後に再確認、改善なければ/clear
- compact_count 3回到達で次回は/clear（compact効果低下のため）
- /compact後ダッシュボードのコンテキスト欄を即更新（実測値で）
- **80%+でもまず/compact**: 80%超えでもいきなり/clearせず、まず/compactを実行
- /compact後に上位者が再測定し、改善なければ/clearを指示
- /clearは最終手段であり、compactで改善の余地がある限り使わない

## Prohibited Actions（禁止事項 — 違反は殿の逆鱗）

| 禁止事項 | 理由 |
|---------|------|
| 80%超え放置 | 殿の逆鱗。即/clear |
| 「まだ大丈夫」という主観判断 | 数値で判断せよ。感覚は信用するな |
| コンテキスト未確認で次タスク着手 | 確認は義務。省略不可 |
| ダッシュボードのコンテキスト欄を「fresh」のまま放置 | 実測値で更新。未測定なら「未測定」と書け |
| いきなり/clear実行 | /clearは最終手段。まず/compactを試みよ |

## Accountability（説明責任）

- 家老が80%超えで/clearになった場合、原因をダッシュボードに記載すること
- 将軍の見逃しも将軍の怠慢として記録すること
- **このルールは殿の厳命。いかなるタスクの緊急度よりも優先される**

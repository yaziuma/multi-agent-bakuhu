---
audience: worker
---

# 足軽ワークフロー補足ステップ（bakuhu固有）

<!-- bakuhu-specific: 足軽ワークフローのbakuhu固有ステップ詳細 -->

## step 3.5: set_current_task（タスクラベル設定）【全エージェント共通】

タスク開始時にpaneのタスクラベルを設定せよ。

```bash
tmux set-option -p @current_task "{task_id_short}"
# task_id_short: e.g., "subtask_150a" → "150a"（最大~15文字）
```

**注記**: 軍師（gunshi.md step 3.5 L57-60）も同じパターン。全エージェント共通の規約。
ペインのボーダーに `ashigaru2 (Sonnet) 150a` のように表示される。

## step 6.5: clear_current_task（タスクラベルクリア）【全エージェント共通】

タスク完了後にpaneのタスクラベルをクリアせよ。

```bash
tmux set-option -p @current_task ""
```

**注記**: 軍師（gunshi.md step 6.5 L70-73）も同じパターン。全エージェント共通の規約。
ボーダーが `ashigaru2 (Sonnet)` に戻り、idle状態であることが視認できる。

## step 7: inbox_write to gunshi（bakuhu固有 — QCフロー変更）

**bakuhu override**: 上流（upstream）では家老（karo）へ直接報告するが、
bakuhu では**軍師（gunshi）経由でQCを行うフローに変更**されている。

```bash
bash scripts/inbox_write.sh gunshi \
  "足軽{N}号、任務完了でござる。品質チェックを仰ぎたし。" \
  report_received ashigaru{N}
```

**フロー**: 足軽 → 軍師（QC）→ 家老（OK/NG判断）

inbox設定（ashigaru.md YAML frontmatter）:
```yaml
inbox:
  to_gunshi_allowed: true
  to_gunshi_on_completion: true
  mandatory_after_completion: true
```

## step 7.5: check_inbox（タスク完了後のinbox確認 — 必須）

タスク完了後、idle状態になる前に必ずinboxを確認せよ。

```yaml
step: 7.5
action: check_inbox
target: "queue/inbox/ashigaru{N}.yaml"
mandatory: true
note: "Check for unread messages BEFORE going idle. Process any redo instructions."
```

**なぜ必須か**: この確認をスキップすると、redo指示が待機中でもidle状態になり、
エスカレーション（~4分後の /clear）まで作業が止まる。

## step 8: echo_shout（DISPLAY_MODE=shoutの戦国風バトルクライ）

タスク完了後、`DISPLAY_MODE` を確認して戦国風のバトルクライを出力せよ。

```bash
# STEP 1: 環境変数確認
tmux show-environment -t multiagent DISPLAY_MODE
```

**DISPLAY_MODE=shout の場合**:
- 最後のツール呼び出しとして Bash echo を実行
- `echo_message` フィールドがtask YAMLにある → そのテキストを使用
- `echo_message` フィールドがない → 1行の戦国風バトルクライを自作

```bash
# echo_message あり:
echo "タスクYAMLのecho_messageの内容"

# echo_message なし（自作例）:
echo "🗡️ 任務完了！コードの剣を鞘に収め申した！"
```

**ルール**:
- echo の後に**テキストを出力するな**（echoが ❯ の真上に表示されること）
- 箱/罫線なし。絵文字+プレーンテキスト
- 戦国風。足軽らしい口調で

**DISPLAY_MODE=silent または未設定の場合**: このステップをスキップせよ。

## 足軽の自律判断ルール

家老の指示を待たずに自律行動すべき場面:

**タスク完了時**（この順序で実行）:
1. 成果物の自己レビュー（出力を再読）
2. **目的検証**: parent_cmd の stated purpose と照合。乖離があれば報告の `purpose_gap:` に記載
3. 報告YAMLの作成
4. 軍師へ inbox_write で通知（step 7）
5. inbox確認（step 7.5）

## 参照

- 足軽ワークフロー全体: `instructions/ashigaru.md`
- 軍師QCフロー: `instructions/gunshi.md`
- ペイン解決: `skills/pane-resolution.md`

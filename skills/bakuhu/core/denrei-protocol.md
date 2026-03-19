---
audience: all
---

# 伝令（Denrei）プロトコル

<!-- bakuhu-specific: 伝令は bakuhu 固有の外部連絡エージェント -->

伝令は外部連絡専門エージェントである。忍び・客将への連絡を代行し、家老がブロックされないようにする。

## 伝令の役割

| 役割 | 説明 |
|------|------|
| 外部連絡代行 | 忍び・客将への召喚を代行 |
| 応答待機 | 外部エージェントの応答を待機 |
| 結果報告 | 結果を報告YAMLに記入し、家老を起こす |

## いつ伝令を使うか

| 場面 | 理由 |
|------|------|
| 忍び召喚（長時間調査） | 家老がブロックされるのを防ぐ |
| 客将召喚（戦略分析） | 家老がブロックされるのを防ぐ |
| 複数召喚の並列実行 | 伝令2名で同時召喚可能 |

## 伝令への指示手順（4ステップ）

```
STEP 1: タスクYAMLを書き込む
  queue/denrei/tasks/denrei{N}.yaml に依頼内容を記入

STEP 2: send-keys で伝令を起こす（2回に分ける + 動的解決）
  DENREI_PANE=$(grep ': denrei1' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')
  【1回目】
  tmux send-keys -t "$DENREI_PANE" 'queue/denrei/tasks/denrei1.yaml に任務がある。確認して実行せよ。'
  【2回目】
  tmux send-keys -t "$DENREI_PANE" Enter

STEP 3: 伝令が外部エージェントを召喚し、応答を待機
  伝令が gemini / codex "プロンプト" 2>/dev/null を実行し、結果を待つ

STEP 4: 伝令が報告
  queue/denrei/reports/denrei{N}_report.yaml に結果を記入
  send-keys で家老を起こす
```

## 伝令のペイン番号解決

| 伝令 | ペイン解決方法 |
|------|--------------|
| 伝令1 | `grep ': denrei1' config/pane_role_map.yaml` |
| 伝令2 | `grep ': denrei2' config/pane_role_map.yaml` |

ペイン番号は `config/pane_role_map.yaml` から動的に解決する。絶対値ハードコード禁止。

## 関連ファイル

- `queue/denrei/tasks/denrei{N}.yaml` — 伝令タスク
- `queue/denrei/reports/denrei{N}_report.yaml` — 伝令報告
- `instructions/denrei.md` — 伝令自身の指示書

## ファイルパス定義

伝令・忍び・客将に関するファイルパス（CLAUDE.md frontmatter より）:

```yaml
denrei_tasks:    "queue/denrei/tasks/denrei{N}.yaml"      # 伝令タスク
denrei_reports:  "queue/denrei/reports/denrei{N}_report.yaml"  # 伝令報告
shinobi_reports: "queue/shinobi/reports/"                  # 忍び（Gemini）調査報告
kyakusho_reports: "queue/kyakusho/reports/"                # 客将（Codex）戦略報告
```

## Legacy tmux send-keys プロトコル（伝令/忍び向け）

**適用範囲**: 伝令・忍び連携専用。通常のエージェント間通信は inbox_write.sh を使え。

### 2回分離送信ルール（必須）

send-keys は必ず **2回の独立したBash呼び出し** に分離せよ:

```bash
# Bash呼び出し 1: メッセージ送信
tmux send-keys -t multiagent:0.{PANE} 'メッセージ内容'

# Bash呼び出し 2: Enter送信（別の呼び出し）
tmux send-keys -t multiagent:0.{PANE} Enter
```

1回の呼び出しでメッセージとEnterを送ることは禁止。
（paneの状態によってEnterが欠落するリスクがある）

### ポーリング禁止

send-keysを使ったポーリングループは **APIコスト観点から絶対禁止**。

```
❌ 禁止: cmd dispatch → sleep 30 → capture-pane → check → sleep 30 → ...
✅ 正しいパターン: cmd dispatch → inbox_write → stop (await response)
```

### エスカレーション（nudgeが処理されない場合）

| 経過時間 | アクション | トリガー |
|---------|-----------|---------|
| 0〜2 min | 標準 pty nudge | 通常配信 |
| 2〜4 min | Escape×2 + nudge | カーソル位置バグ回避 |
| 4 min+ | `/clear` 送信（5分に1回まで） | 強制セッションリセット + YAML再読 |

### 報告フロー（割り込み防止）

| 方向 | 方法 | 制約 |
|------|------|------|
| 足軽 → 家老 | 報告YAML + inbox_write | — |
| 家老 → 将軍/殿 | dashboard.md更新のみ | **将軍へのinbox送信は禁止** |
| 上位 → 下位 | YAML + inbox_write | — |

**将軍へのinbox送信が禁止の理由**: 殿の入力を妨げないため。

## 参照

- 客将召喚プロトコル: `skills/kyakusho-protocol.md`
- 忍び管理（家老視点）: `skills/external-agent-rules.md`
- ペイン解決手順: `skills/pane-resolution.md`

# ペイン番号解決手順

<!-- bakuhu-specific: pane_role_map.yaml を使ったペイン番号の動的解決 -->

## 原則

**ペイン番号は絶対値ハードコード禁止。** `config/pane_role_map.yaml` から動的に解決せよ。

`shutsujin_departure.sh` が起動時に `pane_role_map.yaml` を正しく設定している。

## 標準解決コマンド

```bash
# 家老のペイン番号を解決
KARO_PANE=$(grep ': karo' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')

# 足軽Nのペイン番号を解決
ASHIGARU_PANE=$(grep ': ashigaru{N}' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')

# 軍師のペイン番号を解決
GUNSHI_PANE=$(grep ': gunshi' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')

# 伝令Nのペイン番号を解決
DENREI_PANE=$(grep ': denrei{N}' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')
```

## 自分のIDを確認する方法

```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```

この値が自分のidentity。MEMORY.md・Memory MCPグラフ・会話履歴よりも **@agent_id が最優先**。

## ズレが発生した場合の逆引き（家老専用）

通常、ペイン番号 = 足軽番号（shutsujin_departure.sh が起動時に保証）。長時間運用でズレが生じた場合:

```bash
# 足軽{N}の実際のペイン番号を @agent_id から逆引き
ACTUAL_PANE=$(tmux list-panes -t multiagent:agents -F '#{pane_index}' -f '#{==:#{@agent_id},ashigaru{N}}')
tmux send-keys -t "multiagent:agents.${ACTUAL_PANE}" 'メッセージ'
tmux send-keys -t "multiagent:agents.${ACTUAL_PANE}" Enter
```

## 逆引きするタイミング

| 状況 | 判断 |
|------|------|
| 通常時 | 不要。pane_role_map.yaml の値でそのまま送れ |
| 到達確認で2回失敗した場合 | ペイン番号ズレを疑い、逆引きで確認せよ |
| shutsujin_departure.sh 再実行後 | ペイン番号は正しくリセットされる |

## Bloom Level → エージェント解決テーブル

| Bloom Level | 割当エージェント | ペイン解決 |
|-------------|--------------|---------|
| L1-L3 | 足軽1-4（Sonnet） | `grep ': ashigaru{1-4}' config/pane_role_map.yaml` |
| L4-L5（auto） | 軍師 → 足軽 | `grep ': gunshi' config/pane_role_map.yaml` |
| L6（auto） | 軍師 | `grep ': gunshi' config/pane_role_map.yaml` |
| 高難度（OC基準2つ以上） | 足軽5-8（Opus） | `grep ': ashigaru{5-8}' config/pane_role_map.yaml` |

## 参照

- Bloom routing設定: `skills/bloom-routing.md`
- 伝令ペイン解決: `skills/denrei-protocol.md`

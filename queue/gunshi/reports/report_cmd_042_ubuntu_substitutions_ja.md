# 目的: LLMが読む量を減らすための「機能・アプリ代替」一覧

## 目的の再定義
- **LLMが全文を読むコストを下げる**ため、Ubuntu標準機能/一般ツールで
  「必要部分だけ抽出して渡す」運用に置き換える。
- **ツールの置換ではなく、読み取り量の削減が目的**。

---

## 1) YAML系（タスク/報告）: 必須フィールドだけ抽出

### 対象
- `queue/tasks/ashigaru{N}.yaml`
- `queue/reports/ashigaru{N}_report.yaml`
- `queue/denrei/tasks/denrei{N}.yaml`
- `queue/denrei/reports/denrei{N}_report.yaml`

### 代替案（Ubuntu標準）
- **awk/sed/grep で必要行のみ抽出**
- **yq があれば構造抽出**（標準ではないが一般的）

### 例（標準コマンドのみ）
```bash
# task_id, priority, description, project, target_path, status だけ抜く
awk '
  /^task_id:|^  task_id:/ ||
  /^  priority:/ ||
  /^  description:/ ||
  /^  project:/ ||
  /^  target_path:/ ||
  /^  status:/ {print}
' queue/tasks/ashigaru3.yaml
```

### 例（yq利用時）
```bash
yq '.task | {task_id,priority,description,project,target_path,status}' \
  queue/tasks/ashigaru3.yaml
```

**効果**: LLMへ渡す内容を「必要キーだけ」に限定できる。

---

## 2) Markdown系: 必要セクションだけ抽出

### 対象
- `context/{project}.md`
- `dashboard.md`
- `CLAUDE.md`
- `instructions/*.md`

### 代替案（Ubuntu標準）
- **awkで特定見出しセクションのみ抽出**
- **rg（ripgrep）で見出し位置を特定し、sedで範囲切り出し**

### 例（awk, 見出し単位抽出）
```bash
# "## Current State" セクションだけ抽出
awk '
  /^## Current State/ {flag=1; print; next}
  /^## / {if(flag) exit}
  flag {print}
' context/my_project.md
```

### 例（dashboard.mdの「戦果」だけ）
```bash
awk '
  /^## 戦果/ {flag=1; print; next}
  /^## / {if(flag) exit}
  flag {print}
' dashboard.md
```

**効果**: LLMが読むのは「必要なセクション」だけ。

---

## 3) 最新のみ読む: 最新ファイル抽出

### 対象
- `queue/reports/`
- `queue/shinobi/reports/`
- `queue/gunshi/reports/`

### 代替案（Ubuntu標準）
```bash
# 最新レポート1件だけ
ls -t queue/reports/*_report.yaml | head -1 | xargs cat
```

**効果**: 過去履歴を読まずに最新だけ渡せる。

---

## 4) ルール/禁止事項の“薄い抜粋”だけ読む

### 対象
- `instructions/*.md`

### 代替案
- 禁止事項の一覧だけ抽出してLLMへ渡す

```bash
# 禁止事項テーブルだけ抽出（見出し単位）
awk '
  /^## 🚨 絶対禁止事項/ {flag=1; print; next}
  /^## / {if(flag) exit}
  flag {print}
' instructions/ashigaru.md
```

**効果**: 毎回全文を読まず「必須ルールだけ」渡せる。

---

## 5) YAML/Markdownの“最小化ビュー”をスクリプト化

### 目的
- 「毎回同じ抽出」を手動でやらず、**固定コマンドで必要部分だけ取得**

### 例
```bash
# task最小ビュー
scripts/view_task_min.sh ashigaru3

# report最小ビュー
scripts/view_report_min.sh ashigaru3

# contextのCurrent Stateだけ
scripts/view_context_state.sh my_project
```

**効果**: LLMに渡す“定型の最小情報”を安定化できる。

---

## 6) 直接のファイル読込を減らす「メタ情報抽出」

### 対象
- `queue/reports/*.yaml` や `dashboard.md`

### 代替案
- **grepでtask_idだけ抽出**して状況把握
```bash
rg -n "task_id:" queue/reports/ashigaru*_report.yaml
```

**効果**: フルレポートを読まずに「何が完了したか」を把握。

---

## 結論
- **「全文を読む」代わりに「必要部分を抽出して渡す」**ことが最も効果的。
- Ubuntu標準の `awk/sed/grep/ls/head` だけで十分に実現可能。
- これらを**固定スクリプト化**すれば、LLM入力コストを安定的に削減できる。


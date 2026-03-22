---
audience: all
---

# 絶対パスハードコード検出・修正スキル

GitHubで公開するリポジトリに `/home/username` 等の個人パスをハードコードしてはならない。
本スキルは検出・修正の標準手順を定める。

---

## 1. 検出コマンド

### 単一プロジェクトの全数スキャン

```bash
grep -rn '/home/' \
  --include="*.sh" --include="*.py" --include="*.yaml" \
  --include="*.toml" --include="*.json" --include="*.md" \
  --include="*.example" --include="*.sample" \
  --exclude-dir=.git --exclude-dir=.venv --exclude-dir=node_modules \
  /path/to/project/
```

### config/ ディレクトリのみ確認

```bash
grep -rn '/home/' /path/to/project/config/
```

### git追跡ファイルのみ確認（推奨）

```bash
git -C /path/to/project ls-files | xargs grep -n '/home/' 2>/dev/null
```

---

## 2. 検出対象ファイル種別

| 種別 | 対象パターン | 優先度 |
|------|------------|--------|
| シェルスクリプト | `*.sh` | 最高 |
| Pythonスクリプト | `*.py` | 最高 |
| 設定ファイル | `*.yaml`, `*.toml`, `*.json` | 高 |
| サンプル設定 | `*.example`, `*.sample` | 高（必ず修正） |
| ドキュメント | `*.md` | 中 |
| config/ 配下 | `config/*` | 高 |

**除外対象**（git管理外のローカル設定）:
- `git ls-files` で未追跡のファイル → 修正不要
- `.gitignore` 対象ファイル → 修正不要

---

## 3. 修正パターン表

### シェルスクリプト (.sh)

```bash
# 修正前
PROJECT_DIR="/home/username/projects/myapp"

# 修正後（スクリプト位置から動的解決）
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# またはサブディレクトリのスクリプト用
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
```

### Pythonスクリプト (.py)

```python
# 修正前
from pathlib import Path
project_root = Path("/home/username/projects/myapp")

# 修正後（__file__から動的解決）
from pathlib import Path
project_root = Path(__file__).parent.parent  # スクリプトの位置に応じて調整

# 環境変数フォールバック付き
import os
project_root = Path(os.environ.get("MY_PROJECT_ROOT", str(Path(__file__).parent.parent)))
```

```python
# 修正前（sys.path）
sys.path.insert(0, "/home/username/projects/myapp")

# 修正後
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
```

### 設定ファイル (.yaml / .toml / .json)

```yaml
# 修正前
base_path: /home/username/projects/bakuhu

# 修正後（環境変数方式）
base_path: ${BAKUHU_ROOT}
```

Pythonコードで読み込む場合は `os.path.expandvars()` を使用:
```python
import os
import yaml
with open("config/settings.yaml") as f:
    config = yaml.safe_load(f)
base_path = os.path.expandvars(config["base_path"])
```

### ドキュメント (.md)

```markdown
<!-- 修正前 -->
bash /home/username/projects/myapp/scripts/start.sh

<!-- 修正後（プレースホルダー） -->
bash <your-projects-dir>/myapp/scripts/start.sh
# または
bash scripts/start.sh  # プロジェクトルートから実行
```

### サンプル設定 (.example / .sample)

```yaml
# 修正前（settings.yaml.example）
base_path: /home/username/projects/myapp

# 修正後（必ずプレースホルダーに）
base_path: /path/to/your/myapp
# または
base_path: ${MY_APP_ROOT}
```

---

## 4. git管理対象の確認

修正前に必ずgit追跡対象か確認する:

```bash
# ファイルがgit管理下か確認
git -C /path/to/project ls-files path/to/file.yaml

# 出力あり → git管理対象 → 修正必要
# 出力なし → git管理外 → 修正不要（ローカル設定）
```

---

## 5. 構文チェック

修正後は必ず構文チェックを実施する:

```bash
# シェルスクリプト
bash -n modified_script.sh

# Pythonスクリプト
python3 -c "import ast; ast.parse(open('modified_script.py').read())"
# または
uv run python -c "import ast; ast.parse(open('modified_script.py').read())"

# YAML
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

---

## 6. 複数プロジェクトの一括調査手順

```bash
# 調査対象プロジェクトを配列で指定
PROJECTS=(
  /path/to/projects/shogun-web-v2
  /path/to/projects/shogun-web
  /path/to/projects/ai-news-anchor
  /path/to/projects/queue-viewer
  /path/to/projects/prolog_mcp
)

for proj in "${PROJECTS[@]}"; do
  echo "=== $(basename $proj) ==="
  # git管理ファイルのみ確認
  git -C "$proj" ls-files \
    '*.sh' '*.py' '*.yaml' '*.toml' '*.json' '*.md' '*.example' '*.sample' \
    2>/dev/null | \
    xargs -I{} grep -n '/home/' "$proj/{}" 2>/dev/null || true
done
```

---

## 7. 報告書フォーマット

調査・修正完了後に以下のフォーマットで報告:

```yaml
task_id: subtask_XXX
title: "絶対パスハードコード調査・修正"
fix_summary:
  total_found: N
  fixed: N
  skipped_git_untracked: N
hardcodes_found_and_fixed:
  - file: "project/path/to/file.sh:5"
    before: 'PROJECT_DIR="/home/username/..."'
    after: 'PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"'
    method: "スクリプト位置から動的解決"
hardcodes_skipped:
  - file: "project/config/local.yaml"
    reason: "git管理外（git ls-files で未追跡確認済み）"
syntax_checks:
  - "file.sh: bash -n OK"
  - "file.py: ast.parse OK"
```

---

## 8. 環境変数設定ガイド（運用者向け）

`${BAKUHU_ROOT}` 等の環境変数を使用する場合、運用者は以下を設定する:

```bash
# ~/.bashrc または ~/.zshrc に追加
export BAKUHU_ROOT="/home/yourname/projects/multi-agent-bakuhu"
export PROLOG_MCP_ROOT="/home/yourname/projects/prolog_mcp"
```

または `.env` ファイルを使用（.gitignore対象にすること）:
```bash
# project/.env（git管理外）
BAKUHU_ROOT=/home/yourname/projects/multi-agent-bakuhu
```

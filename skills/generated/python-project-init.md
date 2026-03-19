---
name: python-project-init
description: 新規Pythonプロジェクトの初期化。uv + ruff + mypy + pytest の構成で、型安全で保守性の高いプロジェクト雛形を作成する。プロジェクト開始時に使用。
---

# Python Project Init - プロジェクト初期化スキル

## Overview

uvを使ったモダンなPythonプロジェクトの雛形を作成する。
型安全性（mypy strict）、コード品質（ruff）、テスト（pytest）を標準装備。

## When to Use

- 新規Pythonプロジェクトを開始する時
- "新しいPythonプロジェクトを作って" などの指示を受けた時
- プロトタイプやツールを作成する時

## Project Structure

```
project-name/
├── src/
│   ├── __init__.py
│   └── project_name/
│       └── __init__.py
├── tests/
│   └── __init__.py
├── config/
│   └── settings.yaml (optional)
├── pyproject.toml
├── CLAUDE.md
├── README.md
└── .gitignore
```

## Instructions

### Step 1: プロジェクト初期化

```bash
# プロジェクトディレクトリ作成
mkdir project-name
cd project-name

# uv プロジェクト初期化
uv init --lib
```

### Step 2: pyproject.toml 作成

```toml
[project]
name = "project-name"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
requires-python = ">=3.11"
dependencies = [
    # プロジェクト固有の依存関係をここに追加
]

[dependency-groups]
dev = [
    "mypy>=1.19.1",
    "pytest>=9.0.2",
    "pytest-asyncio>=1.3.0",  # 非同期テストが必要な場合
    "ruff>=0.9.0",
]

[tool.mypy]
strict = true
warn_return_any = true
warn_unused_configs = true
# pydantic使用時は以下を追加:
# plugins = ["pydantic.mypy"]

[tool.pydantic-mypy]
init_forbid_extra = true
init_typed = true
warn_required_dynamic_aliases = true

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = [
    "E",   # pycodestyle errors
    "F",   # pyflakes
    "I",   # isort
    "N",   # pep8-naming
    "UP",  # pyupgrade
    "B",   # flake8-bugbear
    "C4",  # flake8-comprehensions
]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
asyncio_default_fixture_loop_scope = "function"
```

### Step 3: ディレクトリ構造作成

```bash
# ディレクトリ作成
mkdir -p src/project_name tests config

# __init__.py 作成
touch src/__init__.py
touch src/project_name/__init__.py
touch tests/__init__.py
```

### Step 4: CLAUDE.md 作成

```markdown
# project-name

## Overview
{プロジェクトの説明}

## Development

### Setup
\`\`\`bash
uv sync
\`\`\`

### Run Tests
\`\`\`bash
uv run pytest
\`\`\`

### Type Check
\`\`\`bash
uv run mypy src/
\`\`\`

### Lint
\`\`\`bash
uv run ruff check .
uv run ruff format .
\`\`\`

## Project Structure
- src/project_name/ - メインソースコード
- tests/ - テストコード
- config/ - 設定ファイル
```

### Step 5: README.md 作成

```markdown
# project-name

{プロジェクトの説明}

## Installation

\`\`\`bash
uv sync
\`\`\`

## Usage

{使用方法}

## Development

\`\`\`bash
# Run tests
uv run pytest

# Type check
uv run mypy src/

# Lint
uv run ruff check .
\`\`\`
```

### Step 6: .gitignore 作成

```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
.venv/
venv/
ENV/

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# Testing
.pytest_cache/
.coverage
htmlcov/

# Type checking
.mypy_cache/
.dmypy.json
dmypy.json

# Ruff
.ruff_cache/

# OS
.DS_Store
Thumbs.db
```

### Step 7: 依存関係インストール

```bash
# dev依存関係をインストール
uv sync --dev

# 追加パッケージのインストール例
uv add pydantic           # バリデーション
uv add pydantic-settings  # 設定管理
uv add pyyaml             # YAML読み込み
uv add click              # CLIツール
```

## Common Use Cases

### CLI ツールの場合

```toml
[project.scripts]
project-name = "project_name.cli:main"
```

```python
# src/project_name/cli.py
import click

@click.command()
@click.option('--name', default='World', help='Name to greet.')
def main(name: str) -> None:
    """Simple CLI tool."""
    click.echo(f'Hello {name}!')

if __name__ == '__main__':
    main()
```

### Webアプリケーションの場合

```bash
# FastAPI の場合
uv add fastapi uvicorn

# Flask の場合
uv add flask
```

### データ処理の場合

```bash
uv add pandas numpy scipy matplotlib
```

## Guidelines

### 命名規則
- **プロジェクト名**: ハイフン区切り（kebab-case）例: `my-project`
- **Pythonパッケージ名**: アンダースコア区切り（snake_case）例: `my_project`
- **モジュール/ファイル名**: snake_case
- **クラス名**: PascalCase
- **関数/変数名**: snake_case

### 推奨事項
1. **型ヒント必須**: 全ての関数に型ヒントを付ける
2. **docstring推奨**: public関数にはdocstringを書く
3. **テスト重視**: 実装と同時にテストを書く
4. **mypy strict**: 型安全性を最優先
5. **ruff auto-fix**: コードフォーマットは自動化

### 避けるべきこと
- グローバル変数の乱用
- type: ignore の多用（型を正しく設計する）
- テストの省略
- README の放置（最新の情報を維持）

## Examples

### 最小構成の例

```bash
# プロジェクト作成
mkdir hello-world && cd hello-world
uv init --lib

# pyproject.toml 編集（上記テンプレート使用）

# ディレクトリ作成
mkdir -p src/hello_world tests
echo "def greet(name: str) -> str:\n    return f'Hello {name}!'" > src/hello_world/__init__.py
echo "from hello_world import greet\n\ndef test_greet():\n    assert greet('World') == 'Hello World!'" > tests/test_hello.py

# テスト実行
uv sync --dev
uv run pytest
uv run mypy src/
```

## Quick Start Command

全手順を1コマンドで実行する例：

```bash
PROJECT_NAME="my-project"
PACKAGE_NAME="my_project"

mkdir $PROJECT_NAME && cd $PROJECT_NAME
uv init --lib
mkdir -p src/$PACKAGE_NAME tests config
touch src/__init__.py src/$PACKAGE_NAME/__init__.py tests/__init__.py
# pyproject.toml, CLAUDE.md, README.md, .gitignore を作成
uv sync --dev
```

## Notes

- **uv**: Rust製の高速パッケージマネージャー。pip/pipenvの代替
- **ruff**: Rust製の高速linter/formatter。flake8/black/isortの統合代替
- **mypy strict**: 最も厳格な型チェック。品質重視プロジェクトに推奨
- **pytest**: デファクトスタンダードのテストフレームワーク

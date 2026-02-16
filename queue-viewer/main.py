import os
from pathlib import Path
from typing import Any

import markdown
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import YamlLexer, get_lexer_by_name

from routers.kb import router as kb_router

# 環境変数からベースパス取得（将来のnginxリバースプロキシ対応）
BASE_PATH = os.getenv("BASE_PATH", "")

app = FastAPI(title="Queue Viewer", root_path=BASE_PATH)

# Include knowledge base API router
app.include_router(kb_router)

# プロジェクトルートとqueue/のパス
PROJECT_ROOT = Path("/home/quieter/projects/multi-agent-bakuhu").resolve()
QUEUE_DIR = (PROJECT_ROOT / "queue").resolve()
DASHBOARD_PATH = (PROJECT_ROOT / "dashboard.md").resolve()

# テンプレートとstatic
templates = Jinja2Templates(directory="templates")
app.mount("/static", StaticFiles(directory="static"), name="static")


def is_safe_path(requested_path: Path) -> bool:
    """
    パストラバーサル対策：queue/配下またはdashboard.mdのみ許可
    """
    resolved = requested_path.resolve()

    # queue/配下のパスか？
    if str(resolved).startswith(str(QUEUE_DIR)):
        return True

    # dashboard.mdか？
    if resolved == DASHBOARD_PATH:
        return True

    return False


def get_tree_structure(base_path: Path, prefix: str = "") -> list[dict[str, Any]]:
    """
    ディレクトリツリーを再帰的に構築
    """
    items = []
    if not base_path.is_dir():
        return items

    try:
        entries = sorted(base_path.iterdir(), key=lambda p: (not p.is_dir(), p.name))
    except PermissionError:
        return items

    for i, entry in enumerate(entries):
        is_last = i == len(entries) - 1
        current_prefix = "└── " if is_last else "├── "
        next_prefix = prefix + ("    " if is_last else "│   ")

        rel_path = entry.relative_to(PROJECT_ROOT)
        item = {
            "name": entry.name,
            "path": str(rel_path),
            "is_dir": entry.is_dir(),
            "prefix": prefix + current_prefix,
        }

        if entry.is_dir():
            item["children"] = get_tree_structure(entry, next_prefix)

        items.append(item)

    return items


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """
    トップページ：queue/配下のツリー表示
    """
    tree = get_tree_structure(QUEUE_DIR)

    # dashboard.mdも追加（特別扱い）
    if DASHBOARD_PATH.exists():
        tree.insert(
            0,
            {
                "name": "dashboard.md",
                "path": "dashboard.md",
                "is_dir": False,
                "prefix": "├── ",
            },
        )

    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "tree": tree,
            "base_path": BASE_PATH,
        },
    )


@app.get("/file/{file_path:path}", response_class=HTMLResponse)
async def view_file(request: Request, file_path: str):
    """
    ファイル内容表示（YAML/Markdown対応）
    """
    # dashboard.md特別処理
    if file_path == "dashboard.md":
        target_path = DASHBOARD_PATH
    else:
        target_path = (PROJECT_ROOT / file_path).resolve()

    # セキュリティチェック
    if not is_safe_path(target_path):
        raise HTTPException(status_code=403, detail="Access denied")

    if not target_path.exists() or not target_path.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    # ファイル内容読み取り
    try:
        content = target_path.read_text(encoding="utf-8")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to read file: {e}") from e

    # ファイルタイプに応じて整形
    suffix = target_path.suffix.lower()
    if suffix in [".yaml", ".yml"]:
        # YAML: シンタックスハイライト
        lexer = YamlLexer()
        formatter = HtmlFormatter(
            style="monokai",
            linenos="table",
            cssclass="source",
        )
        highlighted = highlight(content, lexer, formatter)
        css = formatter.get_style_defs(".source")
        file_type = "yaml"
        rendered_content = highlighted

    elif suffix == ".md":
        # Markdown: HTML変換
        md = markdown.Markdown(
            extensions=["fenced_code", "tables", "codehilite"],
        )
        rendered_content = md.convert(content)
        css = HtmlFormatter(style="monokai").get_style_defs(".codehilite")
        file_type = "markdown"

    else:
        # その他: プレーンテキスト
        lexer = get_lexer_by_name("text")
        formatter = HtmlFormatter(
            style="monokai",
            linenos="table",
            cssclass="source",
        )
        highlighted = highlight(content, lexer, formatter)
        css = formatter.get_style_defs(".source")
        file_type = "text"
        rendered_content = highlighted

    return templates.TemplateResponse(
        "file.html",
        {
            "request": request,
            "file_path": file_path,
            "file_type": file_type,
            "content": rendered_content,
            "css": css,
            "base_path": BASE_PATH,
        },
    )


def search_files(base_path: Path, query: str) -> list[Path]:
    """
    query に部分一致するファイル・ディレクトリを再帰検索

    Args:
        base_path: 検索ベースディレクトリ
        query: 検索クエリ（大文字小文字を区別しない）

    Returns:
        マッチしたパスのリスト（相対パス）
    """
    if not query:
        return []

    query_lower = query.lower()
    matches = []

    try:
        for entry in base_path.rglob("*"):
            # ファイル名に query が含まれるかチェック（大文字小文字を区別しない）
            if query_lower in entry.name.lower():
                matches.append(entry)
    except PermissionError:
        pass

    return matches


def build_search_tree(matches: list[Path], base_path: Path) -> list[dict[str, Any]]:
    """
    検索結果から親ディレクトリを含むツリー構造を構築

    Args:
        matches: マッチしたパスのリスト
        base_path: ベースパス（PROJECT_ROOT）

    Returns:
        ツリー構造（親ディレクトリも含む）
    """
    if not matches:
        return []

    # マッチしたパスとその全ての親パスを収集
    included_paths = set()
    for match in matches:
        # マッチしたパス自身を追加
        included_paths.add(match)
        # 親ディレクトリをすべて追加
        for parent in match.parents:
            if parent == base_path or not str(parent).startswith(str(base_path)):
                break
            included_paths.add(parent)

    # ツリー構造を再帰的に構築
    def build_subtree(current_path: Path, prefix: str = "") -> list[dict[str, Any]]:
        items = []
        if not current_path.is_dir():
            return items

        try:
            entries = sorted(
                current_path.iterdir(), key=lambda p: (not p.is_dir(), p.name)
            )
        except PermissionError:
            return items

        # included_paths に含まれるエントリのみをフィルタ
        filtered_entries = [e for e in entries if e in included_paths]

        for i, entry in enumerate(filtered_entries):
            is_last = i == len(filtered_entries) - 1
            current_prefix = "└── " if is_last else "├── "
            next_prefix = prefix + ("    " if is_last else "│   ")

            rel_path = entry.relative_to(PROJECT_ROOT)
            item = {
                "name": entry.name,
                "path": str(rel_path),
                "is_dir": entry.is_dir(),
                "prefix": prefix + current_prefix,
            }

            if entry.is_dir():
                item["children"] = build_subtree(entry, next_prefix)

            items.append(item)

        return items

    return build_subtree(QUEUE_DIR)


@app.get("/search", response_class=HTMLResponse)
async def search(request: Request, q: str = ""):
    """
    検索エンドポイント（htmx用パーシャルレスポンス）

    Args:
        q: 検索クエリ（ファイル名・ディレクトリ名の部分一致）

    Returns:
        HTMLフラグメント（ツリー構造）
    """
    if not q:
        # 空クエリの場合は通常のツリーを返す
        tree = get_tree_structure(QUEUE_DIR)

        # dashboard.mdも追加
        if DASHBOARD_PATH.exists():
            tree.insert(
                0,
                {
                    "name": "dashboard.md",
                    "path": "dashboard.md",
                    "is_dir": False,
                    "prefix": "├── ",
                },
            )
    else:
        # 検索実行
        matches = search_files(QUEUE_DIR, q)
        tree = build_search_tree(matches, PROJECT_ROOT)

    return templates.TemplateResponse(
        "search_results.html",
        {
            "request": request,
            "tree": tree,
            "query": q,
            "base_path": BASE_PATH,
        },
    )


@app.get("/health")
async def health():
    """
    ヘルスチェック
    """
    return {"status": "ok"}

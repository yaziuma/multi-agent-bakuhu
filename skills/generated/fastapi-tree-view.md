# FastAPI + Jinja2 + htmx ファイルツリー表示パターン

## 概要
FastAPI + Jinja2 + htmx 構成でファイル/ディレクトリのツリービューを美しくコンパクトに表示するスキル。

## 核心: Jinja2ホワイトスペース制御

**不要な改行が入る問題の原因**: Jinja2のブロックタグ前後の空白文字がそのまま出力される。

**解決策**: `{%- ... -%}` でハイフン付きトリミングを使う。

```jinja
{%- macro render_items(items) -%}
  <ul class="tree-items">
  {%- for item in items -%}
    {%- if item.is_dir -%}
      <li class="folder"
          hx-get="/file-tree?path={{ item.path | urlencode }}"
          hx-target="this"
          hx-swap="outerHTML"
          hx-trigger="click">
        <span class="icon"></span>{{ item.name }}
      </li>
    {%- else -%}
      <li class="file">
        <span class="icon"></span>{{ item.name }}
      </li>
    {%- endif -%}
  {%- endfor -%}
  </ul>
{%- endmacro -%}
```

## アンチパターン
- `<pre>` タグ: 全ての空白を保持するため制御困難。**使うな**。
- Jinja2ブロックタグにハイフンなし（`{% %}`）: 余計な改行が入る。**常に `{%- -%}` を使え**。

## CSS: コンパクトなツリー表示

```css
.tree-view {
  font-family: sans-serif;
  line-height: 1.4;
  padding: 0;
  margin: 0;
}

.tree-view ul {
  list-style-type: none;
  margin: 0;
  padding-left: 20px;
}

.tree-view li {
  padding: 2px 0;
  display: flex;
  align-items: center;
  cursor: pointer;
}

.tree-view li:hover {
  background-color: #f0f0f0;
}

.tree-view .icon {
  width: 1.5em;
  text-align: center;
  margin-right: 5px;
}
```

## htmx: 動的ツリー（遅延ロード + 折りたたみ/展開）

### 戦略
1. 初期表示: トップレベルのみ
2. フォルダクリック → `hx-get` でサブツリー取得
3. `hx-target="this"` + `hx-swap="outerHTML"` で差し替え

### FastAPIエンドポイント
```python
@app.get("/file-tree")
def file_tree(request: Request, path: str):
    # セキュリティ: ルート外に出させない
    req_path = Path(path).resolve()
    if BASE_DIR not in req_path.parents and req_path != BASE_DIR:
        path = str(BASE_DIR)

    if request.headers.get("HX-Request"):
        # htmx: 展開されたフォルダのHTMLフラグメント
        return templates.TemplateResponse("partials/expanded_folder.html", {...})
    # 通常: ページ全体
    return templates.TemplateResponse("index.html", {...})
```

### details/summary パターン（CSS-onlyの開閉）
```html
<details>
  <summary hx-get="/file-tree?path=..." hx-target="next .children" hx-swap="innerHTML">
    📁 folder_name
  </summary>
  <div class="children"><!-- htmxでロードされる --></div>
</details>
```

## チェックリスト
- [ ] 全Jinja2ブロックタグに `{%- -%}` ハイフン付与
- [ ] `<pre>` タグ不使用
- [ ] `ul/li` ベースの構造
- [ ] CSS: `list-style: none`, `margin: 0`, `padding-left: 20px`
- [ ] htmx: `hx-get` + `hx-target="this"` + `hx-swap="outerHTML"`
- [ ] セキュリティ: パストラバーサル防止

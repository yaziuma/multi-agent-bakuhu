# Shogun Absolute Prohibitions (Lord's orders)

<!-- bakuhu-specific: 将軍の絶対禁止事項 -->

## 禁止事項一覧

Unless Lord explicitly orders "Shogun do X", these are **ALL FORBIDDEN**:

| 禁止行為 | 具体例 |
|---------|--------|
| **コードを読む** | source (.py .js .html .css) を Read する |
| **コードを書く/編集する** | source を Edit/Write する |
| **デバッグ/テスト実行** | `python -c`, `curl`, `pytest`, `ruff` を実行する |
| **サーバ操作** | uvicorn を kill/restart する |

**「自分でやった方が早い」は最大の禁忌。** 指揮系統とコンテキスト節約を優先せよ。

## 代替手段

- コード確認が必要 → 足軽報告書を読め
- コード修正が必要 → 家老経由で足軽に委譲せよ
- テストが必要 → 足軽タスクを作成せよ
- サーバ操作が必要 → 足軽タスクを作成せよ

## 将軍に許可された操作

- YAMLファイルの編集（queue/, config/）
- send-keys（家老・伝令へのコマンド送信）
- dashboard.md の読み取り
- 報告書の読み取り
- Memory MCP 操作

## 背景

将軍がコードに触れると:
1. コンテキストが無駄に消費される（将軍のコンテキストは最も高価）
2. 指揮系統が崩れ、他エージェントが混乱する
3. 将軍の本来の責務（戦略判断・指揮）が圧迫される

## 参照

- 指揮系統: `CLAUDE.md` → Shogun Mandatory Rules
- 委譲手順: `skills/architecture.md`

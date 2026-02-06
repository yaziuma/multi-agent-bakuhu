# WebSocket リアルタイム出力バグ調査報告（忍び調査）

**調査日時**: 2026-02-06 05:53
**タスクID**: denrei_websocket_debug_v2
**ステータス**: 完了
**調査者**: Shinobi (Gemini)

## 根本原因

`.pyc` キャッシュファイル（Python バイトコード）が問題。

### 症状の解析

1. **ブラウザ表示**: 家老ペイン出力（古いコード）
2. **Python 直接実行**: 将軍ペイン出力（正しい）
3. **理由**: Uvicorn は古いキャッシュ`.pyc`を実行していた

### 技術的背景

- `/home/quieter/projects/shogun-web/ws/__pycache__/` に古い `tmux_bridge.cpython-313.pyc` が残存
- サーバー起動時、ソース`.py`の更新を正しく検出しない
- 直接実行時は新しいプロセスなので`.pyc`を再コンパイル

## 推奨修正手順

### 1. キャッシュ削除

```bash
cd /home/quieter/projects/shogun-web
find . -type d -name "__pycache__" -exec rm -r {} +
```

### 2. サーバー再起動

キャッシュ削除後、FastAPI/Uvicorn を再起動すれば正常化。

### 3. コード改変（Shinobi推奨）

**ファイル**: `ws/tmux_bridge.py`

- `self.session` → `self.multiagent_session` に改名
- `self.shogun_session` を新規追加してshogun セッションを初期化時にキャッシュ
- 全メソッドを新しい属性に対応

この変更により、セッション参照が明示的になり、将来の同様エラーを防止できます。

## 結論

**根本原因**: ソースコードは正しいが、古いバイトコードキャッシュをuvicornが実行中

**解決手順**:
1. キャッシュ削除
2. サーバー再起動
3. 推奨: コード改変で明示性向上

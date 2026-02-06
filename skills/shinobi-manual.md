# 忍び（Shinobi / Gemini）召喚マニュアル

> CLAUDE.md から分離。忍び召喚時に参照。

忍びは諜報・調査専門の外部委託エージェントである。Gemini CLI 経由でオンデマンド召喚する。

## 忍びの能力
- **Web検索**: Google Search統合で最新情報取得
- **大規模分析**: 1Mトークンコンテキストでコードベース全体を分析
- **マルチモーダル**: PDF/動画/音声の内容抽出

## 召喚権限
| 召喚者 | 可否 | 条件 | 伝令経由 |
|--------|------|------|---------|
| 将軍 | ○ | 無条件 | 必須 |
| 家老 | ○ | 無条件 | 必須 |
| 足軽 | △ | タスクYAMLに `shinobi_allowed: true` がある場合のみ | 必須 |

## 基本的な召喚方法
```bash
# 調査依頼
gemini -p "調査内容" 2>/dev/null > queue/shinobi/reports/report_001.md

# 結果の要約取得（コンテキスト保護）
head -50 queue/shinobi/reports/report_001.md
```

詳細は instructions/shinobi.md を参照。

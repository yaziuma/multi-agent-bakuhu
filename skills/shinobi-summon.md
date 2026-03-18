# 忍び（Gemini）召喚プロトコル（足軽視点）

<!-- bakuhu-specific: 足軽が許可制で忍びを召喚する手順 -->

忍びは諜報・調査専門の外部エージェント。**タスクYAMLで許可された場合のみ** 召喚できる。

## 許可の確認

タスクYAMLに以下が記載されている場合のみ召喚可：

```yaml
task:
  shinobi_allowed: true   # これがあれば召喚OK
  shinobi_budget: 3       # 最大召喚回数
```

`shinobi_allowed` がない場合は召喚禁止。違反は規律違反となる。

## 召喚方法

```bash
# 調査依頼（英語で記述することを推奨）
gemini -p "調査内容を英語で記述" 2>/dev/null > queue/shinobi/reports/report_{task_id}.md

# 結果の要約取得（コンテキスト保護のため head を使う）
head -50 queue/shinobi/reports/report_{task_id}.md
```

## 忍びを使うべき場面

| 場面 | 例 |
|------|-----|
| 最新ドキュメント調査 | 「TypeScript 5.x の breaking changes」 |
| ライブラリ比較 | 「Playwright vs Puppeteer」 |
| 外部コードベース理解 | 「このOSSのアーキテクチャ」 |

## 忍びを使うべきでない場面

- コード実装（足軽の仕事）
- ファイル編集（足軽の仕事）
- 単純なファイル読み取り（直接 Read ツールを使え）
- 設計判断（家老自身が判断すること）

## 禁止事項

- `shinobi_allowed` がないタスクでの召喚禁止
- `shinobi_budget` を超えた召喚禁止
- 家老の指示なしの自発的召喚禁止

## 報告への記載義務

忍びを召喚した場合、報告YAMLに必ず記載すること：

```yaml
shinobi_usage:
  called: true
  count: 2
  queries:
    - "Research TypeScript 5.x breaking changes"
    - "Compare Playwright vs Puppeteer"
```

## 参照

- 忍び管理（家老視点）: `skills/external-agent-rules.md`
- 既存忍び情報: `skills/shinobi-manual.md`

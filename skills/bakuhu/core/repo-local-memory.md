---
audience: all
---

# Repo-Local Memory と Skills 構成（bakuhu固有）

<!-- bakuhu-specific: Layer 1b repo-local memory と skills/ ディレクトリ構成 -->

## Layer 1b: repo-local memory

**対象**: 将軍（shogun）のみ。

```
Layer 1b: repo-local memory
  — memory/MEMORY.md に格納
  — セッション開始時に自動読み込み（shogunのみ）
  — ファイルがなければサイレントにスキップ
```

**用途**: セッションをまたいで保持したいリポジトリローカルな情報（Memory MCPとは別）。
Memory MCPが全プロジェクト共有なのに対し、このファイルはこのリポジトリ専用。

**書き込みルール**:
- identity情報（ロール名、pane ID等）を書くことは**禁止**（全エージェント共有ファイルのため）
- `MEMORY.md` は各ロールのメモリファイルへの **インデックス** として使う
- 実際のメモリは `memory/{role}.md` に分割して保存

**参照**: `memory/MEMORY.md` → 役職別メモリファイルのルックアップテーブル

## Skills ディレクトリ構成（bakuhu）

```
skills/                        # コアスキル（git-tracked）
  ├─ context-health.md         # /compact テンプレート、混合戦略
  ├─ shinobi-manual.md         # 忍び能力、召喚プロトコル
  ├─ spec-before-action.md     # 仕様先行の原則（全階層必読）
  ├─ skill-creator/            # スキル自動生成メタスキル（upstreamから）
  └─ generated/                # 開発プロジェクト用スキル（git-ignored）
      ├─ async-rss-fetcher.md
      └─ ...
```

**全エージェント必読**: `skills/spec-before-action.md`
— 仕様が完全確定するまで下流に実装指示を送るな。違反は殿の逆鱗に触れる。

## Context Layers（全体像）

```
Layer 1:  Memory MCP       — セッション横断（好み、ルール、教訓）
Layer 1b: repo-local memory — リポジトリローカル（memory/MEMORY.md, shogunのみ）
Layer 2:  Project files    — プロジェクト固有（config/, projects/, context/）
Layer 3:  YAML Queue       — タスクデータ永続化（queue/ — 権威ある情報源）
Layer 4:  Session context  — 揮発性（CLAUDE.md自動読み込み、/clearで消える）
```

## 参照

- Session Start手順: `CLAUDE.md` → Session Start / Recovery
- Memory MCP使用方針: `instructions/shogun.md` → Memory MCP section

---
name: production-change-procedure
description: 本番環境変更の標準手順。hook/設定ファイル等の変更時に参照。
---

# Production Change Procedure

## Overview

本番環境（稼働中hook、.gitignore、重要設定ファイル等）を変更する際の必須手順。
cmd_320-322の連鎖失敗（3度のやり直し）を教訓に策定。

## Standard Procedure

### Phase 1: Staging（ステージング作成）

1. `queue/staging/` にステージングファイルを作成
   - **Writeツール使用**（Bash heredocは.gitignore含有時に自己ブロックの危険）
   - `.claude/hooks/staging/` はwrite-guardでブロックされるため使用禁止
2. `bash -n <staging-file>` でシンタックス検証

### Phase 2: Review（御意見番レビュー）

1. goikenban（御意見番）にステージングファイルのレビューを依頼
2. 検査項目（hookの場合）:
   - 全バイパス経路の検証（echo/sed/python/ruby/node/git update-index等）
   - リダイレクト・パイプ経由の書き込み検知
   - 許可リスト方式の網羅性
3. **Critical 0** でなければPhase 1に戻って修正

### Phase 3: Deploy（本番配置）

1. バックアップ: `cp <production-file> <production-file>.bak`
2. 配置: `cp <staging-file> <production-file>`
3. 権限設定: `chmod +x <production-file>` （hookの場合）

### Phase 4: Test（本番動作テスト）

1. ブロックされるべき操作がexit 2になることを確認
2. 通過すべき操作がexit 0になることを確認
3. テスト失敗時: 即座に `cp <production-file>.bak <production-file>` で復元

### Phase 5: Cleanup（後片付け）

1. テスト全項目パス後、staging/ と .bak を削除
2. 報告YAML作成

## Protected Files

以下のファイルは殿以外の変更を完全禁止:
- `.gitignore`
- `.gitattributes`
- Read（cat, grep, git diff等）のみ許可

## Pre-Launch Checklist（cmd発令前確認）

cmdを発令する前に将軍が必ず確認すべき項目:

1. 各ステップで何が起きるか全て書き出したか
2. hookに引っかかるか確認したか
3. ファイル操作の副作用を確認したか（git rm vs --cached等）
4. 対象パスへの権限（write-guard）を確認したか
5. 本番直接変更ではなくstaging経由か
6. 失敗時のロールバック手順を用意したか

## Lessons Learned

| 失敗 | 原因 | 対策 |
|------|------|------|
| cmd_320 git rm (--cached忘れ) | ファイル操作の副作用未確認 | チェックリスト項目3 |
| cmd_322 heredocデッドロック | guardian hookが自身のデプロイをブロック | Writeツール使用 + staging/ |
| cmd_322r write-guardブロック | .claude/hooks/への書き込み権限未確認 | queue/staging/ 使用 |

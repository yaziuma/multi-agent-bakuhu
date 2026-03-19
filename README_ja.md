<div align="center">

# multi-agent-bakuhu

**AIコーディング軍団を封建武将のように統率せよ。**

複数のAIコーディングエージェントを並列実行 — **Claude Code（主力）+ Gemini（忍び）+ Codex（客将）** — 連携コストゼロの侍階層システムで統率する。

**Talk Coding, not Vibe Coding. スマホに喋るだけ、AIが実行する。**

[![GitHub Stars](https://img.shields.io/github/stars/yaziuma/multi-agent-bakuhu?style=social)](https://github.com/yaziuma/multi-agent-bakuhu)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell%2FBash-100%25-green)]()

[English](README.md) | [日本語](README_ja.md)

</div>

---

## クイックスタート

**必要環境:** tmux、bash 4+、[Claude Code](https://claude.ai/code)

```bash
git clone https://github.com/yaziuma/multi-agent-bakuhu
cd multi-agent-bakuhu
bash first_setup.sh          # 初回セットアップ: 設定・依存関係・MCP
bash shutsujin_departure.sh  # 全エージェント起動
```

将軍ペインにコマンドを入力：

> 「JavaScriptフレームワーク上位5つを調査して比較表を作成せよ」

将軍が委譲 → 家老がタスク分解 → 複数の足軽が並列実行。深い調査が必要なら伝令が忍び（Gemini）または客将（Codex）を召喚。
あなたはダッシュボードを見るだけ。それだけ。

> **もっと詳しく知りたい方へ:** 以降のREADMEでアーキテクチャ・外部エージェント連携・コンテキスト健康管理・Bakuhu独自機能を解説します。

---

## これは何？

**multi-agent-bakuhu** は、[multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) を土台に、外部エージェント連携・より深い封建階層・コンテキスト健康管理・hookベースのセキュリティを追加した拡張フォークです。**Claude Code** がコアエージェント全員（将軍・家老・足軽・伝令）を担当し、**Gemini**（忍び経由）と **Codex**（客将経由）が外部専門家として召喚される混成軍を形成します。

**なぜ使うのか？**
- 1つの命令で複数のAIワーカーが並列実行
- 待ち時間なし — タスクがバックグラウンドで動いている間も次の命令が出せる
- AIがセッションを跨いであなたの好みを記憶（Memory MCP）
- ダッシュボードでリアルタイム進捗確認
- Claude・Gemini・Codexの混成軍が統一階層で協調動作

```
      あなた（上様）
           │
           ▼ 命令を出す
    ┌─────────────┐
    │   SHOGUN    │  ← 命令を受け取り、即座に委譲
    └──────┬──────┘
           │ YAMLファイル + tmux
    ┌──────▼──────┐
    │    KARO     │  ← タスクを分解・分配、ダッシュボード管理
    └──────┬──────┘
           │
    ┌─┬─┬─┬─┬─┬─┬─┬─┬──┬──┐
    │1│2│3│4│5│6│7│8│D1│D2│  ← ワーカー + 伝令
    └─┴─┴─┴─┴─┴─┴─┴─┴──┴──┘
      足軽 1-8             伝令 1-2
                               │
                     ┌─────────┴──────────┐
                     ▼                    ▼
               ┌──────────┐        ┌──────────┐
               │  忍び    │        │  客将    │
               │(Gemini)  │        │ (Codex)  │
               └──────────┘        └──────────┘
                諜報・調査          戦略・設計助言
```

> [Akira-Papa氏](https://github.com/Akira-Papa/Claude-Code-Communication) の Claude-Code-Communication、[yohey-w氏](https://github.com/yohey-w/multi-agent-shogun) の multi-agent-shogun を土台に、外部エージェント統合（Gemini・Codex）・より深い封建階層・コンテキスト健康管理・hookセキュリティ・Agent Team対応を大幅追加して再設計。

---

## なぜ Bakuhu なのか？

多くのマルチエージェントフレームワークは、連携のためにAPIトークンを消費します。Bakuhuは違います。

| | Claude Code `Task` ツール | Claude Code Agent Teams | LangGraph | CrewAI | **multi-agent-bakuhu** |
|---|---|---|---|---|---|
| **アーキテクチャ** | 1プロセス内のサブエージェント | チームリーダー + メンバー | グラフベースの状態機械 | ロールベースエージェント | tmux経由の階層構造 |
| **並列性** | 逐次実行（1つずつ） | 複数の独立セッション | 並列ノード（v0.2+） | 限定的 | **N個の独立エージェント** |
| **連携コスト** | TaskごとにAPIコール | トークン消費大（メンバー数×コンテキスト） | API + インフラ（Postgres/Redis） | API + CrewAIプラットフォーム | **ゼロ**（YAML + tmux） |
| **外部AI連携** | なし | なし | カスタム実装 | カスタム実装 | **Gemini + Codex（伝令経由）** |
| **可観測性** | Claudeのログのみ | tmuxペイン or プロセス内 | LangSmith連携 | OpenTelemetry | **ライブtmuxペイン** + ダッシュボード |
| **スキル発見** | なし | なし | なし | なし | **ボトムアップ自動提案** |
| **コンテキスト安全管理** | なし | なし | なし | なし | **hookベースのロール強制** |
| **セットアップ** | Claude Code内蔵 | 内蔵（実験的） | 重い（インフラ必要） | pip install | シェルスクリプト |

### 他のフレームワークとの違い

**連携コストゼロ** — エージェント間の通信はディスク上のYAMLファイル。APIコールは実際の作業にのみ使われ、オーケストレーションには使われません。N個のエージェントを動かしても、支払うのはN個分の作業コストだけです。

**完全な透明性** — すべてのエージェントが見えるtmuxペインで動作。すべての指示・報告・判断がプレーンなYAMLファイルで、読んで、diffして、バージョン管理できます。ブラックボックスなし。

**実戦で鍛えた階層構造** — 将軍→家老→足軽→伝令の指揮系統が設計レベルで衝突を防止：明確な責任分担、エージェントごとの専用ファイル、イベント駆動通信、ポーリングなし。

**マルチモデル協調** — Claude（Opus/Sonnet/Haiku）・Gemini・Codexが連携。各モデルが得意な領域で投入される。外部エージェントは**常に伝令経由**で召喚され、指揮系統のレスポンスを維持。

**hookベースのセキュリティ** — 全エージェントがロール別のClaude Code PreToolUseフックに拘束される。将軍はコードを書けない。足軽はシステム設定に触れない。慣例ではなくツール呼び出しレベルで強制。

---

## なぜCLI（APIではなく）？

多くのAIコーディングツールはトークン従量課金。複数のOpus級エージェントをAPI経由で動かすと高コスト。CLI定額サブスクはこれを逆転させる：

| | API（従量課金） | CLI（定額制） |
|---|---|---|
| **複数エージェント × Opus** | ~$100+/時間 | ~$200/月 |
| **コスト予測性** | 予測不能なスパイク | 月額固定 |
| **使用時の心理** | 1トークンが気になる | 使い放題 |
| **実験の余地** | 制約あり | 自由に投入 |

**「AIを使い倒す」思想** — 定額CLIサブスクなら、複数の足軽を気兼ねなく投入できる。1時間稼働でも24時間稼働でもコストは同じ。「まあまあ」と「徹底的に」の二択で悩む必要がない — エージェントを増やせばいい。

### マルチモデル協調

Bakuhuは3種類のAIモデルを、得意分野ごとに使い分ける：

| モデル | 担当 | 役割 | 強み |
|--------|------|------|------|
| **Claude Code**（Opus/Sonnet/Haiku） | 将軍・家老・足軽・伝令 | コアエージェント全員 | 実戦実証済み統合、Memory MCP、専用ファイルツール |
| **Gemini CLI** | 忍び（Shinobi） | 外部諜報員 | 100万トークン文脈、ウェブ検索、PDF/動画分析 |
| **Codex CLI** | 客将（Kyakusho） | 外部参謀 | 深い推論、設計判断、コードレビュー |

外部エージェント（Gemini/Codex）は**必ず伝令経由**で召喚される。直接召喚は禁止行為。これにより、ブロッキングAPIコールを伝令が肩代わりし、指揮系統は常にレスポンシブを維持する。

---

## ボトムアップスキル発見

他のフレームワークにはない機能です。

足軽がタスクを実行する中で、**再利用可能なパターンを自動的に発見**し、スキル候補として提案します。家老が提案を `dashboard.md` に集約し、殿（あなた）が正式なスキルに昇格させるか判断します。

```
足軽がタスクを完了
    ↓
気づき: 「このパターン、3つのプロジェクトで同じことをした」
    ↓
YAMLで報告:  skill_candidate:
                 found: true
                 name: "api-endpoint-scaffold"
                 reason: "3プロジェクトで同じRESTスキャフォールドパターンを使用"
    ↓
dashboard.md に掲載 → 殿が承認 → .claude/commands/ にスキル作成
    ↓
全エージェントが /api-endpoint-scaffold を呼び出し可能に
```

スキルは実際の作業から有機的に成長します — 既製のテンプレートライブラリからではなく。スキルセットは**あなた自身**のワークフローの反映になります。

---

## 🚀 クイックスタート（詳細）

### 🪟 Windowsユーザー（WSL2）

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **リポジトリをダウンロード**

[ZIPダウンロード](https://github.com/yaziuma/multi-agent-bakuhu/archive/refs/heads/main.zip) して `C:\tools\multi-agent-bakuhu` に展開

*または git を使用:* `git clone https://github.com/yaziuma/multi-agent-bakuhu.git C:\tools\multi-agent-bakuhu`

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **`install.bat` を実行**

右クリック→「管理者として実行」（WSL2が未インストールの場合）。WSL2 + Ubuntu をセットアップします。

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

🐧 **Ubuntu を開いて以下を実行**（初回のみ）

```bash
cd /mnt/c/tools/multi-agent-bakuhu
./first_setup.sh
```

</td>
</tr>
<tr>
<td>

**Step 4**

</td>
<td>

✅ **出陣！**

```bash
./shutsujin_departure.sh
```

</td>
</tr>
</table>

#### 🔑 初回のみ: 認証

`first_setup.sh` 完了後、一度だけ以下を実行して認証：

```bash
# 1. PATHの反映
source ~/.bashrc

# 2. OAuthログイン + Bypass Permissions承認（1コマンドで完了）
claude --dangerously-skip-permissions
#    → ブラウザが開く → Anthropicアカウントでログイン → CLIに戻る
#    → 「Bypass Permissions」の承認画面 → 「Yes, I accept」を選択（↓キーで2を選んでEnter）
#    → /exit で退出
```

認証情報は `~/.claude/` に保存され、以降は不要。

#### 📅 毎日の起動

**Ubuntuターミナル**（WSL）を開いて実行：

```bash
cd /mnt/c/tools/multi-agent-bakuhu
./shutsujin_departure.sh
```

### 📱 スマホからアクセス（どこからでも指揮）

ベッドから、カフェから、トイレから。スマホでAI部下を操作できる。

**必要なもの（全部無料）：**

| 名前 | 一言で言うと | 役割 |
|------|------------|------|
| [Tailscale](https://tailscale.com/) | 外から自宅に届く道 | カフェからでもトイレからでも自宅PCに繋がる |
| SSH | その道を歩く足 | Tailscaleの道を通って自宅PCにログインする |
| [Termux](https://termux.dev/) | スマホの黒い画面 | SSHを使うために必要。スマホに入れるだけ |

**セットアップ：**

1. WSLとスマホの両方にTailscaleをインストール
2. WSL側（Auth key方式 — ブラウザ不要）：
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscaled &
   sudo tailscale up --authkey tskey-auth-XXXXXXXXXXXX
   sudo service ssh start
   ```
3. スマホのTermuxから：
   ```sh
   pkg update && pkg install openssh
   ssh あなたのユーザー名@あなたのTailscale IP
   css    # 将軍に繋がる
   ```
4. ＋ボタンで新しいウィンドウを開いて、部下の様子も見る：
   ```sh
   ssh あなたのユーザー名@あなたのTailscale IP
   csm    # 家老+足軽+伝令のペインが広がる
   ```

**切り方：** Termuxのウィンドウをスワイプで閉じるだけ。tmuxセッションは生き残る。AI部下は黙々と作業を続けている。

**音声入力：** スマホの音声入力で喋れば、将軍が自然言語を理解して全軍に指示を出す。

---

<details>
<summary>🐧 <b>Linux / Mac ユーザー</b>（クリックで展開）</summary>

### 初回セットアップ

```bash
# 1. リポジトリをクローン
git clone https://github.com/yaziuma/multi-agent-bakuhu.git ~/multi-agent-bakuhu
cd ~/multi-agent-bakuhu

# 2. スクリプトに実行権限を付与
chmod +x *.sh

# 3. 初回セットアップを実行
./first_setup.sh
```

### 毎日の起動

```bash
cd ~/multi-agent-bakuhu
./shutsujin_departure.sh
```

</details>

---

<details>
<summary>❓ <b>WSL2とは？なぜ必要？</b>（クリックで展開）</summary>

### WSL2について

**WSL2（Windows Subsystem for Linux）** は、Windows内でLinuxを実行できる機能です。このシステムは `tmux`（Linuxツール）を使って複数のAIエージェントを管理するため、WindowsではWSL2が必要です。

### WSL2がまだない場合

問題ありません！`install.bat` を実行すると：
1. WSL2がインストールされているかチェック（なければ自動インストール）
2. Ubuntuがインストールされているかチェック（なければ自動インストール）
3. 次のステップ（`first_setup.sh` の実行方法）を案内

**クイックインストールコマンド**（PowerShellを管理者として実行）：
```powershell
wsl --install
```

その後、コンピュータを再起動して `install.bat` を再実行してください。

</details>

---

<details>
<summary>📋 <b>スクリプトリファレンス</b>（クリックで展開）</summary>

| スクリプト | 用途 | 実行タイミング |
|-----------|------|---------------|
| `install.bat` | Windows: WSL2 + Ubuntu のセットアップ | 初回のみ |
| `first_setup.sh` | tmux、Node.js、Claude Code CLI のインストール + Memory MCP設定 | 初回のみ |
| `shutsujin_departure.sh` | tmuxセッション作成 + Claude Code起動 + 指示書読み込み | 毎日 |

### `shutsujin_departure.sh` が行うこと：
- ✅ tmuxセッションを作成（shogun + multiagent）
- ✅ 全エージェントでClaude Codeを起動
- ✅ 各エージェントに指示書を自動読み込み
- ✅ キューファイルをリセットして新しい状態に
- ✅ ntfyリスナーを起動（設定済みの場合）

**実行後、全エージェントが即座にコマンドを受け付ける準備完了！**

</details>

---

### ✅ セットアップ後の状態

以下のAIエージェントが自動起動します：

| エージェント | 役割 | 数 | モデル |
|-------------|------|-----|-------|
| 🏯 将軍（Shogun） | 総大将 — あなたの命令を受ける | 1 | Opus |
| 📋 家老（Karo） | 管理者 — タスクを分配、ダッシュボード管理 | 1 (+控え1) | Opus |
| ⚔️ 足軽（Ashigaru） | ワーカー — 並列でタスク実行 | 3〜8（設定可） | Sonnet/Opus |
| 📨 伝令（Denrei） | 使者 — 外部エージェントとの通信 | 2 | Haiku |

tmuxセッションが作成されます：
- `shogun` — ここに接続してコマンドを出す
- `multiagent` — ワーカーがバックグラウンドで稼働

---

## 📖 基本的な使い方

### Step 1: 将軍に接続

`shutsujin_departure.sh` 実行後、全エージェントが自動的に指示書を読み込み、作業準備完了となります。

新しいターミナルを開いて将軍に接続：

```bash
tmux attach-session -t shogun
```

### Step 2: 最初の命令を出す

将軍は既に初期化済み！そのまま命令を出せます：

```
JavaScriptフレームワーク上位5つを調査して比較表を作成せよ
```

将軍は：
1. タスクをYAMLファイルに書き込む
2. 家老（管理者）に通知
3. 即座にあなたに制御を返す（待つ必要なし！）

その間、家老はタスクを足軽ワーカーに分配し、並列実行します。より深い調査が必要な場合、家老は伝令を派遣して忍び（Gemini）を召喚します。

### Step 3: 進捗を確認

エディタで `dashboard.md` を開いてリアルタイム状況を確認：

```markdown
## 進行中
| ワーカー | タスク | 状態 |
|----------|--------|------|
| 足軽 1 | React調査 | 実行中 |
| 足軽 2 | Vue調査 | 実行中 |
| 伝令1 → 忍び | Angularトレンド調査（ウェブ） | 実行中 |
| 足軽 3 | Svelte調査 | 完了 |
```

### 詳細なフロー

```
あなた: 「トップ5のMCPサーバを調査して比較表を作成せよ」
```

将軍がタスクを `queue/shogun_to_karo.yaml` に書き込み、家老を起動。あなたには即座に制御が戻ります。

家老がタスクをサブタスクに分解：

| ワーカー | 割当内容 |
|----------|----------|
| 足軽1 | Notion MCP調査 |
| 足軽2 | GitHub MCP調査 |
| 足軽3 | Playwright MCP調査 |
| 伝令1 → 忍び | Memory MCP + Sequential Thinking MCP（ウェブ検索） |

全エージェントが同時に調査開始。結果は完了次第 `dashboard.md` に表示されます。

---

## ✨ 主な特徴

### ⚡ 1. 並列実行

1つの命令で複数の並列タスクを生成：

```
あなた: 「5つのMCPサーバを調査せよ」
→ 複数の足軽が同時に調査開始
→ 足りない部分は伝令が忍び（Gemini）を召喚して補完
→ 数時間ではなく数分で結果が出る
```

### 🔄 2. ノンブロッキングワークフロー

将軍は即座に委譲して、あなたに制御を返します：

```
あなた: 命令 → 将軍: 委譲 → あなた: 次の命令をすぐ出せる
                                    ↓
                    ワーカー: バックグラウンドで実行
                                    ↓
                    ダッシュボード: 結果を表示
```

長いタスクの完了を待つ必要はありません。

### 🧠 3. セッション間記憶（Memory MCP）

AIがあなたの好みを記憶します：

```
セッション1: 「シンプルな方法が好き」と伝える
            → Memory MCPに保存

セッション2: 起動時にAIがメモリを読み込む
            → 複雑な方法を提案しなくなる
```

### 📡 4. イベント駆動通信（ポーリングなし）

エージェント同士はYAMLファイルを書いて通信します — **ポーリングなし、APIコールの浪費なし。**

```
家老が足軽3号を起こしたい場合:

Step 1: メッセージを書く           Step 2: エージェントを起こす
┌──────────────────────┐           ┌──────────────────────────┐
│ inbox_write.sh       │           │ inbox_watcher.sh         │
│                      │           │                          │
│ メッセージ全文を     │  ファイル │ ファイル変更を検知       │
│ ashigaru3.yaml に    │──変更────▶│ (inotifywait、ポーリング │
│ flock付きで書き込み  │           │  なし)                   │
└──────────────────────┘           │                          │
                                   │ 起床通知:                │
                                   │  短い「inbox3」だけ      │
                                   └──────────────────────────┘

Step 3: エージェントが自分のinboxを読む
┌──────────────────────────────────┐
│ 足軽3号が ashigaru3.yaml を読む  │
│ → 未読メッセージを発見           │
│ → 処理する                       │
│ → 既読にする                     │
└──────────────────────────────────┘
```

**設計のポイント:**
- **メッセージ内容はtmuxを経由しない** — 送るのは短い「inbox3」という起床通知だけ。中身はエージェントが自分でファイルを読む
- **待機中のCPU使用率ゼロ** — ポーリングではない。カーネルイベント待機のため、メッセージ間のCPU使用率は0%
- **配信保証** — ファイル書き込みが成功すれば、メッセージは確実にそこにある

**3フェーズエスカレーション** — エージェントが起床通知に反応しない場合：

| フェーズ | タイミング | 対応 |
|---------|-----------|------|
| Phase 1 | 0〜2分 | 標準的な起床通知 |
| Phase 2 | 2〜4分 | Escape×2 + C-c でカーソルリセット後に再通知 |
| Phase 3 | 4分以上 | `/clear` でセッション強制リセット（5分に1回まで） |

### 📊 5. エージェント状態確認

各エージェントのtmuxペイン内容を確認して稼働状況を把握：

```bash
# tmuxペインの内容から状態を確認
tmux capture-pane -t multiagent:agents.0 -p | tail -5   # karo
tmux capture-pane -t multiagent:agents.1 -p | tail -5   # ashigaru1
```

タスク状況はKaroがリアルタイムで更新する `dashboard.md` で確認：

```markdown
## 進行中
| ワーカー | タスク | 状態 |
|----------|--------|------|
| ashigaru1 | subtask_042a_research | assigned |
| ashigaru2 | subtask_042b_review | done |
| denrei1 | summon_shinobi_042c | assigned |
```

### 📸 6. スクリーンショット連携

VSCode拡張のClaude Codeはスクショで事象を説明できます。このCLIシステムでも同等の機能を実現：

```yaml
# config/settings.yaml でスクショフォルダを設定
screenshot:
  path: "/mnt/c/Users/あなたの名前/Pictures/Screenshots"
```

```
# 将軍に伝えるだけ:
あなた: 「最新のスクショを見ろ」
あなた: 「スクショ2枚見ろ」
→ AIが即座にスクリーンショットを読み取って分析
```

**💡 Windowsのコツ:** `Win + Shift + S` でスクショが撮れます。

### 📁 7. コンテキスト管理（4層アーキテクチャ）

効率的な知識共有のため、四層構造のコンテキストを採用：

| レイヤー | 場所 | 用途 |
|---------|------|------|
| Layer 1: Memory MCP | `memory/shogun_memory.jsonl` | プロジェクト横断・セッションを跨ぐ長期記憶 |
| Layer 2: Project | `config/projects.yaml`, `context/{project}.md` | プロジェクト固有情報・技術知見 |
| Layer 3: YAML Queue | `queue/shogun_to_karo.yaml`, `queue/tasks/`, `queue/reports/` | タスク管理・指示と報告の正データ |
| Layer 4: Session | CLAUDE.md, instructions/*.md | 作業中コンテキスト（/clearで破棄） |

この設計により：
- どの足軽でも任意のプロジェクトを担当可能
- エージェント切り替え時もコンテキスト継続
- 関心の分離が明確
- セッション間の知識永続化

#### /clear プロトコル（コスト最適化）

長時間作業するとコンテキスト（Layer 4）が膨れ、APIコストが増大する。`/clear` でセッション記憶を消去すれば、コストがリセットされる。Layer 1〜3はファイルとして残るので失われない。

`/clear` 後の復帰コスト: **約1,950トークン**（目標5,000の39%）

1. CLAUDE.md（自動読み込み）→ shogunシステムの一員と認識
2. `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` → 自分の番号を確認
3. Memory MCP 読み込み → 殿の好みを復元（~700トークン）
4. タスクYAML 読み込み → 次の仕事を確認（~800トークン）

「何を読ませないか」の設計がコスト削減に効いている。

### 📱 8. スマホ通知（ntfy）

スマホと将軍の双方向通信 — SSH・Tailscale・サーバー不要。

| 方向 | 仕組み |
|------|--------|
| **スマホ → 将軍** | ntfyアプリでメッセージを送信 → `ntfy_listener.sh` が受信 → 将軍が自動処理 |
| **家老 → スマホ（直接）** | `dashboard.md` 更新時に `scripts/ntfy.sh` でプッシュ通知 — 将軍バイパス |

```
📱 あなた（ベッドから）     🏯 将軍
    │                          │
    │  「React 19を調査せよ」  │
    ├─────────────────────────►│
    │    (ntfy メッセージ)     │  → 家老に委譲 → 足軽が作業
    │                          │
    │  「✅ cmd_042 完了」     │
    │◄─────────────────────────┤
    │    (プッシュ通知)        │
```

**セットアップ:**
1. `config/settings.yaml` に `ntfy_topic: "shogun-yourname"` を追加
2. スマホに [ntfy アプリ](https://ntfy.sh) をインストールして同じトピックを購読
3. `shutsujin_departure.sh` がリスナーを自動起動 — 追加手順なし

**通知例:**

| イベント | 通知内容 |
|---------|---------|
| コマンド完了 | `✅ cmd_042 complete — 5/5 subtasks done` |
| タスク失敗 | `❌ subtask_042c failed — API rate limit` |
| 要対応 | `🚨 Action needed: approve skill candidate` |

無料・アカウント不要・サーバー不要。[ntfy.sh](https://ntfy.sh) — オープンソースのプッシュ通知サービスを使用。

> **⚠️ セキュリティ:** トピック名がパスワード。知っている人は通知を読めて将軍に命令できる。推測されにくい名前を選び、**公開の場では絶対に使わないこと**。

### 🖼️ 9. ペインボーダーのタスク表示

各tmuxペインが現在のタスクをボーダーに表示：

```
┌ ashigaru1 (Sonnet) VF requirements ─┬ ashigaru3 (Opus) API research ──────┐
│                                      │                                     │
│  SayTask要件に取り組み中             │  REST APIパターンを調査中           │
│                                      │                                     │
├ ashigaru2 (Sonnet) ─────────────────┼ denrei1 (Haiku) ────────────────────┤
│                                      │                                     │
│  （待機中 — 割当待ち）               │  忍びを召喚してウェブ検索中         │
│                                      │                                     │
└──────────────────────────────────────┴─────────────────────────────────────┘
```

- **稼働中**: `ashigaru1 (Sonnet) VF requirements` — エージェント名、モデル、タスク概要
- **待機中**: `ashigaru1 (Sonnet)` — モデル名のみ、タスクなし
- 家老がタスクを割当・完了するたびに自動更新
- 全ペインを一目見るだけで誰が何をしているか即座に把握

### 🔊 10. 雄叫びモード（戦闘の雄叫び）

足軽がタスクを完了すると、個性的な雄叫びをtmuxペインに表示 — AI部下が頑張っているという視覚的な実感を提供。

```
┌ ashigaru1 (Sonnet) ──────────┬ ashigaru2 (Sonnet) ──────────┐
│                               │                               │
│  ⚔️ 足軽1号、先陣切った！     │  🔥 足軽2号、二番槍の意地！   │
│  八刃一志！                   │  八刃一志！                   │
│  ❯                            │  ❯                            │
└───────────────────────────────┴───────────────────────────────┘
```

家老が各タスクYAMLに `echo_message` フィールドを書き、足軽がすべての作業完了後に**最後の行動**として `echo` を実行。メッセージは `❯` プロンプトの上に残る。

**雄叫びモードはデフォルト。** 無効化するには：

```bash
./shutsujin_departure.sh --silent    # 雄叫びなし
./shutsujin_departure.sh             # デフォルト: 雄叫びモード
```

---

## 🥷 外部エージェント（Bakuhu独自機能）

将軍は**伝令（使者）経由**でClaude Code以外の外部専門家を召喚できます：

| エージェント | ツール | 役割 | 得意分野 |
|-------------|--------|------|---------|
| **忍び（Shinobi）** | Gemini CLI | 諜報・調査 | 100万トークン文脈、ウェブ検索、PDF/動画分析 |
| **客将（Kyakusho）** | Codex CLI | 参謀・設計 | 深い推論、設計判断、コードレビュー |

**必要なもの:**
- **忍び**: 別途 [Gemini CLI](https://github.com/google-gemini/gemini-cli) のインストールが必要
- **客将**: 別途 [Codex CLI](https://github.com/openai/codex) のインストールが必要

**鉄則:**
- 将軍・家老が外部エージェントを召喚するのは**伝令経由のみ**（直接召喚は禁止行為）
- 伝令がブロッキングAPIコールを肩代わりし、指揮系統のレスポンスを維持
- 足軽は明示的許可（`shinobi_allowed: true`）がある場合のみ召喚可

**なぜ伝令が必要なのか？**

Gemini CLIやCodex CLIなどの外部ツールは、実行中はターミナルをブロックする。家老が直接呼ぶと、その間は指揮系統全体が固まる。伝令は専用ペインでこのブロッキングコストを肩代わりするため、家老は他のタスクに集中し続けられる。

```
伝令なし:                    伝令あり:
家老 → Geminiを直接呼ぶ     家老 → 伝令1 → Gemini（ブロッキング）
家老 30秒間フリーズ          家老 フリー（他タスクに割当可）
                             伝令1 完了後に報告
```

---

## 🛡️ コンテキスト健康管理（Bakuhu独自機能）

長時間稼働するエージェントはコンテキストが肥大化し、APIコストが増大する。Bakuhuは組み込み戦略でこれを管理する：

### コンテキスト使用率の閾値

| 状態 | 使用率 | 推奨アクション |
|------|--------|---------------|
| 🟢 健全 | 0-60% | 通常作業を継続 |
| 🟡 注意 | 60-70% | 現タスク後に /compact（run_compact.sh経由） |
| 🔴 危険 | 70-80% | 猶予なし。即時 /compact（run_compact.sh経由） |
| ⚫ 限界 | 80%以上 | まず /compact を試みる。改善なければ /clear |

### エージェント別推奨戦略

| エージェント | 推奨戦略 | 理由 |
|-------------|----------|------|
| **将軍** | `/compact` 優先 | コンテキスト保持が重要 |
| **家老** | 混合: `/compact` 3回 → `/clear` 1回 | 保持とコストのバランス（30%削減） |
| **足軽** | タスク完了ごとに `/clear` | タスク単位でリセット、復帰コスト最小 |
| **伝令** | タスク完了ごとに `/clear` | ステートレス設計 |

**控え家老（ホットスタンバイ）** が待機しており、主家老が `/clear` を必要とする際に引き継ぎ、運用の継続性を確保。

### 退避（アーカイブ）システム

完了コマンド・古いレポート・解決済みダッシュボードセクションは削除せず `logs/archive/YYYY-MM-DD/` に退避。`scripts/extract-section.sh` でダッシュボードの必要セクションだけを選択的に読み込み、コンパクション復帰時のトークン消費を削減。

---

## 🗣️ SayTask — タスク管理が嫌いな人のためのタスク管理

> **⚠️ ステータス: 計画中 / Coming Soon** — SayTaskは未実装です。現在 `saytask/streaks.yaml.sample` のみ存在します（プレースホルダー）。以下は設計上の想定動作です。

### SayTaskとは？（計画中）

**タスク管理が嫌いな人のためのタスク管理。スマホに喋るだけ。**

**Talk Coding, not Vibe Coding.** タスクを喋ればAIが整理する。タイピングなし、アプリを開くことなし、摩擦なし。

- **対象者**: Todoistを入れてから3日で開かなくなった人
- 敵は他のアプリではなく「何もしないこと」。競合は別の生産性ツールではなく、惰性と怠慢
- UIゼロ。タイピングゼロ。アプリを開くことゼロ。ただ喋るだけ

### 設計イメージ

1. [ntfy アプリ](https://ntfy.sh) をインストール（無料・アカウント不要）
2. スマホに喋る: *「明日の歯医者」*、*「金曜に請求書を送る」*
3. AIが自動整理 → 朝の通知: *「今日やること」*

```
 🗣️ 「牛乳買う、明日歯医者、金曜に請求書を送る」
       │
       ▼
 ┌──────────────────┐
 │  ntfy → 将軍     │  AIが自動分類・日時解析・優先度設定
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐
 │   tasks.yaml     │  構造化保存（ローカル、端末外に出ない）
 └────────┬─────────┘
          │
          ▼
 📱 朝の通知:
    「今日: 🐸 請求書 · 🦷 歯医者15時 · 🛒 牛乳」
```

### SayTask vs cmd パイプライン

Bakuhuには2つの補完的なタスクシステムがある（SayTaskは計画中・未実装）：

| 機能 | SayTask（音声レイヤー） | cmd パイプライン（AI実行） |
|------|:-:|:-:|
| 音声入力 → タスク作成 | 🔜 計画中 | — |
| 朝の通知ダイジェスト | 🔜 計画中 | — |
| 蛙を食べろ 🐸 選択 | 🔜 計画中 | — |
| 連続達成日数トラッキング | 🔜 計画中 | 🔜 計画中 |
| AIが実行するタスク（複数ステップ） | — | ✅ |
| 複数エージェント並列実行 | — | ✅ |

SayTaskは個人の生産性管理（キャプチャ→スケジュール→リマインド）を担当。cmdパイプラインは複雑な作業（調査・コーディング・複数ステップ）を担当。

---

## アーキテクチャ

### エージェント一覧

| エージェント | 役割 | モデル | 数 |
|-------------|------|--------|-----|
| **将軍（Shogun）** | 総大将 — あなたの命令を受け、家老に委譲 | Opus | 1 |
| **家老（Karo）** | 管理者 — タスクを分解・割当、ダッシュボード管理 | Opus | 1 (+控え1) |
| **足軽（Ashigaru）** | ワーカー — タスクを並列実行 | Sonnet/Opus | 3〜8（設定可） |
| **伝令（Denrei）** | 使者 — 外部エージェントを召喚・中継 | Haiku | 2 |
| **忍び（Shinobi）** | 諜報員 — 調査・ウェブ検索・大規模文書分析 | Gemini | 外部 |
| **客将（Kyakusho）** | 参謀 — 深い推論・設計判断・コードレビュー | Codex | 外部 |

### Agent Team（Claude Code サブエージェント / Agent SDK）

上記のtmux階層エージェントとは別に、**Claude Code のサブエージェント機能**を使った Agent Team も利用可能。これらはtmuxペインではなく、Claude Codeプロセス内でサブプロセスとして動作する。

エージェント定義は `agents/default/` に配置されており（Claude Agent SDK構造: `agent.yaml` + `system.md`、fork元 [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) より移植）、追加のAgent SDK対応ランタイムにも拡張可能。

| エージェント | 役割 | モデル | 権限 |
|-------------|------|--------|------|
| **奉行（Bugyo）** | タスク統括官 — タスク分解・チーム調整・品質確認。コード実装は行わず、足軽に委譲 | inherit | 全ツール（委譲モード） |
| **足軽（Ashigaru）** | 実装ワーカー — コード実装・テスト・デバッグ。品質基準: `ruff check + format + pytest` | Sonnet | 全ツール |
| **御意見番（Goikenban）** | 批評家 — 実装の問題点・セキュリティリスク・エッジケースを厳しく指摘。読み取り専用（Write/Edit不可）。Critical / Warning / Suggestion の3段階で報告 | Sonnet | Read, Grep, Glob, Bash |
| **目付（Metsuke）** | UI確認専門官 — ブラウザで実際にページを開き、スクリーンショット・クリック・遷移・再生の動作確認。コード修正権限なし、確認・報告専任 | Sonnet | ブラウザ（Playwright）、Read、Grep、Glob |

**ワークフロー:**
1. 奉行がタスクを受ける → サブタスクに分解 → TaskListを作成
2. 奉行が足軽（実装）と御意見番（レビュー）をTaskツールで生成
3. 足軽が割当タスクを並列実行
4. 御意見番が全変更をレビュー
5. Critical問題発見 → 足軽が修正 → 再レビューサイクル
6. 全Critical解決 → 奉行が完了報告

**tmux階層との違い:**
- **tmux階層**: 長期稼働、YAMLファイルで連携、tmuxペインに表示（将軍/家老/足軽/伝令）
- **Agent Team**: タスクスコープで生成、Claude CodeのTask/SendMessageツールで連携、タスク期間のみ存在

### 通信プロトコル

- **下向き**（命令）: YAML書き込み → `tmux send-keys` でターゲットを起こす（またはメールボックスシステム）
- **上向き**（報告）: YAMLのみ（send-keysなし — あなたの入力を中断しないため）
- **外部エージェント**: 必ず伝令経由（直接召喚禁止）
- **ポーリング**: 禁止。イベント駆動のみ。APIコストが予測可能なまま。

### North Star（cmdの北極星）

将軍がcmdを発令する際、**`north_star` フィールドは必須**です。このcmdが事業目標にどう貢献するかを1〜2文で記述します。

```yaml
# queue/shogun_to_karo.yaml
cmd_id: cmd_462
project: bakuhu
north_star: >
  context/{project}.md を事業目標の権威あるソースとして確立し、
  全cmdを計測可能なビジネス成果に紐付ける。
purpose: "bakuhuプロジェクト用のbakuhu.mdコンテキストファイルを作成"
```

`north_star` は `context/{project}.md` のNorth Starセクション（プロジェクトの根本的な存在意義）から導出する。エージェントが優先順位・スコープ・トレードオフの判断を迫られた際、`north_star` が判断の軸になる。

**品質基準:**
- ✅ **良い例**: 「将軍の反射行動を構造的に防止し、事業目標に基づく判断を全cmdに強制する」
- ❌ **悪い例**: 「システムをより良くする」← 抽象的すぎて判断材料にならない

### 🔒 Identity分離v3（ロールベースアクセス制御）

各エージェントが「なりすまし」や「越権操作」をできないようにする、多層防御セキュリティ機構。**Claude Code PreToolUseフック**によりツール呼び出しレベルで強制。慣例ではない。

#### Identity解決

全エージェントのIdentityは **tmux pane ID** から `config/pane_role_map.yaml` 経由で解決される — MEMORY.mdや任意のユーザー書き込み可能な変数からではない。これによりセッション間のIdentity汚染を防止（2026-02-20検出の致命的バグ対策）。

```
セッション起動（shutsujin_departure.sh）
    ↓
pane_role_map.yaml を生成: { %0: shogun, %1: karo, %2: ashigaru, ... }
sha256sum を記録 → pane_role_map.yaml.sha256
hook_common.sh を読み取り専用に設定（chmod 444）
    ↓
全ツール呼び出し（PreToolUseフック）:
    get_role() → tmux pane ID → pane_role_map.yaml → ロール
    ロール別制限を適用 → exit 0（許可）または exit 2（拒否）
```

#### 2層フック防御

各ロールに2つの専用フックがある：**Bash実行ガード**と**ファイル書き込みガード**。

| フック | 防御対象 |
|--------|---------|
| `shogun-guard.sh` / `shogun-write-guard.sh` | 将軍がソースコードを読み書きすること（委譲のみ） |
| `karo-guard.sh` / `karo-write-guard.sh` | 家老が実装コマンドを実行すること（python・pytest・npm・ruff） |
| `ashigaru-write-guard.sh` | 足軽がシステム設定・指示書・他ロールのメモリを編集すること |
| `denrei-write-guard.sh` | 伝令がソースコードを書くこと（使者は自分のレーンを守る） |
| `global-guard.sh` | **全ロール共通**: 破壊的操作（rm -rf・git push --force・sudo・kill・curl\|bash等） |

#### メモリ分離

各ロールは自分のメモリファイルのみ読み書き可能。他ロールへの書き込みはwrite-guardフックがブロック。

| ロール | メモリファイル | 書き込み権限 |
|--------|-------------|-------------|
| 将軍 | `memory/shogun.md` | 将軍のみ |
| 家老 | `memory/karo.md` | 家老のみ |
| 足軽 | `memory/ashigaru.md` | 足軽のみ |
| 伝令 | `memory/denrei.md` | 伝令のみ |

`MEMORY.md`（全セッションに自動注入）には**ロール→メモリファイルのルックアップテーブルのみ**が記載される。Identity情報は一切書かない。

#### 起動時セルフテスト

`scripts/selftest_hooks.sh` がセッション起動時にフックシステムを自動検証：
- 全フックファイルが正しい実行権限で存在すること
- `hook_common.sh`（共有フックライブラリ）のSHA-256整合性
- 全ポリシーYAMLのJSON Schemaバリデーション
- ゼロトレランス: 1つでも失敗するとセッションをブロック

### 🧭 設計思想

#### なぜ階層構造（将軍→家老→足軽）なのか

1. **即座の応答**: 将軍は即座に委譲し、あなたに制御を返す
2. **並列実行**: 家老が複数の足軽に同時分配
3. **単一責任**: 各役割が明確に分離され、混乱しない
4. **スケーラビリティ**: 足軽を増やしても構造が崩れない
5. **障害分離**: 1体の足軽が失敗しても他に影響しない
6. **集約報告**: 将軍のみがあなたと対話し、情報を整理して提供

#### なぜメールボックスシステムか

| 直接メッセージングの問題 | メールボックスによる解決 |
|------------------------|------------------------|
| エージェントがクラッシュ → メッセージ消失 | YAMLファイルは再起動後も残る |
| ポーリングがAPIコールを無駄遣い | `inotifywait` はイベント駆動（待機中CPU 0%） |
| エージェントが互いを中断 | 各エージェントに専用inboxファイル — クロストークなし |
| デバッグが困難 | 任意の `.yaml` ファイルを開けばメッセージ履歴が見える |
| 並列書き込みでデータ破損 | `flock`（排他ロック）が書き込みを自動シリアライズ |
| 文字化けや配信ハング | メッセージ内容はファイルに残る — tmuxには短い起床通知のみ |

#### なぜ家老だけが dashboard.md を更新するのか

1. **単一書き込み者**: 更新を1エージェントに限定し、競合を防止
2. **情報集約**: 家老は全足軽の報告を受け取るため、全体像を把握している
3. **一貫性**: すべての更新が単一の品質ゲートを通過
4. **中断防止**: 将軍が更新すると、あなたの入力を中断する可能性がある

---

## 🧠 モデル設定

| エージェント | モデル | 思考モード | 役割 |
|-------------|--------|----------|------|
| 将軍 | Opus | **有効（高）** | 殿の戦略顧問。レイモードのみにするには `--shogun-no-thinking` |
| 家老 | Opus | 有効 | タスク分配・品質ゲート・ダッシュボード管理 |
| 足軽 1〜N | Sonnet / Opus | 有効 | 実装: コード・調査・ファイル操作 |
| 伝令 1〜2 | Haiku | 無効 | 中継タスクのみ — ステートレス使者 |

### 陣形モード

| 陣形 | 足軽 | コマンド |
|------|------|---------|
| **平時の陣**（デフォルト） | Sonnet | `./shutsujin_departure.sh` |
| **決戦の陣**（全力） | Opus | `./shutsujin_departure.sh -k` |

平時はSonnetモデルで運用。ここぞという時に `-k`（`--kessen`）で全軍Opusの「決戦の陣」に切り替え。家老が `/model opus` を送れば個別の足軽を一時昇格させることも可能。

### タスク依存関係（blockedBy）

タスクは `blockedBy` を使って他タスクへの依存を宣言できます：

```yaml
# queue/tasks/ashigaru2.yaml
task:
  task_id: subtask_010b
  blockedBy: ["subtask_010a"]  # 足軽1のタスク完了を待つ
  description: "subtask_010aで構築したAPIクライアントを統合"
```

ブロック元のタスクが完了すると、家老が自動的に依存タスクのブロックを解除し、空いている足軽に割り当てます。

---

## 🧭 核心思想

> **「脳死で依頼をこなすな。最速×最高のアウトプットを常に念頭に置け。」**

Bakuhuシステムは5つの核心原則に基づいて設計されている：

| 原則 | 説明 |
|------|------|
| **自律陣形設計** | テンプレートではなく、タスクの複雑さに応じて陣形を設計 |
| **並列化** | サブエージェントを活用し、単一障害点を作らない |
| **リサーチファースト** | 判断の前にエビデンスを探す |
| **継続的学習** | モデルの知識カットオフだけに頼らない |
| **三角測量** | Claude・Gemini・Codexの複数視点からリサーチして統合 |

---

## スキル

デフォルトではスキルは含まれていません。スキルは運用の中から有機的に生まれます — `dashboard.md` に提案が現れたら、殿（あなた）が承認を判断します。

スキルの呼び方: `/skill-name`。将軍に「/skill-nameを実行せよ」と伝えるだけ。

### スキルシステム

`skills/` ディレクトリには、エージェントが必要に応じて読み込むモジュール化された知識ファイルが収録されています。これらは**スラッシュコマンドではなく参照ドキュメント**です — エージェントがドメイン知識を得るために読み込みます。

**組み込みスキルファイル（主要なもの）:**

| スキルファイル | 用途 |
|-------------|------|
| `bloom-routing.md` | Bloom分類 L1-L6 モデルルーティングルール |
| `context-health.md` | /compactテンプレート、混合戦略 |
| `identity-management.md` | Identity分離設計、tmuxペイン解決 |
| `shinobi-manual.md` | 忍び（Gemini）能力・召喚プロトコル |
| `spec-before-action.md` | 仕様先行の原則（全エージェント必読） |
| `bugyo-workflow.md` | Agent Team（奉行）ワークフロー |
| `karo-workflow-steps.md` | 家老ワークフロー詳細手順 |
| `ashigaru-workflow-steps.md` | 足軽ワークフロー詳細手順 |
| `external-agent-rules.md` | 外部エージェント召喚ルール |
| `skill-candidate-flow.md` | スキル候補提案・昇格フロー |

**将軍向けスキル**（`skills/` 内のディレクトリ形式、fork元 [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) より移植）:

| スキル | 内容 |
|-------|------|
| `shogun-agent-status/` | 全エージェント状態を一括確認 |
| `shogun-bloom-config/` | Bloomルーティング設定変更 |
| `shogun-model-list/` | エージェント別利用可能モデル一覧 |
| `shogun-model-switch/` | 運用中のモデル切り替え |
| `shogun-readme-sync/` | READMEを最新変更に同期 |
| `shogun-screenshot/` | スクリーンショット撮影・分析（Pythonヘルパー付き） |

### スキルの思想

**1. ユーザー作成スキルはリポジトリにコミットしない**

`.claude/commands/` 内のスキルは意図的にバージョン管理から除外：
- 全ユーザーのワークフローはそれぞれ異なる
- 汎用スキルを押し付けるのではなく、各ユーザーが自分のスキルセットを育てる

**2. スキルの発見方法**

```
足軽が作業中にパターンに気づく
    ↓
dashboard.md の「スキル候補」に掲載
    ↓
殿（あなた）が提案をレビュー
    ↓
承認されたら家老にスキル作成を指示
```

スキルはユーザー主導。自動作成は管理不能な肥大化を招く — 本当に役立つものだけ残す。

---

## テスト基盤

> fork元 [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) より移植。

Bakuhuにはシステム動作とエージェント連携をカバーする包括的なテストスイートが付属しています。

### E2Eテストフレームワーク（`tests/e2e/`）

エンドツーエンドテストは **bats**（Bash自動テストシステム）と、実際のAPIコールなしにエージェント動作を再現するモックCLIレイヤーで構成されています：

| テストスイート | カバー範囲 |
|-------------|----------|
| `e2e_basic_flow.bats` | 将軍 → 家老 → 足軽 の基本フロー |
| `e2e_parallel_tasks.bats` | 複数の足軽による並列実行 |
| `e2e_bloom_routing.bats` | Bloom分類による自動モデルルーティング |
| `e2e_inbox_delivery.bats` | メールボックスシステムのメッセージ配信 |
| `e2e_escalation.bats` | 3フェーズエスカレーション（通知 → escape → /clear） |
| `e2e_redo.bats` | セッションリセット付きタスクやり直しプロトコル |
| `e2e_clear_recovery.bats` | /clear後のエージェント復帰 |
| `e2e_blocked_by.bats` | タスク依存（blockedBy）のブロック解除 |
| `e2e_codex_startup.bats` | Codex CLI（客将）起動シーケンス |

モックCLI（`tests/e2e/mock_cli.sh`）が `claude`・`gemini`・`codex` コマンドをインターセプト。エージェント動作は `tests/e2e/mock_behaviors/` で定義。

### ユニットテスト（`tests/unit/`）

| テスト | カバー範囲 |
|-------|----------|
| `test_dynamic_model_routing.bats` | Bloomルーティング判定ロジック |
| `test_inbox_write.bats` | inbox_write.sh の正確性とflock動作 |
| `test_idle_flag.bats` | エージェントアイドルフラグのライフサイクル |
| `test_ntfy_ack.bats` | ntfy確認応答フロー |
| `test_stop_hook.bats` | PreToolUseフックのブロック動作 |
| `test_switch_cli.bats` | CLI切り替え（claude ↔ codex ↔ gemini） |
| `test_build_system.bats` | ビルドシステムの正確性 |

### テスト実行

```bash
# E2Eテスト全実行
bats tests/e2e/

# ユニットテスト全実行
bats tests/unit/

# 特定スイートのみ
bats tests/e2e/e2e_basic_flow.bats
```

---

## Androidアプリ

> fork元 [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) より移植。

BakuhuにはSSH/Termuxアプローチを超えた、モバイル指揮・監視のためのネイティブAndroidアプリが付属しています。

### 機能

- **Kotlin + Jetpack Compose** — モダンなAndroidアーキテクチャ
- **SSH経由でtmuxに接続** — 稼働中のBakuhuセッションに直接接続
- **ntfy通知連携** — タスク完了時のリアルタイムプッシュ通知
- **5画面構成**: エージェントグリッド、ダッシュボード表示、コマンド入力、設定、レート制限状態

### スクリーンショット

| 将軍ターミナル | エージェントグリッド | ダッシュボード | 設定 | レート制限 |
|:-:|:-:|:-:|:-:|:-:|
| ![将軍](android/screenshots/01_shogun_terminal.png) | ![エージェント](android/screenshots/02_agents_grid.png) | ![ダッシュボード](android/screenshots/03_dashboard.png) | ![設定](android/screenshots/04_settings.png) | ![レート](android/screenshots/05_ratelimit.png) |

### インストール

ビルド済みAPKが `android/release/` に収録されています。Androidデバイスにサイドロード：

1. Android設定で「不明なソースからのインストール」を有効化
2. APKをスマホに転送
3. インストール後、TailscaleのIPとSSH認証情報を設定

---

## MCP セットアップガイド

MCP（Model Context Protocol）サーバーがClaudeの能力を拡張します。セットアップ方法：

### MCPとは？

MCPサーバーがClaudeに外部ツールへのアクセスを付与：
- **Notion MCP** → Notionページの読み書き
- **GitHub MCP** → PRの作成、イシュー管理
- **Memory MCP** → セッションを跨ぐ記憶の永続化
- **Playwright MCP** → ブラウザ自動操作（目付のUI確認に使用）

### MCPサーバーのインストール

以下のコマンドでMCPサーバーを追加：

```bash
# 1. Notion - Notionワークスペースに接続
claude mcp add notion -e NOTION_TOKEN=your_token_here -- npx -y @notionhq/notion-mcp-server

# 2. Playwright - ブラウザ自動操作（目付のUI確認に必要）
claude mcp add playwright -- npx @playwright/mcp@latest
# 注意: 先に `npx playwright install chromium` を実行すること

# 3. GitHub - リポジトリ操作
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat_here -- npx -y @modelcontextprotocol/server-github

# 4. Sequential Thinking - 複雑な問題のステップバイステップ推論
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# 5. Memory - セッションを跨ぐ長期記憶（推奨！）
# ✅ first_setup.sh が自動設定
# 手動で再設定する場合:
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/shogun_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory
```

### インストール確認

```bash
claude mcp list
```

全サーバーが「Connected」になっていればOK。

---

## 実際のユースケース

このシステムはコードだけでなく、**すべてのホワイトカラー業務**を管理できます。プロジェクトはファイルシステム上のどこにでも置けます。

### 例1: リサーチスプリント

```
あなた: 「AIコーディングアシスタント上位5つを調査して比較せよ」

実際の動き:
1. 将軍が家老に委譲
2. 家老が割当:
   - 足軽1: GitHub Copilotを調査
   - 足軽2: Cursorを調査
   - 足軽3: Claude Codeを調査
   - 伝令1 → 忍び: Geminiでウェブ検索（Codeium + CodeWhisperer）
3. 全エージェントが同時に調査開始
4. 結果が dashboard.md に集約
```

### 例2: 外部知性を使ったPoC準備

```
あなた: 「このNotionページのプロジェクトのPoCを準備せよ: [URL]」

実際の動き:
1. 家老がMCP経由でNotionの内容を取得
2. 足軽2: 確認すべき事項をリストアップ
3. 足軽3: 技術的実現可能性を調査
4. 伝令 + 忍び: 未知の技術をGeminiでディープリサーチ（100万トークン文脈）
5. 伝令 + 客将: アーキテクチャレビューと設計提案
6. 全結果が dashboard.md に集約 — 打ち合わせ準備完了
```

### 例3: レビュー付きフルスタック機能開発

```
あなた: 「ユーザー認証のRESTエンドポイントをテスト込みで追加せよ」

実際の動き:
1. 家老が奉行（Agent Teamモード）を派遣
2. 奉行が分解: 仕様 → 実装 → テスト → レビュー
3. 足軽が機能を実装
4. 御意見番がレビュー: セキュリティリスク・エッジケース・完成度
5. Critical問題があれば修正 → 再レビュー
6. 目付がブラウザでUI動作を確認
7. 奉行が完了報告
```

---

## 設定

### 言語

```yaml
# config/settings.yaml
language: ja   # 侍語（日本語）のみ
language: en   # 侍語 + 英語翻訳
```

### スクリーンショット連携

```yaml
# config/settings.yaml
screenshot:
  path: "/mnt/c/Users/あなたの名前/Pictures/Screenshots"
```

将軍に「最新のスクショを確認せよ」と伝えると、視覚的なコンテキストを読み取って分析します。（Windowsでは `Win+Shift+S`）

### ntfy（スマホ通知）

```yaml
# config/settings.yaml
ntfy_topic: "shogun-yourname"
```

スマホの [ntfy アプリ](https://ntfy.sh) で同じトピックを購読。`shutsujin_departure.sh` がリスナーを自動起動。

### 外部エージェント

```yaml
# config/settings.yaml
external_agents:
  shinobi: true    # Gemini CLI 連携を有効化
  kyakusho: true   # Codex CLI 連携を有効化
```

GeminiおよびCodex CLIが別途インストール済みであること。

---

## Advanced

<details>
<summary><b>shutsujin_departure.sh オプション</b>（クリックで展開）</summary>

```bash
# デフォルト: フル起動（tmuxセッション + Claude Code起動）
./shutsujin_departure.sh

# セッション作成のみ（Claude Code起動なし）
./shutsujin_departure.sh -s
./shutsujin_departure.sh --setup-only

# タスクキューをクリア（コマンド履歴は保持）
./shutsujin_departure.sh -c
./shutsujin_departure.sh --clean

# 決戦の陣: 全足軽をOpusに（最大能力・高コスト）
./shutsujin_departure.sh -k
./shutsujin_departure.sh --kessen

# サイレントモード: 雄叫びなし（echoコールのAPIトークンを節約）
./shutsujin_departure.sh -S
./shutsujin_departure.sh --silent

# 将軍レイモード: 将軍の思考を無効化（コスト節約）
./shutsujin_departure.sh --shogun-no-thinking

# ヘルプを表示
./shutsujin_departure.sh -h
./shutsujin_departure.sh --help
```

</details>

<details>
<summary><b>コンテキスト健康確認コマンド</b>（クリックで展開）</summary>

```bash
# 家老のコンテキスト使用率を確認（将軍から実行）
bash scripts/check_context.sh karo

# 特定の足軽を確認
bash scripts/check_context.sh ashigaru1

# エージェントをコンパクト（スクリプト経由、直接入力は禁止）
bash scripts/run_compact.sh karo
bash scripts/run_compact.sh ashigaru1
```

**重要:** コンテキスト測定は外部から行う（将軍が家老を測定、家老が足軽を測定）。自己測定は不正確なため禁止。

</details>

---

## ファイル構成

<details>
<summary><b>クリックで展開</b></summary>

```
multi-agent-bakuhu/
│
│  ┌──────────────── セットアップスクリプト ──────────────┐
├── first_setup.sh            # 初回セットアップ（設定・依存関係・MCP）
├── shutsujin_departure.sh    # 毎日の起動（エージェント指示書を自動ロード）
│  └─────────────────────────────────────────────────┘
│
├── instructions/             # エージェント指示書
│   ├── shogun.md             # 将軍（戦略アドバイザー）
│   ├── karo.md               # 家老（チーフオブスタッフ）
│   ├── ashigaru.md           # 足軽（実装ワーカー）
│   ├── kyakusho.md           # 客将（外部エージェント: Codex CLI）
│   ├── shinobi.md            # 忍び（スカウト: Gemini）
│   ├── denrei.md             # 伝令（メッセンジャー）
│   ├── metsuke.md            # 目付（UI確認: Playwright）
│   ├── cli_specific/         # CLI別ツール説明
│   └── generated/            # 他CLI向け指示書バリアント（Codex/Copilot/Kimi等）
│                              # bakuhuでは現在未使用（Claude Code専用）
│                              # 他CLI導入時は同ファイルにも修正を反映すること
│                              # upstream（yohey-w/multi-agent-shogun）由来・編集禁止
│
├── scripts/                  # ユーティリティスクリプト
│   ├── inbox_write.sh        # エージェントinboxへのメッセージ書き込み
│   ├── inbox_watcher.sh      # inotifywaitによるinbox監視
│   ├── check_context.sh      # エージェントコンテキスト使用率計測（外部から実行）
│   ├── run_compact.sh        # エージェントへの/compact実行
│   ├── ntfy.sh               # スマホへのプッシュ通知送信
│   ├── ntfy_listener.sh      # スマホからのメッセージ受信
│   ├── agent_status.sh       # 全エージェント状態を一括確認
│   ├── switch_cli.sh         # 使用CLI切り替え（claude/codex/gemini）
│   ├── ratelimit_check.sh    # APIレート制限状態確認
│   └── kill_playwright.sh    # Playwright MCPプロセス停止
│
├── config/
│   ├── settings.yaml         # 言語・ntfy・エージェント設定
│   └── projects.yaml         # プロジェクト一覧
│
├── context/                  # プロジェクト北極星ファイル（cmd YAMLから参照）
│   └── {project}.md          # プロジェクト別の目的・事業背景・north_star
│
├── queue/                    # 通信・タスクファイル
│   ├── shogun_to_karo.yaml   # 将軍 → 家老 命令
│   ├── inbox/                # エージェント別inboxファイル
│   │   ├── karo.yaml
│   │   └── ashigaru{1-N}.yaml
│   ├── tasks/                # 足軽別タスクYAML
│   ├── reports/              # 足軽報告YAML
│   ├── kyakusho/             # 客将（Codex）タスクキュー
│   ├── shinobi/              # 忍び（Gemini）タスクキュー
│   ├── denrei/               # 伝令タスクキュー
│   └── 殿/                   # 殿への報告・文書
│
├── skills/                   # モジュール化された知識ファイル（エージェントが必要時に読み込み）
│   ├── bloom-routing.md      # Bloom分類 L1-L6 モデルルーティング
│   ├── context-health.md     # /compactテンプレート、混合戦略
│   ├── identity-management.md# Identity分離設計
│   ├── spec-before-action.md # 仕様先行の原則（全エージェント必読）
│   ├── shinobi-manual.md     # 忍び（Gemini）能力・プロトコル
│   ├── shogun-agent-status/  # エージェント状態確認スキル
│   ├── shogun-screenshot/    # スクリーンショット取得スキル（Pythonヘルパー付き）
│   └── generated/            # 開発プロジェクトスキル（git管理外）
│
├── tests/                    # テストスイート
│   ├── e2e/                  # E2Eテスト（bats + モックCLI）
│   │   ├── mock_cli.sh       # claude/codex/geminiのモック
│   │   ├── mock_behaviors/   # CLIごとのモック動作定義
│   │   ├── fixtures/         # テストフィクスチャ
│   │   └── helpers/          # テストヘルパー（アサーション・tmux・セットアップ）
│   └── unit/                 # ユニットテスト（bats）
│
├── android/                  # Androidアプリ（Kotlin + Jetpack Compose）
│   ├── app/                  # アプリソースコード
│   ├── release/              # ビルド済みAPK
│   └── screenshots/          # アプリスクリーンショット
│
├── agents/                   # Agent SDK定義
│   └── default/              # デフォルトエージェント（agent.yaml + system.md）
│
├── .claude/                  # Claude Code設定
│   ├── hooks/                # ツール前後フック（gitignore guardian等）
│   ├── agents/               # サブエージェント定義（bugyo・goikenban等）
│   ├── rules/                # プロジェクトルール（ディレクトリ自動ロード）
│   └── commands/             # スラッシュコマンド
│
├── logs/                     # エージェントログ
├── memory/                   # Memory MCP永続ストレージ
├── projects/                 # プロジェクト詳細（git管理外・機密情報を含む場合あり）
├── dashboard.md              # リアルタイム状況ボード（家老が管理）
└── CLAUDE.md                 # システム指示書（Claude Codeが自動ロード）
```

</details>

---

## トラブルシューティング

<details>
<summary><b>エージェントがinboxメッセージに反応しない</b></summary>

inbox_watcherのエスカレーションシステムが自動対処します：

| 経過時間 | アクション |
|---------|-----------|
| 0〜2分 | 標準 `tmux send-keys` ナッジ |
| 2〜4分 | Escape×2 + ナッジ（カーソル位置バグの回避策） |
| 4分以上 | `/clear` 送信（強制セッションリセット、5分に1回まで） |

手動確認: `cat queue/inbox/{agent}.yaml`

</details>

<details>
<summary><b>コンテキスト溢れ — エージェントが遅い・タスク拒否</b></summary>

```bash
# コンテキスト計測（外部から実行 — 自己測定は不正確なため禁止）
bash scripts/check_context.sh karo
bash scripts/check_context.sh ashigaru1

# compact実行（将軍が家老に、家老が足軽に）
bash scripts/run_compact.sh karo
```

閾値: 60% → タスク完了後にcompact; 85%以上 → 即時 `/clear`

</details>

<details>
<summary><b>hookがファイル操作を予期せずブロックする</b></summary>

`.claude/hooks/` のhookは `.gitignore` 書き込み保護などのルールを強制します。正当な操作がブロックされた場合は殿に明示的な許可を求めてください。許可なしのhookバイパスは禁止です。

</details>

<details>
<summary><b>Identity汚染 — 再起動後にエージェントが誤ったロールを名乗る</b></summary>

全エージェントが同じロールを名乗る場合：

```bash
# 各エージェントのidentity確認
tmux display-message -t multiagent:agents.0 -p '#{@agent_id}'  # karo
tmux display-message -t multiagent:agents.1 -p '#{@agent_id}'  # ashigaru1
```

根本原因: MEMORY.mdまたはMemory MCP graphにidentity情報が書かれていた（全エージェントで共有されるため）。共有永続ストレージにロール・identity情報を書くことは絶対禁止。回復手順はCLAUDE.md「セッション開始/回復」を参照。

</details>

<details>
<summary><b>Playwright MCPツールがロードされない</b></summary>

Playwright MCPツールは遅延ロードです。`ToolSearch`後もツールが使えない場合は Claude Code を再起動してください。MCPは `.mcp.json` で定義されています。

</details>

---

## tmux クイックリファレンス

| コマンド | 説明 |
|---------|------|
| `tmux attach -t shogun` | 将軍セッションに接続 |
| `tmux attach -t multiagent` | マルチエージェントセッションに接続 |
| `Ctrl+B` → `0` | 家老ペイン |
| `Ctrl+B` → `1`〜`N` | 足軽1〜Nペイン |
| `Ctrl+B` → `d` | デタッチ（エージェントはバックグラウンドで稼働継続） |
| `Ctrl+B` → `[` | スクロールモード（Escで終了） |

### マウスサポート

`first_setup.sh` が `~/.tmux.conf` に `set -g mouse on` を設定します：

| 操作 | 説明 |
|------|------|
| マウスホイール | ペイン内スクロール |
| ペインをクリック | ペイン間でフォーカス切替 |
| ペインボーダーをドラッグ | ペインサイズ変更 |

---

## コントリビューション

IssueとPull Requestを歓迎します。

- **バグ報告**: 再現手順を含めてIssueを開いてください
- **機能アイデア**: まずDiscussionで議論を
- **スキル**: スキルは個人設計のため `skills/generated/` はgit管理外です
- **開発**: Fork → ブランチ → `main` へPR

## クレジット

- **原作**: [Akira-Papa氏](https://github.com/Akira-Papa/Claude-Code-Communication) の Claude-Code-Communication
- **フォーク元**: [yohey-w氏](https://github.com/yohey-w/multi-agent-shogun) の multi-agent-shogun
- **本リポジトリ**: [multi-agent-bakuhu](https://github.com/yaziuma/multi-agent-bakuhu) — Bakuhu拡張機能: コンテキスト健康管理・Identity分離v3・外部エージェント（忍び/客将）・North Star

## ライセンス

[MIT](LICENSE)

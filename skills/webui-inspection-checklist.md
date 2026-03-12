# Web UI 自動テストエージェント向け総合品質検査チェックリスト (Playwright版)

## 序文

このチェックリストは、Playwright を利用する自動テストエージェントが、Webアプリケーションの品質を包括的に検証するために使用します。過去の失敗事例（要素の存在確認のみでインタラクションを検証しない）を教訓とし、本リストは**静的な存在確認**だけでなく、**動的な振る舞いと状態変化の検証**に重点を置いています。

各項目は、Playwright MCP (Multi-Modal Control Plane) ツールセット（`browser_navigate`, `browser_click`, `browser_snapshot`, `browser_take_screenshot`, `browser_type`, `browser_evaluate`など）の利用を前提としています。

---

## Level別チェック項目分類

UIテストは以下の3段階で優先度を分類する。**Level 1を満たさない実装はリリース不可**。

### Level 1（最低限守るべき・必須）

| 対象 | 該当セクション |
| :--- | :--- |
| 要素の存在と可視性確認 | セクション 1 |
| クリック後の状態変化確認 | セクション 2, 3 |
| フォームバリデーション | セクション 6 |
| APIエラー時のエラー表示 | セクション 8 |
| 未認証時の認証リダイレクト | セクション 12 |
| XSSインジェクション防止 | セクション 12 |

### Level 2（UX品質）

| 対象 | 該当セクション |
| :--- | :--- |
| ローディングスピナー表示・消滅 | セクション 5 |
| トースト通知の表示・消滅 | セクション 5 |
| レスポンシブレイアウト | セクション 10 |
| 空状態（Empty State）の表示 | セクション 7 |
| ページネーション・検索 | セクション 7 |
| ナビゲーション遷移 | セクション 4 |

### Level 3（高度品質）

| 対象 | 該当セクション |
| :--- | :--- |
| パフォーマンス計測（LCP等） | セクション 11 |
| コントラスト比（WCAG 2.2） | セクション 9 |
| CSRFトークン・Cookie属性 | セクション 12 |
| Visual Regression | セクション 14 |
| ネットワーク観測 | セクション 13 |
| テスト独立性確保 | セクション 15 |

---

## やりがちな間違い (Common Mistakes to Avoid)

- **クリックしない存在確認**: `expect(locator).toBeVisible()`だけで満足し、`browser_click()`を実行してその後の変化を見ない。インタラクションの結果（例：モーダルが開く、テキストが更新される）まで検証することが必須。
- **アニメーションを待たないスクリーンショット**: `browser_click()`直後に`browser_take_screenshot()`を撮ってしまい、遷移中の不完全なUIをキャプチャする。PlaywrightのAuto-Waiting機能を活用するか、状態が安定したことを示す特定の要素（例：ローディング完了後のデータ）を待つことが不可欠。
- **スクロール不足**: 要素がビューポート外にある場合、Playwrightは自動でスクロールを試みるが、複雑なレイアウトでは失敗することがある。`locator.scrollIntoViewIfNeeded()`を明示的に呼び出し、操作対象を確実に見える位置に移動させる。
- **インタラクション後の状態未検証**: ボタンをクリックした後、ローディングスピナーが表示され、データが更新され、スピナーが消える、という一連の状態変化をステップバイステップで追跡・検証しない。各状態でのスクリーンショットやアサーションが重要。
- **アクセシビリティツリーへの依存**: `page.accessibility.snapshot()`の結果だけで満足せず、実際の`browser_take_screenshot()`による視覚的な確認を怠る（特にフォーカスインジケーターの視認性など）。

---

## 1. 静的確認 (Static Verification)
要素が静的に正しく表示されているかを確認します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **要素の存在と可視性** | `expect(page.locator('selector')).toBeVisible()` | 対象要素がレンダリングされ、ビューポート内で非表示（`display:none`, `visibility:hidden`等）になっていないこと。 | **必須** |
| **テキスト内容の一致** | `expect(page.locator('h1')).toHaveText('期待される見出し')` | 完全一致または部分一致で、指定されたテキストが表示されていること。正規表現も活用する。 | **必須** |
| **属性値の検証** | `expect(page.locator('a')).toHaveAttribute('href', '/expected-path')` | `href`, `src`, `alt`, `data-*`などの属性が期待通りの値を持っていること。 | **必須** |
| **CSSプロパティの適用** | `expect(locator).toHaveCSS('color', 'rgb(51, 51, 51)')` | ボタンの色、フォントサイズ、マージン等がデザイン仕様通りであること。 | 推奨 |
| **画像の読み込み成功** | `const isLoaded = await page.evaluate(el => el.complete && el.naturalWidth > 0, imageElementHandle)`<br>`expect(isLoaded).toBe(true)` | `<img>`タグの`complete`プロパティが`true`であり、`naturalWidth`が0より大きいこと。 | **必須** |

---

## 2. インタラクション確認 (Interaction Verification)
ユーザー操作に対するシステムの応答を検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **クリック/タップ** | `await browser_click(locator)`<br>`expect(newElement).toBeVisible()` | クリック後、期待される状態変化（例：モーダル表示、アコーディオン展開、データ更新）が発生すること。 | **必須** |
| **ダブルクリック** | `await locator.dblclick()`<br>`expect(editModeInput).toBeVisible()` | ダブルクリック後、期待される状態（例：テキストが編集モードになる）に遷移すること。 | 任意 |
| **ホバー** | `await locator.hover()`<br>`await expect(tooltip).toBeVisible()` | ホバー時にツールチップやメニューが規定時間内に表示され、内容が正しいこと。 | 推奨 |
| **ドラッグ＆ドロップ** | `await sourceLocator.dragTo(targetLocator)`<br>`//ドロップ後の位置やリストの順序を検証` | ドラッグ＆ドロップ操作後、要素が期待通りの位置に移動、または順序が変更されていること。 | 推奨 |
| **キーボード入力** | `await browser_type(locator, 'テスト入力')`<br>`await expect(locator).toHaveValue('テスト入力')` | 入力フィールドに入力したテキストが正しく反映されること。 | **必須** |

---

## 3. 状態遷移確認 (State Transition Verification)
操作前後のUIの状態変化を詳細に検証します。

### 標準的な非同期操作の状態遷移テンプレート

UIは状態マシンである。単発の`expect`で満足せず、**一連の遷移パターン**を追跡すること。非同期APIを伴うボタン操作の標準テンプレートは以下の通り：

```
click → spinner表示 → spinner消滅 → resultList表示 → counter更新 → toast表示 → toast消滅
```

各フェーズで必ずアサーションを置き、スクリーンショットを撮ること：

```javascript
// ① クリック前の初期状態を確認
await expect(spinner).toBeHidden();
const beforeCount = await resultList.locator('li').count();

// ② クリック実行
await browser_click(executeButton);

// ③ スピナー表示（処理開始の確認）
await expect(spinner).toBeVisible();
await browser_take_screenshot({ path: 'step1_loading.png' });

// ④ スピナー消滅（処理完了の確認）
await expect(spinner).toBeHidden({ timeout: 15000 });

// ⑤ 結果リスト更新
await expect(resultList.locator('li').first()).toBeVisible();
expect(await resultList.locator('li').count()).toBeGreaterThan(beforeCount);
await browser_take_screenshot({ path: 'step2_result.png' });

// ⑥ カウンター更新
await expect(counter).not.toHaveText(String(beforeCount));

// ⑦ トースト表示・消滅
await expect(toast).toBeVisible();
await browser_take_screenshot({ path: 'step3_toast.png' });
await expect(toast).toBeHidden({ timeout: 5000 });
```

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **DOM構造の変化** | `await browser_take_screenshot({ path: 'before.png' })`<br>`await browser_click(locator)`<br>`await expect(newElement).toBeVisible()`<br>`await browser_take_screenshot({ path: 'after.png' })` | 操作後に要素が追加/削除/変更される。スクリーンショットやスナップショットで差分を比較し、意図しない変更がないことを確認。 | **必須** |
| **CSSクラス/スタイルの変化** | `await expect(locator).toHaveClass(/initial/);`<br>`await browser_click(locator)`<br>`await expect(locator).toHaveClass(/final/);` | 操作後に`active`, `disabled`, `hidden`などのクラスが正しく付与/削除され、スタイルが変更されること。 | **必須** |
| **テキスト内容の変化** | `await expect(counter).toHaveText('0')`<br>`await browser_click(addButton)`<br>`await expect(counter).toHaveText('1')` | カウンター、ステータス表示、通知メッセージなどが操作に応じて正しく更新されること。 | **必須** |
| **数値の変化（件数、ピクセル値）** | `const beforeCount = await list.locator('li').count()`<br>`await browser_click(deleteButton)`<br>`expect(await list.locator('li').count()).toBe(beforeCount - 1)` | リストアイテムの件数、要素の高さや幅などが期待通りに変化すること。 | 推奨 |
| **非同期操作の全遷移** | 上記テンプレート参照 | click→spinner→result→counter→toast の全フェーズが正しい順序で完了すること。 | **必須** |

---

## 4. ナビゲーション確認 (Navigation Verification)
ページ間の遷移やURLの変更が正しく行われるかを検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **ページ遷移** | `await browser_click('a[href="/about"]')`<br>`await expect(page).toHaveURL(/.*\/about/)`<br>`await expect(page.locator('h1')).toHaveText('About Us')` | リンククリック後、URLが正しく変更され、遷移先ページの主要コンテンツが表示されること。 | **必須** |
| **リダイレクト** | `await browser_click(oldLink)`<br>`await page.waitForURL('**/new-path')`<br>`expect(page.url()).toContain('new-path')` | 古いURLへのアクセスが、指定された新しいURLへ正しくリダイレクトされること。 | 推奨 |
| **ブラウザの戻る/進む** | `await page.goBack()`<br>`await expect(page).toHaveURL(previousUrl)`<br>`await page.goForward()`<br>`await expect(page).toHaveURL(currentUrl)` | ブラウザの「戻る」「進む」操作で、ページの表示状態が正しく復元されること（特にフォーム入力内容）。 | 推奨 |
| **アンカーリンク** | `await browser_click('#section2-link')`<br>`// ターゲット要素がビューポート内にあるか検証` | アンカーリンククリック後、ページが指定されたセクションまでスクロールされること。 | 任意 |
| **URLパラメータの処理** | `await browser_navigate('.../search?q=test&sort=date')`<br>`// 検索結果とソート順がパラメータを反映しているか検証` | URLパラメータを付与してページにアクセスした際、そのパラメータに応じた初期状態が再現されること。 | 推奨 |

---

## 5. フィードバック確認 (Feedback Verification)
ユーザー操作に対する視覚的なフィードバックを検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **ローディング表示** | `await browser_click(submitButton)`<br>`await expect(spinner).toBeVisible()`<br>`await expect(spinner).toBeHidden({ timeout: 15000 })` | 非同期処理中、ローディングスピナーやスケルトンUIが表示され、処理完了後に非表示になること。タイムアウトも確認。 | **必須** |
| **トースト/通知** | `await browser_click(saveButton)`<br>`await expect(toast).toContainText('保存しました')`<br>`await browser_take_screenshot()`<br>`await expect(toast).toBeHidden({ timeout: 5000 })` | 操作成功/失敗時にトーストが規定時間表示され、内容が正しいこと。スクリーンショットで見た目も確認。 | **必須** |
| **エラーメッセージ** | `await browser_type(invalidInput, 'xxx')`<br>`await expect(errorMessage).toBeVisible()`<br>`await expect(errorMessage).toHaveText('無効な形式です')` | バリデーションエラー等の際、適切なエラーメッセージがユーザーに分かりやすく表示されること。 | **必須** |
| **成功メッセージ** | `await browser_click(submitButton)`<br>`await expect(successMessage).toBeVisible()` | 操作成功後、「完了しました」などのメッセージが表示され、ユーザーが次のアクションを理解できること。 | 推奨 |

---

## 6. フォーム確認 (Form Verification)
フォーム全体の入力、バリデーション、送信処理を検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **入力値バリデーション** | `await browser_type(emailField, 'invalid-email')`<br>`await browser_click(submitButton)`<br>`await expect(emailError).toBeVisible()` | 無効な形式の入力に対して、リアルタイムまたは送信時にエラーメッセージが表示されること。 | **必須** |
| **必須項目チェック** | `await browser_click(submitButton)`<br>`await expect(requiredError).toBeVisible()` | 必須項目を空のまま送信しようとした際、エラーメッセージが表示され送信がブロックされること。 | **必須** |
| **送信成功とリセット** | `// 正常値を入力`<br>`await browser_click(submitButton)`<br>`await expect(page).toHaveURL(/.*\/success/)`<br>`// またはフォームがリセットされているか確認` | 全ての入力が有効な場合、フォームが正常に送信され、サンクスページに遷移するかフォームが初期化されること。 | **必須** |
| **送信失敗時の入力保持** | `// 無効な値を一部入力して送信`<br>`await browser_click(submitButton)`<br>`await expect(validInputField).toHaveValue(validValue)` | 送信失敗時、ユーザーが入力した有効な値がフォームフィールドに保持されていること。 | 推奨 |

---

## 7. データ表示確認 (Data Display Verification)
リスト、テーブルなどの動的なデータ表示を検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **ページネーション** | `await expect(pageIndicator).toContainText('1 / 10')`<br>`await browser_click(nextButton)`<br>`await expect(pageIndicator).toContainText('2 / 10')` | 「次へ」「前へ」ボタンでデータが更新され、ページ番号表示が正しく変わること。件数表示も確認。 | **必須** |
| **ソート機能** | `await browser_click(sortHeader)`<br>`// 1列目の値を取得し、昇順になっているか検証` | テーブルヘッダーのクリックで、データが指定された列（昇順/降順）で正しくソートされること。 | 推奨 |
| **フィルタリング機能** | `await browser_click(filterDropdown)`<br>`await browser_click(filterOption)`<br>`expect(await table.locator('tr').count()).toBe(expectedCount)` | フィルタ適用後、表示されるアイテムが条件に合致し、件数が正しいこと。 | 推奨 |
| **検索機能** | `await browser_type(searchInput, '検索語')`<br>`// 表示されている全アイテムに「検索語」が含まれるか検証` | 検索実行後、結果が検索語と関連性の高いものに絞り込まれていること。 | **必須** |
| **空の状態 (Empty State)** | `// 検索結果が0件になるように検索`<br>`await expect(emptyStateMessage).toBeVisible()` | データが0件の場合、「データがありません」などのメッセージが分かりやすく表示されること。 | 推奨 |

---

## 8. エラーケース確認 (Error Cases)
予期せぬエラー発生時のシステムの挙動を検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **APIリクエスト失敗** | `await page.route('**/api/data', route => route.abort())`<br>`await browser_click(loadButton)`<br>`await expect(apiErrorDisplay).toBeVisible()` | バックエンドAPIの接続に失敗した際、アプリケーションがクラッシュせず、エラーメッセージがユーザーに表示されること。 | **必須** |
| **サーバーエラー (500)** | `await page.route('**/api/data', route => route.fulfill({ status: 500, body: 'Server Error' }))`<br>`await browser_click(loadButton)` | 500エラー受信時、ユーザーに「サーバーでエラーが発生しました」等のメッセージを通知し、リトライを促すなどの対策が取られていること。 | **必須** |
| **対象が見つからない (404)** | `await browser_navigate('/non-existent-page')`<br>`await expect(page.locator('h1')).toContainText('404')` | 存在しないページやリソースにアクセスした際、カスタム404ページが表示されること。 | 推奨 |
| **タイムアウト** | `await page.route('**/api/data', async route => { await new Promise(r => setTimeout(r, 20000)); await route.continue(); })` | API応答が遅延した場合、タイムアウト機構が働き、ユーザーに状況を通知すること。 | 推奨 |

---

## 9. アクセシビリティ確認 (Accessibility)
全てのユーザーがアプリケーションを利用できるかを検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **キーボードナビゲーション** | `await page.keyboard.press('Tab')`<br>`await expect(firstFocusableElement).toBeFocused()` | `Tab`キーで全てのインタラクティブ要素に論理的な順序でフォーカスが移動すること。`Shift+Tab`で逆順に移動すること。 | **必須** |
| **フォーカスインジケーター** | `await page.keyboard.press('Tab')`<br>`await browser_take_screenshot()` | フォーカスが当たっている要素が、視覚的に明確なスタイル（アウトラインなど）で示されていること。スクリーンショットで確認。 | **必須** |
| **ARIA属性の妥当性** | `await expect(button).toHaveAttribute('aria-label', 'メニューを開く')` | `role`, `aria-label`, `aria-describedby`などが正しく設定され、スクリーンリーダー利用者に適切な情報が伝わること。 | 推奨 |
| **コントラスト比** | `// browser_evaluateでテキストと背景色を取得し、計算するライブラリを使用`<br>`const ratio = calculateContrast(fgColor, bgColor)`<br>`expect(ratio).toBeGreaterThanOrEqual(4.5)` | テキストと背景のコントラスト比が、WCAG 2.2の基準（AAレベルで4.5:1）を満たしていること。（Level 3） | 推奨 |

---

## 10. レスポンシブ確認 (Responsive)
異なるデバイスや画面サイズで表示が崩れないかを検証します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **ビューポート変更** | `const viewports = [320, 768, 1024, 1920]`<br>`for (const width of viewports) { await page.setViewportSize({ width, height: 800 }); await browser_take_screenshot(...) }` | 主要なブレークポイントでレイアウトが崩れないこと。画像やテキストがはみ出したり、重なったりしていないこと。Visual Regression Testで自動比較。 | **必須** |
| **モバイルでのタッチ領域** | `// browser_evaluateで要素のサイズを取得`<br>`const box = await locator.boundingBox()`<br>`expect(box.width).toBeGreaterThanOrEqual(44)`<br>`expect(box.height).toBeGreaterThanOrEqual(44)` | モバイル表示時、ボタンやリンクなどのタップターゲットが最低でも44x44ピクセル以上のサイズを確保していること。 | 推奨 |
| **コンテンツのオーバーフロー** | `const hasHorizontalScroll = await page.evaluate(() => document.body.scrollWidth > document.body.clientWidth)`<br>`expect(hasHorizontalScroll).toBe(false)` | どのビューポートサイズでも、意図しない横スクロールバーが表示されないこと。 | **必須** |

---

## 11. パフォーマンス確認 (Performance)
ページの表示速度や操作の応答性が許容範囲内であるかを検証します。

> **⚠️ 測定条件の注意事項**
>
> - **ローカル環境限定**: 以下の数値基準はすべてローカル開発環境（localhost）での実行を前提とする。本番サーバーやネットワーク経由での計測には別途基準を設けること。
> - **Headless環境の不安定性**: Playwrightのheadlessモードでは、パフォーマンスAPIの値がheadedモードと異なる場合がある。計測結果にばらつきが生じやすいため、単発の数値でPass/Failを判断しないこと。3回以上の平均値を用いることを推奨。
> - **CI環境での変動警告**: CI（GitHub Actions等）での計測値はローカルより大幅に遅くなる場合がある。CI環境ではパフォーマンステストをsoftアサーション（warn only）とし、絶対的な合否判定に使用しないことを推奨。
> - **キャッシュ状態の明示**: テスト前にキャッシュをクリアするか否かを明示すること（`await context.clearCookies(); await page.evaluate(() => caches.keys().then(keys => keys.forEach(key => caches.delete(key))))`）。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **初期読み込み時間 (LCP)** | `const lcp = await page.evaluate(() => new Promise(resolve => { new PerformanceObserver(list => { const entries = list.getEntries(); const lastEntry = entries[entries.length - 1]; resolve(lastEntry.startTime); }).observe({ type: 'largest-contentful-paint', buffered: true }); }))`<br>`expect(lcp).toBeLessThan(2500)` | Largest Contentful Paint (LCP)が2.5秒以内であること。（ローカル環境・非CI） | 推奨 |
| **インタラクティブ性 (FID/INP)** | `// INPは複雑なため、TTI (Time to Interactive) を代替指標に`<br>`const tti = await page.evaluate(...)`<br>`expect(tti).toBeLessThan(5000)` | ページが操作可能になるまでの時間（TTI）が5秒以内であること。（ローカル環境・非CI） | 推奨 |
| **遅延読み込み (Lazy Loading)** | `await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight))`<br>`await expect(lazyLoadedImage).toBeVisible()` | ページ下部までスクロールした際、ビューポートに入った画像やコンテンツが遅延読み込みされること。 | 推奨 |

---

## 12. セキュリティ確認 (Security)
基本的なWebセキュリティの脆弱性がないかを確認します。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **クロスサイトスクリプティング (XSS)** | `await browser_type(input, '<script>alert("xss")</script>')`<br>`await browser_click(submitButton)`<br>`// アラートが表示されないこと、および入力がサニタイズされて表示されることを確認` | ユーザー入力にスクリプトを埋め込んでも実行されず、無害なテキストとして扱われること。`textContent`が使われているかなど。 | **必須** |
| **認証状態の管理** | `await browser_navigate(protectedPage)`<br>`await expect(page).toHaveURL(/.*\/login/)`<br>`// ログイン後、ログアウトし、再度アクセスできないことを確認` | 未認証状態で保護されたページにアクセスするとログインページにリダイレクトされること。ログアウト後はセッションが確実に破棄されること。 | **必須** |
| **入力のサニタイズ** | `await browser_type(input, " O'Malley -- ")`<br>`// 送信後、データが壊れたり、エラーが発生したりせずに正しく表示されることを確認` | SQLインジェクションに繋がりうる特殊文字を入力しても、システムがエラーを起こさず、データが正しく処理・表示されること。 | 推奨 |
| **CSRFトークン検証** | `// ネットワークインターセプトでリクエストヘッダーを確認`<br>`page.on('request', req => { if (req.method() === 'POST') { const headers = req.headers(); expect(headers['x-csrf-token'] \|\| headers['x-xsrf-token']).toBeTruthy(); } })` | 状態変更を伴うPOST/PUT/DELETEリクエストにCSRFトークンが付与されていること。ブラウザ外からのリクエストが拒否されること。 | **必須** |
| **CookieのSecure/HttpOnly属性** | `const cookies = await context.cookies()`<br>`const sessionCookie = cookies.find(c => c.name === 'session')`<br>`expect(sessionCookie.httpOnly).toBe(true)`<br>`expect(sessionCookie.secure).toBe(true)` | セッションCookieに`HttpOnly`（JS非アクセス）と`Secure`（HTTPS限定）属性が設定されていること。 | **必須** |
| **Mixed Content検出** | `const mixedContentErrors = []`<br>`page.on('console', msg => { if (msg.type() === 'error' && msg.text().includes('Mixed Content')) mixedContentErrors.push(msg.text()); })`<br>`await browser_navigate(targetPage)`<br>`expect(mixedContentErrors).toHaveLength(0)` | HTTPSページ内からHTTPリソース（画像・スクリプト等）が読み込まれていないこと。コンソールにMixed Contentエラーが出ないこと。 | 推奨 |
| **Content-Security-Policy確認** | `const response = await page.goto(targetUrl)`<br>`const cspHeader = response.headers()['content-security-policy']`<br>`expect(cspHeader).toBeTruthy()` | レスポンスヘッダーに`Content-Security-Policy`が設定されており、最低限`default-src`または`script-src`が定義されていること。 | 推奨 |

---

## 13. ネットワーク観測 (Network Observation)
APIリクエストの正確性・効率性・重複を検証します。`page.waitForResponse()` / `page.on('request')` を活用してください。

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **API呼び出し回数検証（二重送信防止）** | `let callCount = 0`<br>`page.on('request', req => { if (req.url().includes('/api/submit')) callCount++; })`<br>`await browser_click(submitButton)`<br>`await page.waitForResponse('**/api/submit')`<br>`expect(callCount).toBe(1)` | ボタンを1回クリックした際にAPIが1回だけ呼び出されること。二重送信・重複リクエストが発生しないこと。 | **必須** |
| **レスポンスステータス検証** | `const response = await page.waitForResponse('**/api/data')`<br>`expect(response.status()).toBe(200)` | 想定するAPIエンドポイントが200 OKを返すこと。エラーステータス（4xx/5xx）が意図せず発生していないこと。 | **必須** |
| **不要なAPIリクエスト検出（無駄な再レンダリング）** | `const requests = []`<br>`page.on('request', req => requests.push(req.url()))`<br>`// ページを読み込んだだけ、または静的な操作をしただけの状態で計測`<br>`// 同一URLへの連続リクエストや不要な呼び出しがないか確認` | ページ表示・静的操作時に同一エンドポイントへの重複リクエストが発生しないこと。無駄な再フェッチがUIのパフォーマンスを損なっていないこと。 | 推奨 |
| **リクエストペイロード検証** | `page.on('request', req => { if (req.method() === 'POST') { const body = req.postDataJSON(); expect(body).toMatchObject({ id: expect.any(Number) }); } })` | POSTリクエストのbodyに必要なフィールドが含まれ、型が正しいこと（例：IDはstring型でなくnumber型）。 | 推奨 |
| **レスポンスボディ検証** | `const resp = await page.waitForResponse('**/api/articles')`<br>`const json = await resp.json()`<br>`expect(Array.isArray(json.items)).toBe(true)`<br>`expect(json.total).toBeGreaterThan(0)` | APIレスポンスのJSONスキーマが仕様通りであること（必須フィールド存在、型一致）。 | 推奨 |

---

## 14. Visual Regression（視覚的回帰テスト）
UIの意図しない視覚的変更を自動検出します。

### 原則

- **`toMatchSnapshot()` を原則化**: 全ての重要なUIコンポーネントにスナップショットテストを実装すること。
- **初回実行でベースライン生成**: `--update-snapshots` フラグでベースライン画像を生成し、リポジトリにコミットする。
- **差分比較の基準**: ピクセル差分が**5%未満**をPASS、5%以上をFAILとする（`threshold: 0.05`）。

### 差分比較手順

```javascript
// 1. スナップショット取得（ベースラインとの比較）
await expect(page).toHaveScreenshot('news-list.png', {
  threshold: 0.05,            // 5%差分まで許容
  maxDiffPixels: 100,         // 最大100ピクセルの差分まで許容
  animations: 'disabled',    // アニメーション無効化（再現性確保）
});

// 2. 特定コンポーネントのスナップショット
const card = page.locator('.article-card').first();
await expect(card).toHaveScreenshot('article-card.png', { threshold: 0.02 });
```

### 判定基準

| 状態 | 対応 |
| :--- | :--- |
| 差分なし（0%） | PASS |
| 差分あり・閾値以内（0〜5%） | PASS（ただし差分画像を確認） |
| 差分あり・閾値超過（5%+） | FAIL → 意図的変更なら `--update-snapshots` で更新、バグなら修正 |
| スナップショット未生成 | FAIL → 初回実行で生成すること |

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **ページ全体のスナップショット** | `await expect(page).toHaveScreenshot('page-full.png', { fullPage: true, animations: 'disabled' })` | ベースライン画像との差分が5%未満であること。 | 推奨 |
| **重要UIコンポーネント** | `await expect(page.locator('.main-content')).toHaveScreenshot('main-content.png')` | ボタン・カード・フォーム等の主要コンポーネントに視覚的変更がないこと。 | 推奨 |
| **ダークモード/テーマ切替** | `await page.emulateMedia({ colorScheme: 'dark' })`<br>`await expect(page).toHaveScreenshot('page-dark.png')` | ダークモードやテーマ切替後のUIがベースラインと一致すること。 | 任意 |
| **アニメーション無効化確認** | `animations: 'disabled'` オプションをスナップショット取得時に常に指定 | アニメーション途中の状態でスナップショットが撮影されないこと。常に最終状態がキャプチャされること。 | **必須** |

---

## 15. テスト独立性 (Test Independence)
各テストが他のテストの実行結果や順序に依存しないことを保証します。

### 原則

- **各テストは独立していること**: あるテストの実行がそれに続くテストの結果に影響を与えてはならない。
- **テスト順序に依存しないこと**: テストを任意の順序で実行しても同じ結果が得られること（Playwright では `--shard` やランダム実行でも同一結果）。
- **DBと状態のリセット**: 各テスト開始前にデータベースやセッション状態を既知の初期状態に戻すこと。

### クリーンアップ手順テンプレート

```javascript
// テストファイル冒頭またはbeforeEachで実施
test.beforeEach(async ({ page, context }) => {
  // 1. Cookieとセッションをクリア
  await context.clearCookies();

  // 2. LocalStorage / SessionStorage をクリア
  await page.evaluate(() => {
    localStorage.clear();
    sessionStorage.clear();
  });

  // 3. DBリセット（テスト用エンドポイント経由）
  await page.request.post('/api/test/reset-db');

  // 4. ページをクリーンな状態でロード
  await page.goto('/');
});

// テスト終了後のクリーンアップ
test.afterEach(async ({ page }) => {
  // テスト中に作成したデータの削除
  await page.request.delete('/api/test/cleanup');
});
```

| チェック項目名 | 確認方法 (Playwright) | PASS/FAIL判定基準 | 重要度 |
| :--- | :--- | :--- | :--- |
| **テスト間のCookieリセット** | `test.beforeEach(() => context.clearCookies())` | 各テスト開始時にCookieがクリアされており、前テストのセッション状態を引き継がないこと。 | **必須** |
| **テスト間のDB状態リセット** | `await page.request.post('/api/test/reset-db')` | 各テスト開始時にDBが既知の初期状態にリセットされていること。テストデータの混入がないこと。 | **必須** |
| **LocalStorage/SessionStorageのクリア** | `await page.evaluate(() => { localStorage.clear(); sessionStorage.clear(); })` | ブラウザストレージが各テスト前にクリアされていること。 | **必須** |
| **テスト後のデータクリーンアップ** | `test.afterEach(() => page.request.delete('/api/test/cleanup'))` | テスト中に作成したデータ（記事、ユーザー等）がテスト後に削除されていること。 | 推奨 |
| **ランダム順序での実行確認** | `npx playwright test --shard=1/3` などでシャード実行、または順序をシャッフルして実行 | テスト実行順序を変えても全テストがPASSすること。 | 推奨 |
| **並列実行での安全性** | Playwright の `workers` 設定でマルチワーカー実行し、結果を確認 | 並列実行時にテスト間で共有リソース（DB・ファイル等）の競合が発生しないこと。 | 推奨 |

---

## やりがちな間違い（追記）

- **トーストの撮影タイミング**: `browser_click()`直後にスクリーンショットを撮ると、toastIn等のアニメーション途中（opacity:0）でキャプチャされる場合がある。`animations: 'disabled'`オプション使用、またはトーストの`opacity > 0`を確認してから撮影すること。
- **非同期APIのWait不足**: `fetch`完了を待たずに要素の状態を確認するケース。`page.waitForResponse()` または `await expect(resultElement).toBeVisible()` で確実に待機すること。
- **テスト間のデータ汚染**: 前のテストで挿入したDBレコードが残り、次のテストの件数アサーションが失敗するケース。`beforeEach`でのDBリセットを徹底すること。
- **ハードコードされたタイムアウト値**: `await page.waitForTimeout(3000)` などのsleepは不安定の元。`await expect(element).toBeVisible()` のようなイベント駆動の待機に置き換えること。

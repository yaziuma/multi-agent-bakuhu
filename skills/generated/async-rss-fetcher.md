---
name: async-rss-fetcher
description: 複数のRSSフィードから記事を非同期・並列取得する。ニュース集約、コンテンツ収集、フィード監視システムで使用。feedparser + aiohttp + pydantic によるデータ構造化。
---

# Async RSS Fetcher - 非同期RSSフェッチャー

## Overview

複数のRSS/Atomフィードから記事を効率的に取得するための非同期フェッチャー。
`feedparser` でパース、`aiohttp` で非同期HTTP通信、`asyncio.gather` で並列実行、`pydantic` でデータ構造化を行う。

大量のフィード（10+）を扱う場合でも、並列実行により高速な取得が可能。

## When to Use

以下の状況で使用せよ：

- **ニュース集約システム**: 複数のニュースサイトのRSSフィードから記事を収集
- **コンテンツ監視**: ブログやメディアの更新を定期的にチェック
- **データ収集パイプライン**: RSS経由で公開されるデータセットの取得
- **通知システム**: 特定のトピックに関する新着記事の検出

## Dependencies

```bash
# Python 3.10+
feedparser      # RSS/Atom パーサー
aiohttp         # 非同期HTTPクライアント
pydantic        # データバリデーション・構造化
```

## Data Model

### Article Model (pydantic)

```python
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

class Article(BaseModel):
    """RSS記事のデータモデル"""

    title: str = Field(..., description="Article title")
    link: str = Field(..., description="Article URL")
    summary: str = Field(..., description="Article summary/description")
    published: Optional[datetime] = Field(None, description="Publication timestamp")
    feed_name: str = Field(..., description="Source feed name")
    genre: str = Field(..., description="Article genre/category")
```

**ポイント**:
- `published` は Optional（フィードに日付がない場合を考慮）
- `feed_name` と `genre` で記事の出典を追跡
- pydantic により自動バリデーション

## Implementation

### 1. Single Feed Fetcher

```python
import asyncio
import logging
import time
from datetime import datetime
from typing import List

import aiohttp
import feedparser

logger = logging.getLogger(__name__)

async def fetch_feed(
    session: aiohttp.ClientSession,
    feed_url: str,
    feed_name: str,
    genre: str = "general",
    max_articles: int = 10
) -> List[Article]:
    """
    単一フィードから記事を取得.

    Args:
        session: aiohttp client session
        feed_url: RSS feed URL
        feed_name: Feed display name
        genre: Article category/genre
        max_articles: Maximum number of articles to fetch

    Returns:
        List of articles from the feed

    Raises:
        aiohttp.ClientError: On network errors
        Exception: On parsing errors
    """
    logger.info(f"Fetching feed: {feed_name} ({feed_url})")

    try:
        # Fetch feed content asynchronously
        async with session.get(
            feed_url,
            timeout=aiohttp.ClientTimeout(total=10)
        ) as response:
            response.raise_for_status()
            content = await response.text()

        # Parse feed (synchronous, but fast)
        parsed = feedparser.parse(content)

        # Check for parsing errors
        if parsed.bozo:
            logger.warning(
                f"Feed {feed_name} has parsing issues: {parsed.bozo_exception}"
            )

        # Extract articles
        articles = []
        for entry in parsed.entries[:max_articles]:
            # Parse published date
            published = None
            if hasattr(entry, "published_parsed") and entry.published_parsed:
                try:
                    published = datetime.fromtimestamp(
                        time.mktime(entry.published_parsed)
                    )
                except (ValueError, OverflowError) as e:
                    logger.warning(f"Invalid published date in {feed_name}: {e}")

            # Create article
            article = Article(
                title=entry.get("title", "No title"),
                link=entry.get("link", ""),
                summary=entry.get("summary", ""),
                published=published,
                feed_name=feed_name,
                genre=genre,
            )
            articles.append(article)

        logger.info(f"Fetched {len(articles)} articles from {feed_name}")
        return articles

    except aiohttp.ClientError as e:
        logger.error(f"Network error fetching {feed_name}: {e}")
        raise
    except Exception as e:
        logger.error(f"Error parsing {feed_name}: {e}")
        raise
```

**ポイント**:
- `aiohttp.ClientTimeout(total=10)`: タイムアウト10秒
- `parsed.bozo`: feedparser のエラー検出フラグ
- `entry.published_parsed` → `datetime.fromtimestamp()`: 時刻変換
- `entry.get()` でデフォルト値を指定（KeyError回避）

### 2. Parallel Feed Fetcher

```python
async def fetch_all_feeds(
    feed_configs: List[dict],
    max_articles_per_feed: int = 10
) -> List[Article]:
    """
    全てのフィードから記事を並列取得.

    Args:
        feed_configs: List of feed configuration dicts
            Example: [{"url": "...", "name": "...", "genre": "..."}]
        max_articles_per_feed: Maximum articles per feed

    Returns:
        List of all articles from all feeds

    Note:
        Uses asyncio.gather with return_exceptions=True.
        Failed feeds are logged but do not stop other feeds.
    """
    if not feed_configs:
        logger.warning("No feeds provided")
        return []

    logger.info(f"Fetching {len(feed_configs)} feeds in parallel")

    async with aiohttp.ClientSession() as session:
        tasks = [
            fetch_feed(
                session,
                config["url"],
                config["name"],
                config.get("genre", "general"),
                max_articles_per_feed
            )
            for config in feed_configs
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

    # Flatten results and filter out exceptions
    articles = []
    for result in results:
        if isinstance(result, Exception):
            logger.error(f"Feed fetch failed: {result}")
        elif isinstance(result, list):
            articles.extend(result)

    logger.info(f"Fetched {len(articles)} articles total")
    return articles
```

**ポイント**:
- `asyncio.gather(*tasks, return_exceptions=True)`: 並列実行、エラー時も継続
- `isinstance(result, Exception)`: 失敗したタスクの検出
- `articles.extend(result)`: リストのフラット化

## Error Handling

### Timeout Handling

```python
# タイムアウト設定
timeout = aiohttp.ClientTimeout(
    total=10,      # 全体のタイムアウト
    connect=3,     # 接続タイムアウト
    sock_read=5    # 読み取りタイムアウト
)

async with session.get(url, timeout=timeout) as response:
    content = await response.text()
```

### Network Error Handling

```python
try:
    articles = await fetch_feed(session, url, name)
except aiohttp.ClientError as e:
    # ネットワークエラー（接続失敗、タイムアウト等）
    logger.error(f"Network error: {e}")
    # 継続するか、リトライするか判断
except asyncio.TimeoutError:
    # タイムアウト
    logger.error(f"Timeout fetching {name}")
```

### Graceful Degradation

```python
# 失敗したフィードがあっても他のフィードは処理する
results = await asyncio.gather(*tasks, return_exceptions=True)

for i, result in enumerate(results):
    if isinstance(result, Exception):
        logger.error(f"Feed {feed_configs[i]['name']} failed: {result}")
        # 失敗をメトリクスとして記録
    else:
        # 成功した記事を処理
        process_articles(result)
```

## Advanced Features

### Rate Limiting with Semaphore

大量のフィード（100+）を取得する場合、同時接続数を制限せよ：

```python
async def fetch_all_feeds_with_limit(
    feed_configs: List[dict],
    max_concurrent: int = 10
) -> List[Article]:
    """
    同時接続数を制限して並列取得.

    Args:
        feed_configs: Feed configurations
        max_concurrent: Maximum concurrent connections
    """
    semaphore = asyncio.Semaphore(max_concurrent)

    async def fetch_with_semaphore(session, config):
        async with semaphore:
            return await fetch_feed(
                session,
                config["url"],
                config["name"],
                config.get("genre", "general")
            )

    async with aiohttp.ClientSession() as session:
        tasks = [
            fetch_with_semaphore(session, config)
            for config in feed_configs
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

    # ... (結果処理は同じ)
```

### Retry Logic

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10)
)
async def fetch_feed_with_retry(session, url, name, genre):
    """リトライ機能付きフェッチ"""
    return await fetch_feed(session, url, name, genre)
```

## Testing

### Mock Test Example

```python
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

@pytest.mark.asyncio
async def test_fetch_feed_success():
    """Test successful feed fetch"""
    mock_session = MagicMock()
    mock_response = AsyncMock()
    mock_response.text = AsyncMock(return_value="""
        <?xml version="1.0"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>Test Article</title>
                    <link>https://example.com/article</link>
                    <description>Test summary</description>
                </item>
            </channel>
        </rss>
    """)
    mock_response.raise_for_status = MagicMock()
    mock_session.get.return_value.__aenter__.return_value = mock_response

    articles = await fetch_feed(
        mock_session,
        "https://example.com/feed.xml",
        "Test Feed",
        "tech"
    )

    assert len(articles) == 1
    assert articles[0].title == "Test Article"
    assert articles[0].feed_name == "Test Feed"
    assert articles[0].genre == "tech"


@pytest.mark.asyncio
async def test_fetch_all_feeds_with_failure():
    """Test parallel fetch with one feed failing"""
    # モックの設定（省略）
    # 1つのフィードは成功、もう1つは失敗させる

    articles = await fetch_all_feeds(feed_configs)

    # 失敗したフィードがあっても成功したフィードの記事は取得できる
    assert len(articles) > 0
```

## Guidelines

### Must Do

1. **Always use async with for ClientSession**
   ```python
   # ✅ Good
   async with aiohttp.ClientSession() as session:
       ...

   # ❌ Bad - セッションがクローズされない
   session = aiohttp.ClientSession()
   ```

2. **Set timeouts to prevent hanging**
   ```python
   # ✅ Good
   timeout = aiohttp.ClientTimeout(total=10)
   async with session.get(url, timeout=timeout) as response:
       ...

   # ❌ Bad - タイムアウトなし
   async with session.get(url) as response:
       ...
   ```

3. **Handle published_parsed carefully**
   ```python
   # ✅ Good - 存在チェック + 例外処理
   if hasattr(entry, "published_parsed") and entry.published_parsed:
       try:
           published = datetime.fromtimestamp(time.mktime(entry.published_parsed))
       except (ValueError, OverflowError):
           published = None

   # ❌ Bad - AttributeError の可能性
   published = datetime.fromtimestamp(time.mktime(entry.published_parsed))
   ```

4. **Use return_exceptions=True in gather**
   ```python
   # ✅ Good - エラーでも他のタスクは継続
   results = await asyncio.gather(*tasks, return_exceptions=True)

   # ❌ Bad - 1つでもエラーがあると全体が失敗
   results = await asyncio.gather(*tasks)
   ```

### Should Do

1. **Limit concurrent connections for large feed lists**
   - Use `asyncio.Semaphore` for 100+ feeds
   - Recommended: max_concurrent=10-20

2. **Log feed fetch results**
   - Success: number of articles fetched
   - Failure: error details with feed name

3. **Validate feed URLs before fetching**
   - Check URL format
   - Filter out disabled feeds

### Should Not Do

1. **Don't fetch feeds synchronously**
   - Bad for performance with multiple feeds
   - Use async/await pattern

2. **Don't ignore bozo flag**
   - feedparser sets `parsed.bozo=True` for malformed feeds
   - Log warnings but continue processing if possible

3. **Don't assume all entries have all fields**
   - Use `entry.get()` with defaults
   - Example: `entry.get("title", "No title")`

## Common Pitfalls

### 1. Time Conversion Error

```python
# ❌ Bad - TypeError if published_parsed is None
published = datetime.fromtimestamp(time.mktime(entry.published_parsed))

# ✅ Good
if entry.published_parsed:
    try:
        published = datetime.fromtimestamp(time.mktime(entry.published_parsed))
    except (ValueError, OverflowError):
        published = None
```

### 2. Session Not Closed

```python
# ❌ Bad - リソースリーク
session = aiohttp.ClientSession()
await fetch_feed(session, url, name)
# session.close() を忘れる

# ✅ Good
async with aiohttp.ClientSession() as session:
    await fetch_feed(session, url, name)
# 自動クローズ
```

### 3. Blocking feedparser.parse()

```python
# ⚠️ Note: feedparser.parse() is synchronous
# For large feeds (1000+ entries), consider running in executor:

import asyncio

async def parse_feed_async(content):
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, feedparser.parse, content)
```

## Performance Tips

1. **Batch Processing**
   - Process feeds in batches of 10-20 for better memory usage

2. **Connection Pooling**
   - Reuse `ClientSession` for multiple requests
   - Set connector limits: `connector=aiohttp.TCPConnector(limit=100)`

3. **Content Length Limit**
   - Set max response size to prevent memory issues:
     ```python
     response = await session.get(url, max_size=10*1024*1024)  # 10MB
     ```

## References

- [feedparser documentation](https://feedparser.readthedocs.io/)
- [aiohttp documentation](https://docs.aiohttp.org/)
- [pydantic documentation](https://docs.pydantic.dev/)
- [asyncio documentation](https://docs.python.org/3/library/asyncio.html)

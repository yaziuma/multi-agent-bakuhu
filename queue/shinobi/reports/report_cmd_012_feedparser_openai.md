# Python Libraries for AI News Anchor

This document provides a guide to using `feedparser` for RSS processing and the `openai` library for interacting with GPT models asynchronously.

## 1. `feedparser` (RSS Parser)

`feedparser` is a robust Python library for parsing RSS and Atom feeds.

### 1.1. Basic Usage & Data Extraction

You can fetch and parse a feed in one step. The parsed result is a dictionary-like object, with feed metadata and a list of entries.

**Key Entry Attributes:**
- **Title:** `entry.title`
- **Link:** `entry.link`
- **Summary/Content:** `entry.summary` or `entry.get('content')[0].value` for full content.
- **Published Date:** `entry.published_parsed` (returns a `time.struct_time`)

### 1.2. Error Handling

- **Network Errors:** Use a `try...except` block to catch exceptions like `urllib.error.URLError`.
- **Parsing Errors:** `feedparser` is very lenient and rarely fails. However, you can check `feed.bozo` which is `1` if the feed is malformed, and `feed.bozo_exception` will contain the exception details.

### 1.3. Japanese Encoding Support

`feedparser` automatically handles character encoding by inspecting HTTP headers and the XML content itself. It decodes to UTF-8 by default, so Japanese characters work out of the box with well-formed feeds.

### 1.4. Async Fetching (`asyncio` + `aiohttp`)

`feedparser` itself is a synchronous library. To fetch feeds asynchronously, you can use `aiohttp` to download the feed content and then pass it to `feedparser.parse()`.

### Code Examples

#### Basic Feed Parsing

```python
import feedparser
import time

# A well-known Japanese news RSS feed
url = "https://www.nhk.or.jp/rss/news/cat0.xml"

print(f"Fetching feed from: {url}")
feed = feedparser.parse(url)

# Check for feed-level errors
if feed.bozo:
    print(f"Error parsing feed: {feed.bozo_exception}")

# Print feed metadata
print(f"Feed Title: {feed.feed.title}")
print(f"Feed Link: {feed.feed.link}")
print("-" * 30)

# Iterate through entries
for entry in feed.entries[:3]:  # Displaying first 3 entries
    print(f"Title: {entry.title}")
    print(f"Link: {entry.link}")
    
    # Safely get published date
    if hasattr(entry, 'published_parsed'):
        published_time = time.strftime('%Y-%m-%d %H:%M:%S', entry.published_parsed)
        print(f"Published: {published_time}")
    
    print(f"Summary: {entry.summary}")
    print("-" * 20)
```

#### Parallel Fetching with `asyncio` and `aiohttp`

```python
import asyncio
import aiohttp
import feedparser

async def fetch_feed_content(session, url):
    """Asynchronously fetches content from a URL."""
    try:
        async with session.get(url, timeout=10) as response:
            response.raise_for_status()  # Raise an exception for bad status codes
            return await response.text()
    except aiohttp.ClientError as e:
        print(f"Error fetching {url}: {e}")
        return None

async def parse_feeds_parallel(urls):
    """Fetches and parses multiple feeds in parallel."""
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_feed_content(session, url) for url in urls]
        feed_contents = await asyncio.gather(*tasks)

        for url, content in zip(urls, feed_contents):
            if content:
                print(f"\n--- Parsing {url} ---")
                
                # feedparser.parse is synchronous, but fast enough here
                feed = feedparser.parse(content)
                
                if feed.bozo:
                    print(f"  Warning: Malformed feed. Reason: {feed.bozo_exception}")
                    
                if feed.entries:
                    print(f"  Latest entry: {feed.entries[0].title}")
                else:
                    print("  No entries found.")
            else:
                print(f"\n--- Could not fetch or parse {url} ---")


# List of RSS feeds
feed_urls = [
    "https://www.nhk.or.jp/rss/news/cat0.xml",       # NHK News
    "http://feeds.bbci.co.uk/news/rss.xml",         # BBC News (example of non-Japanese)
    "https://www.asahi.com/rss/asahi/newsheadlines.rdf", # Asahi Shimbun
    "http://invalid.url/rss.xml"                    # Example of a failing URL
]

# Run the async function
asyncio.run(parse_feeds_parallel(feed_urls))
```

## 2. OpenAI API (Async)

The `openai` library provides an `AsyncOpenAI` client for non-blocking API calls.

### 2.1. `AsyncOpenAI` Client & Chat Completion

The client is the entry point for all API interactions. `ChatCompletion` is used for conversations with models like `gpt-4o-mini`.

**Message Structure:**
- **`system`**: Sets the context and instructions for the AI.
- **`user`**: The user's prompt or question.
- **`assistant`**: The AI's previous responses (useful for follow-up questions).

### 2.2. Streaming Responses

To get a real-time, token-by-token response, set `stream=True`. You then iterate asynchronously over the response object to receive chunks as they are generated.

### 2.3. Error Handling & Retries

The API can fail due to rate limits, network issues, or server errors. It's best practice to implement a retry mechanism. The `tenacity` library is excellent for this.

**Common Exceptions:**
- `openai.RateLimitError`: You are sending requests too quickly.
- `openai.APIConnectionError`: Network issue.
- `openai.APITimeoutError`: Request timed out.
- `openai.APIStatusError` with a 5xx status code: OpenAI server-side issue.

### 2.4. Token Counting

OpenAI charges based on tokens. Before sending a request, you can estimate the token count using the `tiktoken` library to avoid unexpected costs or exceeding model context limits.

### Code Examples

#### Async ChatCompletion Call with Streaming

```python
import asyncio
import os
from openai import AsyncOpenAI

# It's recommended to use environment variables for API keys
# from dotenv import load_dotenv
# load_dotenv()
# client = AsyncOpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

# For demonstration, you can replace the key here, but it is not secure.
client = AsyncOpenAI(api_key="YOUR_OPENAI_API_KEY")

async def generate_news_script():
    """Generates a short news script using streaming."""
    if client.api_key == "YOUR_OPENAI_API_KEY":
        print("Please replace 'YOUR_OPENAI_API_KEY' with your actual OpenAI API key.")
        return

    print("--- Generating news script (streaming) ---")
    try:
        stream = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "あなたはプロのニュースキャスターです。提供された記事の要点をまとめ、簡潔で分かりやすいニュース原稿を作成してください。句読点を使い、自然な間で話すように書いてください。"
                },
                {
                    "role": "user",
                    "content": "記事：本日、東京で桜の開花が宣言されました。これは平年より5日早い開花で、多くの花見客が公園に集まっています。"
                }
            ],
            stream=True,
        )
        
        full_response = ""
        async for chunk in stream:
            content = chunk.choices[0].delta.content or ""
            print(content, end="", flush=True)
            full_response += content
        print("\n--- Stream finished ---")

    except Exception as e:
        print(f"\nAn error occurred: {e}")

# Run the async function
asyncio.run(generate_news_script())

```

#### Retry Logic with `tenacity` and Token Counting with `tiktoken`

```python
import asyncio
import os
import tiktoken
from openai import AsyncOpenAI, RateLimitError, APITimeoutError, APIConnectionError, APIStatusError
from tenacity import retry, stop_after_attempt, wait_random_exponential, retry_if_exception_type

# --- Setup (same as before) ---
client = AsyncOpenAI(api_key="YOUR_OPENAI_API_KEY")

# --- Tokenizer ---
def count_tokens(text: str, model: str = "gpt-4o-mini") -> int:
    """Counts the number of tokens in a string for a given model."""
    try:
        encoding = tiktoken.encoding_for_model(model)
    except KeyError:
        print("Warning: Model not found. Using cl100k_base encoding.")
        encoding = tiktoken.get_encoding("cl100k_base")
    return len(encoding.encode(text))

# --- Retry Logic ---
@retry(
    wait=wait_random_exponential(min=1, max=60), # Exponential backoff between 1s and 60s
    stop=stop_after_attempt(5), # Stop after 5 attempts
    retry=retry_if_exception_type((RateLimitError, APITimeoutError, APIConnectionError, APIStatusError))
)
async def create_completion_with_retry(**kwargs):
    """Wrapper for ChatCompletion create call with tenacity retry logic."""
    print("Attempting to call OpenAI API...")
    try:
        response = await client.chat.completions.create(**kwargs)
        return response
    except APIStatusError as e:
        # Retry on 5xx server errors, but not on client errors like 400
        if e.status_code >= 500:
            print(f"Server error (status {e.status_code}), retrying...")
            raise e 
        else:
            print(f"Client error (status {e.status_code}), not retrying.")
            raise
    except Exception as e:
        print(f"An unexpected error occurred: {e}. Retrying...")
        raise

async def main():
    if client.api_key == "YOUR_OPENAI_API_KEY":
        print("Please replace 'YOUR_OPENAI_API_KEY' with your actual OpenAI API key.")
        return

    prompt = "記事：新しいAI技術が開発され、自動運転車の安全性が大幅に向上する見込みです。この技術は、悪天候でも正確に周囲を認識できます。"
    system_message = "あなたは技術ニュースの専門家です。提供された記事を小学生にも分かるように、100文字程度で要約してください。"

    # Count tokens before sending
    prompt_tokens = count_tokens(prompt)
    system_tokens = count_tokens(system_message)
    print(f"Estimated tokens for prompt: {prompt_tokens + system_tokens}")

    try:
        response = await create_completion_with_retry(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": prompt}
            ]
        )
        summary = response.choices[0].message.content
        print("\n--- Summary Received ---")
        print(summary)
        
        # Count completion tokens
        completion_tokens = response.usage.completion_tokens
        print(f"Completion tokens used: {completion_tokens}")

    except Exception as e:
        print(f"\nFailed to get completion after multiple retries: {e}")

# Run the main async function
asyncio.run(main())

```

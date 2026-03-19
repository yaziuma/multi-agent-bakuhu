# moviepy-video-generator

> **Version**: 1.0
> **Last Updated**: 2026-02-05

## 概要

MoviePy 2.x を使った動画生成スキル。静止画（背景画像）と音声ファイルを組み合わせてMP4動画を生成する。

## 用途

- ニュース動画の自動生成（静止画 + TTS音声）
- プレゼンテーション動画の作成（スライド + ナレーション）
- ポッドキャストの動画化（カバーアート + 音声）
- 解説動画の自動生成（図解 + 解説音声）

## MoviePy 2.x への対応

MoviePy 2.x では API が大幅に変更された。以下の対応が必要：

| 旧 API (1.x) | 新 API (2.x) | 説明 |
|-------------|-------------|------|
| `moviepy.editor` | `moviepy` | インポート元が変更 |
| `set_duration(t)` | `with_duration(t)` | メソッド名変更 |
| `resize(size)` | `resized(size)` | メソッド名変更 |
| `set_audio(audio)` | `with_audio(audio)` | メソッド名変更 |

```python
# 旧 API (1.x) - 使わないこと
from moviepy.editor import ImageClip, AudioFileClip
clip = ImageClip("bg.png").set_duration(10)

# 新 API (2.x) - これを使う
from moviepy import ImageClip, AudioFileClip
clip = ImageClip("bg.png").with_duration(10)
```

## 依存関係

```toml
[dependencies]
moviepy = ">=2.0"
pillow = "*"  # MoviePy が画像処理に使用
```

**システム要件:**
- FFmpeg（必須）: 動画エンコード/デコードに使用
  ```bash
  # Ubuntu/Debian
  sudo apt-get install ffmpeg

  # macOS
  brew install ffmpeg
  ```

## 構成

### 1. VideoSettings（設定クラス）

```python
from pydantic import BaseModel, Field

class VideoResolution(BaseModel):
    """動画解像度設定"""
    width: int = Field(1920, ge=320, description="Video width in pixels")
    height: int = Field(1080, ge=240, description="Video height in pixels")

class VideoSettings(BaseModel):
    """動画生成設定"""
    resolution: VideoResolution = VideoResolution()
    fps: int = Field(30, ge=1, le=60, description="Frames per second")
    codec: str = Field("libx264", description="Video codec")
    audio_codec: str = Field("aac", description="Audio codec")
    output_dir: str = Field("output/videos", description="Output directory")
    background_image: str = Field("assets/background.png", description="Default background")
```

### 2. VideoGenerator（同期版）

```python
from pathlib import Path
import structlog
from moviepy import AudioFileClip, ImageClip  # type: ignore

logger = structlog.get_logger()

class VideoGenerator:
    """
    MoviePy を使った動画生成クラス（同期版）

    静止画と音声を組み合わせてMP4動画を生成する。
    """

    def __init__(self, settings: VideoSettings) -> None:
        """
        Initialize video generator.

        Args:
            settings: Video configuration settings
        """
        self.settings = settings

    def generate(
        self,
        background: Path,
        audio: Path,
        output: Path,
    ) -> Path:
        """
        Generate video from background image and audio.

        Args:
            background: Path to background image
            audio: Path to audio file
            output: Path where video will be saved

        Returns:
            Path to generated video file

        Raises:
            FileNotFoundError: If background image or audio file not found
            RuntimeError: If video generation fails
        """
        # 入力ファイルの検証
        if not background.exists():
            raise FileNotFoundError(f"Background image not found: {background}")
        if not audio.exists():
            raise FileNotFoundError(f"Audio file not found: {audio}")

        logger.info(
            "Generating video",
            background=str(background),
            audio=str(audio),
            output=str(output),
        )

        try:
            # 音声を読み込み、時間を取得
            audio_clip = AudioFileClip(str(audio))
            duration = audio_clip.duration
            logger.debug("Audio loaded", duration=f"{duration:.2f}s")

            # 画像クリップを作成（音声の長さに合わせる）
            image_clip = ImageClip(str(background)).with_duration(duration)

            # 画像を指定解像度にリサイズ
            target_width = self.settings.resolution.width
            target_height = self.settings.resolution.height
            image_clip = image_clip.resized((target_width, target_height))
            logger.debug("Image resized", width=target_width, height=target_height)

            # 音声を動画に追加
            video = image_clip.with_audio(audio_clip)

            # 出力ディレクトリを作成
            output.parent.mkdir(parents=True, exist_ok=True)

            # 動画ファイルを書き出し
            video.write_videofile(
                str(output),
                fps=self.settings.fps,
                codec=self.settings.codec,
                audio_codec=self.settings.audio_codec,
                logger=None,  # MoviePy のプログレスバーを非表示
            )

            # リソースをクリーンアップ
            video.close()
            audio_clip.close()

            logger.info("Video generated successfully", output=str(output))
            return output

        except Exception as e:
            logger.error("Failed to generate video", error=str(e))
            raise RuntimeError(f"Video generation failed: {e}") from e
```

### 3. AsyncVideoGenerator（非同期版）

```python
import asyncio

class AsyncVideoGenerator:
    """
    VideoGenerator の非同期ラッパー

    run_in_executor を使って同期処理を非同期化。
    """

    def __init__(self, sync_generator: VideoGenerator) -> None:
        """
        Initialize async video generator.

        Args:
            sync_generator: Synchronous video generator instance
        """
        self.sync_generator = sync_generator

    async def generate(
        self,
        background: Path,
        audio: Path,
        output: Path,
    ) -> Path:
        """
        Generate video asynchronously.

        Args:
            background: Path to background image
            audio: Path to audio file
            output: Path where video will be saved

        Returns:
            Path to generated video file
        """
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None,
            self.sync_generator.generate,
            background,
            audio,
            output,
        )
```

## 使用例

### 基本的な使い方

```python
from pathlib import Path
from video_generator import VideoGenerator, VideoSettings, VideoResolution

# 設定
settings = VideoSettings(
    resolution=VideoResolution(width=1920, height=1080),
    fps=30,
    codec="libx264",
    audio_codec="aac",
)

# ジェネレーターを初期化
generator = VideoGenerator(settings)

# 動画生成
output = generator.generate(
    background=Path("assets/background.png"),
    audio=Path("output/audio.wav"),
    output=Path("output/video.mp4"),
)

print(f"Video generated: {output}")
```

### 非同期での使い方

```python
import asyncio
from pathlib import Path
from video_generator import VideoGenerator, AsyncVideoGenerator, VideoSettings

async def main():
    settings = VideoSettings()
    sync_gen = VideoGenerator(settings)
    async_gen = AsyncVideoGenerator(sync_gen)

    # 複数の動画を並列生成
    tasks = [
        async_gen.generate(
            Path(f"assets/bg_{i}.png"),
            Path(f"audio/speech_{i}.wav"),
            Path(f"output/video_{i}.mp4"),
        )
        for i in range(3)
    ]

    results = await asyncio.gather(*tasks)
    print(f"Generated {len(results)} videos")

asyncio.run(main())
```

## テスト例

```python
import pytest
from pathlib import Path
from unittest.mock import MagicMock, patch
from video_generator import VideoGenerator, VideoSettings

@pytest.fixture
def video_settings() -> VideoSettings:
    """テスト用の設定"""
    return VideoSettings(
        resolution={"width": 1280, "height": 720},
        fps=24,
        codec="libx264",
        audio_codec="aac",
    )

@pytest.fixture
def temp_files(tmp_path: Path):
    """テスト用の一時ファイル"""
    bg = tmp_path / "background.png"
    audio = tmp_path / "audio.wav"
    output = tmp_path / "output.mp4"

    # ダミーファイルを作成
    bg.touch()
    audio.touch()

    return bg, audio, output

def test_generate_video(video_settings, temp_files):
    """動画生成のテスト（モック使用）"""
    bg, audio, output = temp_files

    with patch("moviepy.AudioFileClip") as mock_audio:
        with patch("moviepy.ImageClip") as mock_image:
            # モックの設定
            mock_audio_instance = MagicMock()
            mock_audio_instance.duration = 10.0
            mock_audio.return_value = mock_audio_instance

            mock_image_instance = MagicMock()
            mock_image.return_value = mock_image_instance

            # 動画生成を実行
            generator = VideoGenerator(video_settings)
            result = generator.generate(bg, audio, output)

            # 検証
            assert result == output
            mock_audio.assert_called_once()
            mock_image.assert_called_once()

def test_file_not_found(video_settings, tmp_path):
    """存在しないファイルでエラーになることを確認"""
    generator = VideoGenerator(video_settings)

    with pytest.raises(FileNotFoundError):
        generator.generate(
            Path("nonexistent.png"),
            Path("nonexistent.wav"),
            tmp_path / "output.mp4",
        )
```

## 機能

### 1. 背景画像の自動リサイズ
- 任意サイズの画像を指定解像度にリサイズ
- アスペクト比は考慮されない（指定サイズに合わせて引き伸ばし/圧縮）

### 2. 音声の長さに基づく動画時間設定
- 音声ファイルの長さを自動検出
- 動画の長さを音声に合わせる

### 3. コーデック指定
- 動画コーデック（デフォルト: libx264）
- 音声コーデック（デフォルト: aac）
- カスタムコーデックも指定可能

### 4. リソース管理
- 生成後に自動クリーンアップ（close()）
- メモリリークを防止

## 注意事項

### 1. FFmpeg のシステムインストールが必須
MoviePy は内部で FFmpeg を使用する。システムに FFmpeg がインストールされていない場合、動画生成に失敗する。

```bash
# インストール確認
ffmpeg -version

# なければインストール
sudo apt-get install ffmpeg  # Ubuntu/Debian
brew install ffmpeg          # macOS
```

### 2. 大容量動画のメモリ使用量
- 長時間の動画（10分以上）は大量のメモリを消費する
- 本番環境では適切なメモリ割り当てが必要
- 可能であればチャンク処理や streaming を検討

### 3. GPU対応（オプション）
MoviePy は基本的に CPU で処理するが、FFmpeg の GPU エンコーダを使用可能：

```python
# NVIDIA GPU (h264_nvenc)
settings = VideoSettings(codec="h264_nvenc")

# AMD GPU (h264_amf)
settings = VideoSettings(codec="h264_amf")
```

ただし、GPU ドライバと対応する FFmpeg ビルドが必要。

### 4. プログレスバーの表示
デフォルトでは `logger=None` で非表示にしているが、コマンドライン実行時は表示したい場合：

```python
video.write_videofile(
    str(output),
    fps=self.settings.fps,
    codec=self.settings.codec,
    audio_codec=self.settings.audio_codec,
    # logger='bar' でプログレスバー表示
)
```

### 5. 画像フォーマットの対応
対応画像形式は Pillow の対応フォーマットに依存：
- PNG, JPEG, BMP, GIF, TIFF など
- 透過PNG も対応（背景は黒になる）

## トラブルシューティング

### エラー: `FFMPEG_BINARY not found`
FFmpeg がインストールされていないか、パスが通っていない。

```bash
# 解決方法
sudo apt-get install ffmpeg
```

### エラー: `OSError: [Errno 24] Too many open files`
ファイルディスクリプタの上限に達した。close() を忘れている可能性。

```python
# 必ず close() を呼ぶ
video.close()
audio_clip.close()
```

### パフォーマンスが遅い
- 解像度を下げる（1920x1080 → 1280x720）
- FPS を下げる（30fps → 24fps）
- GPU エンコーダを使う

## 関連スキル

- `kokoro-tts-generator`: TTS音声生成（このスキルの入力音声を生成）
- `image-processor`: 背景画像の前処理
- `youtube-uploader`: 生成した動画のアップロード

## 参考資料

- [MoviePy 公式ドキュメント](https://zulko.github.io/moviepy/)
- [MoviePy 2.x 移行ガイド](https://github.com/Zulko/moviepy/releases)
- [FFmpeg ドキュメント](https://ffmpeg.org/documentation.html)

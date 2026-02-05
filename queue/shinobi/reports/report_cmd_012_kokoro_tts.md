## Kokoro TTS (Text-to-Speech)

Kokoro TTS is a lightweight and efficient open-weight Text-to-Speech library for Python. It is built upon the StyleTTS 2 architecture and is notable for its high-quality audio generation, multilingual support, and performance, even on CPU.

### 1. Installation

**pip install command**

You can install Kokoro TTS directly using pip:

```bash
pip install kokoro-tts
```

**Dependencies**

The library requires PyTorch. For GPU acceleration, you must install a version of PyTorch that is compatible with your CUDA toolkit. Other dependencies are installed automatically.

```bash
# For CPU
pip install torch

# For NVIDIA GPU (example for CUDA 12.1)
pip install torch --index-url https://download.pytorch.org/whl/cu121
```

**Model Download**

Models are downloaded automatically the first time you initialize a pipeline for a specific language. They are cached locally for future use.

### 2. Basic Usage

**Text to speech conversion**

The core of the library is the `KPipeline` class, which handles model loading and inference.

```python
from kokoro_tts import KPipeline

# Initialize the pipeline for Japanese
tts_pipeline = KPipeline(lang="ja")

# Text to be converted to speech
text = "こんにちは、これは心TTSのテストです。"

# Generate audio
wav, sr = tts_pipeline(text)

print(f"Generated audio with sample rate: {sr}")
# 'wav' is a PyTorch tensor containing the audio waveform
```

**Japanese language model selection**

Language is specified during pipeline initialization with the `lang` parameter. For Japanese, use `"ja"`.

```python
# Other supported languages include:
# en, es, fr, zh, hi, it, pt
tts_pipeline_en = KPipeline(lang="en")
tts_pipeline_es = KPipeline(lang="es")
```

**Voice/speaker selection**

You can list available speakers for a language and select one using the `speaker_name` parameter.

```python
from kokoro_tts import KPipeline

tts_pipeline = KPipeline(lang="ja")

# List available Japanese speakers
available_speakers = tts_pipeline.list_speakers()
print("Available Japanese speakers:", available_speakers)

# Generate speech with a specific speaker
speaker = available_speakers[0] # Using the first available speaker
wav, sr = tts_pipeline("特定の声で話します。", speaker_name=speaker)
```

**Speed and pitch adjustment**

The synthesis speed can be controlled via the `speed` parameter. A value of `1.0` is the default, with lower values being slower and higher values being faster. Direct pitch control is not explicitly available, but can be influenced by the chosen speaker.

```python
from kokoro_tts import KPipeline

tts_pipeline = KPipeline(lang="ja")

# Slower speech
wav_slow, sr = tts_pipeline("これは少しゆっくりしたスピーチです。", speed=0.8)

# Faster speech
wav_fast, sr = tts_pipeline("これは少し速いスピーチです。", speed=1.2)
```

### 3. Audio Output

**Save to WAV file**

The pipeline returns a PyTorch tensor which can be saved to a WAV file using libraries like `scipy` or `soundfile`.

```python
import scipy.io.wavfile
from kokoro_tts import KPipeline

tts_pipeline = KPipeline(lang="ja")
text = "音声をファイルに保存します。"
wav, sr = tts_pipeline(text)

# Save the audio to a WAV file
# The tensor needs to be moved to CPU and converted to a NumPy array
scipy.io.wavfile.write("output.wav", rate=sr, data=wav.cpu().numpy())

print("Audio saved to output.wav")
```

**Save to MP3 (if supported)**

Kokoro TTS does not natively support MP3 output. To save as MP3, you can first generate a WAV file and then convert it using a library like `pydub`, which requires `ffmpeg`.

```python
# First, install pydub and ffmpeg
# pip install pydub
# sudo apt-get install ffmpeg (on Debian/Ubuntu)

import scipy.io.wavfile
from kokoro_tts import KPipeline
from pydub import AudioSegment

tts_pipeline = KPipeline(lang="ja")
text = "音声をMP3ファイルに保存します。"
wav, sr = tts_pipeline(text)

# Save as temporary WAV
temp_wav_path = "temp_for_mp3.wav"
scipy.io.wavfile.write(temp_wav_path, rate=sr, data=wav.cpu().numpy())

# Convert WAV to MP3
audio = AudioSegment.from_wav(temp_wav_path)
audio.export("output.mp3", format="mp3")

print("Audio saved to output.mp3")
```

**Audio format options**

The sample rate is determined by the pre-trained model (typically 24000 Hz). The output is a single-channel (mono) 32-bit floating-point waveform.

### 4. Advanced Features

**Async support**

The library does not have native `asyncio` support. For use in asynchronous applications, you should run the TTS generation in a thread pool executor to avoid blocking the event loop.

```python
import asyncio
from kokoro_tts import KPipeline
import scipy.io.wavfile

# This should be a single instance in your application
tts_pipeline = KPipeline(lang="ja")

async def generate_speech_async(text, loop):
    def sync_generate():
        # This synchronous function will run in a separate thread
        return tts_pipeline(text)

    # Run the synchronous call in a thread pool executor
    wav, sr = await loop.run_in_executor(None, sync_generate)
    scipy.io.wavfile.write("async_output.wav", rate=sr, data=wav.cpu().numpy())
    print("Async audio generation complete.")

async def main():
    loop = asyncio.get_running_loop()
    await generate_speech_async("非同期で音声を生成します。", loop)

if __name__ == "__main__":
    asyncio.run(main())
```

**GPU acceleration**

If you have a compatible NVIDIA GPU and have installed the CUDA-enabled version of PyTorch, Kokoro TTS will automatically use the GPU for faster inference. You can explicitly move the pipeline to a device.

```python
import torch
from kokoro_tts import KPipeline

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

# The pipeline will be moved to the specified device
tts_pipeline = KPipeline(lang="ja", device=device)

wav, sr = tts_pipeline("GPUで高速に音声を生成します。")
```

**Batch processing**

The pipeline currently processes one text input at a time. For batch processing, you can iterate through a list of texts.

### 5. Error Handling

**Common errors and solutions**

-   **`FileNotFoundError` or model download issues**: This can happen due to network problems. Ensure you have a stable internet connection when running the pipeline for the first time for a new language. You can try deleting the cached models (usually in `~/.cache/kokoro_tts/`) to force a fresh download.
-   **CUDA errors**: If you encounter GPU-related errors, ensure your NVIDIA drivers, CUDA toolkit, and PyTorch version are compatible. You can force CPU usage by setting `device="cpu"` during pipeline initialization.
-   **Invalid Speaker Name**: Ensure the `speaker_name` exists for the selected language by checking `list_speakers()`.

### Integration Pattern for News Anchor Use Case

This example demonstrates a simple pattern for a news broadcast script. It reads sentences from a list and synthesizes them sequentially, simulating a news anchor reading a report.

```python
import scipy.io.wavfile
import numpy as np
from kokoro_tts import KPipeline

def create_news_report(script, speaker, output_file):
    """
    Generates a single audio file from a script, with pauses between sentences.
    """
    print("Initializing TTS pipeline for news report...")
    tts_pipeline = KPipeline(lang="ja")

    # Check if the requested speaker is valid
    available_speakers = tts_pipeline.list_speakers()
    if speaker not in available_speakers:
        print(f"Speaker '{speaker}' not found. Using default.")
        # Fallback to the first available speaker if the desired one isn't found
        speaker = available_speakers[0]
        
    print(f"Using speaker: {speaker}")

    # A short silent pause to insert between sentences
    sample_rate = 24000 # Kokoro's default sample rate
    pause_duration_ms = 500
    pause = np.zeros(int(sample_rate * pause_duration_ms / 1000), dtype=np.float32)

    full_audio = []
    print("Generating audio for each sentence in the script...")
    for i, sentence in enumerate(script):
        print(f"Synthesizing line {i+1}/{len(script)}: '{sentence}'")
        wav, sr = tts_pipeline(sentence, speaker_name=speaker, speed=1.0)
        
        # Append the generated audio and a pause
        full_audio.append(wav.cpu().numpy())
        if i < len(script) - 1: # Don't add a pause after the last sentence
            full_audio.append(pause)
    
    # Concatenate all parts into a single audio array
    final_audio = np.concatenate(full_audio)

    # Save the final report
    scipy.io.wavfile.write(output_file, rate=sample_rate, data=final_audio)
    print(f"\nNews report successfully saved to {output_file}")


if __name__ == "__main__":
    # A script for a short news segment
    news_script = [
        "こんばんは、ニュースです。",
        "本日、新しい音声合成技術が公開されました。",
        "この技術は、自然で高品質な音声を生成することができます。",
        "以上、ニュースでした。"
    ]

    # Name of a desired Japanese female speaker
    # Note: available speakers may change, check with tts_pipeline.list_speakers()
    desired_speaker = "ja-female-1" 

    create_news_report(news_script, desired_speaker, "news_report.wav")
```

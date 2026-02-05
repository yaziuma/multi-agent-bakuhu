## Kokoro TTS (v2.3.0+) API Investigation Report

Based on the investigation of the `kokoro` package (the correct package name for `kokoro-tts`), here is a complete guide to its API and usage, addressing the errors you've encountered. The primary source of confusion is that the method names you were trying to use (`.tts()`, `.list_voices()`) are not the correct ones for this library.

---

### 1. KPipeline Complete Method List

The `KPipeline` class is the main entry point for using Kokoro. The old methods you were trying to use do not exist. Here are the correct, primary methods and their usage:

*   **`__init__(self, lang_code, model_name='g', device=None)`**
    *   **Purpose:** Initializes the TTS pipeline for a specific language.
    *   **Parameters:**
        *   `lang_code` (str): The language code. For Japanese, use `'j'`.
        *   `model_name` (str, optional): The model to use. Defaults to `'g'`.
        *   `device` (str, optional): The device to run on (e.g., `'cuda'`, `'cpu'`). Automatically detected if not provided.
    *   **Usage:**
        ```python
        from kokoro import KPipeline
        pipeline = KPipeline(lang_code='j')
        ```

*   **`__call__(self, text, voice)`**
    *   **Purpose:** This is the main text-to-speech generation method. It takes text and returns a generator that yields audio chunks. It replaces the non-existent `.tts()` method.
    *   **Parameters:**
        *   `text` (str): The text to synthesize.
        *   `voice` (str): The name of the voice to use.
    *   **Returns:** A generator that yields tuples of `(graphemes, phonemes, audio_tensor)`.
    *   **Usage:**
        ```python
        generator = pipeline("こんにちは、世界。", voice='jf_alpha')
        ```

*   **`g2p(self, text)`**
    *   **Purpose:** Performs Grapheme-to-Phoneme conversion. This is an internal method, and you generally do not need to call it directly, as the main `__call__` method handles it.
    *   **Note:** The error `‘str’ object has no attribute ‘phonemes’` likely occurred because you were trying to access phonemes from a string directly. The correct way is to get them from the generator returned by the pipeline.

---

### 2. Text-to-Speech Complete Flow

Here is the correct, step-by-step process to convert text to a WAV file.

1.  **Import necessary libraries:** `KPipeline`, `soundfile`, and `torch`.
2.  **Initialize `KPipeline`:** Create an instance for the desired language (e.g., Japanese).
3.  **Call the pipeline:** Pass the text and a valid voice name to the pipeline object. This returns a generator.
4.  **Iterate and process:** Loop through the generator to get audio chunks. Each chunk is a PyTorch tensor.
5.  **Concatenate audio:** Collect all audio tensors into a list.
6.  **Save to file:** Use `torch.cat` to combine the chunks into a single tensor and `soundfile.write` to save it as a WAV file.

**Complete Code Example:**

```python
import torch
import soundfile as sf
from kokoro import KPipeline

# 1. Initialize KPipeline for Japanese
print("Initializing pipeline for Japanese...")
pipeline = KPipeline(lang_code='j')

# 2. Define Japanese text and select a voice
text = "こんにちは、これはkokoro TTSのテストです。"
# Recommended Japanese female voice: 'jf_alpha'
# Recommended Japanese male voice: 'jm_kumo'
voice = 'jf_alpha' 

# 3. Generate audio by calling the pipeline
print(f"Generating speech for: '{text}' with voice '{voice}'...")
generator = pipeline(text, voice=voice)

# 4. Collect audio chunks from the generator
audio_chunks = []
for i, (gs, ps, audio) in enumerate(generator):
    print(f"  - Processing chunk {i+1}: Graphemes: {gs} | Phonemes: {ps}")
    audio_chunks.append(audio)

# 5. Combine chunks and save to a WAV file
if audio_chunks:
    full_audio = torch.cat(audio_chunks, dim=0)
    output_filename = "output_japanese_speech.wav"
    sample_rate = 24000  # Kokoro models operate at 24kHz
    
    sf.write(output_filename, full_audio, sample_rate)
    print(f"\nAudio successfully saved to {output_filename}")
else:
    print("No audio was generated.")

```

---

### 3. Japanese Language Support

*   **Correct Parameter:** Use `lang_code='j'` when initializing `KPipeline`.
*   **Required Dependencies:** To add Japanese language support, you must install `misaki` with the `[ja]` extra. This will automatically install `fugashi`, `ipadic`, and `pyopenjtalk`.
    ```bash
    pip install "misaki[ja]"
    ```
    You also need the `espeak-ng` system package. On Debian/Ubuntu:
    ```bash
    sudo apt-get update && sudo apt-get install espeak-ng
    ```

---

### 4. Available Voices/Speakers

There is no `.list_voices()` method. The available voices are documented in the project's `VOICES.md` file.

*   **How to get the list:** You must refer to the official documentation or the `VOICES.md` file in the GitHub repository.
*   **Default Voice:** There is no default voice; you must specify one.
*   **Recommended Japanese Voices:**
    *   **Female:** `jf_alpha`, `jf_gongitsune`, `jf_nezumi`, `jf_tebukuro`
    *   **Male:** `jm_kumo`

---

### 5. Output Format

*   **Return Type:** The pipeline returns a **generator**. Each item yielded by the generator is a tuple `(graphemes, phonemes, audio_tensor)`.
*   **Audio Data:** The audio data is a **PyTorch Tensor**.
*   **Sample Rate:** The sample rate is **24000 Hz**.
*   **Saving with `torchaudio.save()`:** You can use `torchaudio.save()` as well. The principle is the same.
    ```python
    import torchaudio
    # Assuming full_audio is the concatenated tensor
    # and sample_rate is 24000
    torchaudio.save("output.wav", full_audio.unsqueeze(0), sample_rate)
    ```
*   **Waveform Shape:** The tensor from the generator is a 1-dimensional tensor (a flat waveform). `torchaudio.save` expects a shape of `(channels, samples)`, so you may need to `unsqueeze(0)` it.

---

### 6. Dependencies

**Complete Dependency List for Japanese:**

1.  **Core Python Packages:**
    ```bash
    pip install kokoro soundfile torch
    ```
2.  **Japanese Language Support:**
    ```bash
    pip install "misaki[ja]"
    ```
3.  **System-Level Package:**
    *   `espeak-ng` (Install via your system's package manager, e.g., `apt-get`, `brew`).

---

### 7. Complete Working Python Script

This script incorporates all the findings into a single, runnable file.

```python
# Filename: generate_japanese_tts.py
# Description: A complete example to generate Japanese speech using kokoro-tts.
#
# Installation:
# 1. Install system dependency:
#    - sudo apt-get update && sudo apt-get install espeak-ng (for Debian/Ubuntu)
# 2. Install Python packages:
#    - pip install kokoro soundfile torch "misaki[ja]"

import torch
import soundfile as sf
from kokoro import KPipeline
import sys

def generate_tts(text: str, voice: str, output_filename: str):
    """
    Initializes the Kokoro TTS pipeline and generates speech from text,
    saving it to a WAV file.
    """
    try:
        # --- Initialization ---
        print("Initializing Kokoro TTS pipeline for Japanese (lang_code='j')...")
        # This might take a moment on first run as it downloads the model.
        pipeline = KPipeline(lang_code='j')
        
        # --- Audio Generation ---
        print(f"Generating speech for the text: '{text}'")
        print(f"Using voice: '{voice}'")
        generator = pipeline(text, voice=voice)

        # --- Process and Collect Audio Chunks ---
        audio_chunks = []
        print("Processing generated audio chunks...")
        for i, (gs, ps, audio) in enumerate(generator):
            print(f"  - Chunk {i+1}: Graphemes='{gs}'")
            audio_chunks.append(audio)

        if not audio_chunks:
            print("Error: No audio was generated. The input text might be too short or invalid.")
            return

        # --- Save to File ---
        full_audio = torch.cat(audio_chunks, dim=0)
        sample_rate = 24000  # Kokoro's fixed sample rate

        print(f"Saving audio to '{output_filename}' at {sample_rate}Hz...")
        sf.write(output_filename, full_audio, sample_rate)
        
        print("\n--- Success! ---")
        print(f"Audio file saved successfully: {output_filename}")

    except ImportError as e:
        print(f"\n--- Dependency Error ---", file=sys.stderr)
        print(f"An import error occurred: {e}", file=sys.stderr)
        print("Please ensure all required packages are installed:", file=sys.stderr)
        print("  pip install kokoro soundfile torch \"misaki[ja]\"", file=sys.stderr)
        print("And that 'espeak-ng' is installed on your system.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"\n--- An unexpected error occurred ---", file=sys.stderr)
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    japanese_text = "明日は晴れるでしょう。音声合成のテストは成功です。"
    # You can choose other Japanese voices: jf_gongitsune, jf_nezumi, jf_tebukuro, jm_kumo
    selected_voice = "jf_alpha" 
    output_file = "kokoro_japanese_output.wav"
    
    generate_tts(japanese_text, selected_voice, output_file)
```

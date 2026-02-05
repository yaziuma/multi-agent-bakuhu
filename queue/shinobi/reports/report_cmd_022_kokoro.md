# kokoro-tts Python Library Research

This document provides a detailed overview of the `kokoro` Python library for Text-to-Speech (TTS), focusing on version 2.3.0 and newer paradigms.

## 1. Package Information

-   **What is kokoro-tts?**: `kokoro` is the official Python inference library for **Kokoro-82M**, an 82-million parameter open-weight TTS model. It is designed to be lightweight, fast, and high-quality. The weights are Apache 2.0 licensed, allowing for commercial use. The library you interact with programmatically is called `kokoro` on PyPI, while `kokoro-tts` is a separate community-built CLI tool.

-   **Latest Version and Changelog**: The library is under active development. As of early 2026, the team is working towards a stable `v2.x.x` series. The v1.0 release (Jan 2025) supports 5 languages and over 40 voices. For the most current version and detailed changes, refer to the project's GitHub releases page and the `CHANGELOG.md` file in the repository.

-   **GitHub Repository**: The official source code and documentation can be found on GitHub:
    -   **URL**: `https://github.com/hexgrad/kokoro`

## 2. API Investigation

-   **Main Classes and Functions**: The primary entry point for using the TTS is the `KPipeline` class. This class handles model loading, text processing, and audio synthesis.

-   **Is there a 'KPipeline' class?**: Yes. `KPipeline` is the correct and central class for all TTS operations in the `kokoro` library.

-   **How to import the main TTS pipeline class**: You import the class directly from the `kokoro` package:
    ```python
    from kokoro import KPipeline
    ```

-   **Constructor Parameters**: The `KPipeline` constructor accepts several arguments to configure the TTS engine. The most important is `lang` to specify the language.
    ```python
    # Constructor signature example
    pipeline = KPipeline(lang: str = 'en', device: str = 'cpu')
    ```
    -   `lang`: An ISO 639-1 language code (e.g., `'en'`, `'ja'`).
    -   `device`: The compute device to use, such as `'cpu'` or `'cuda'`. Models are loaded onto the specified device.

## 3. Usage Example

-   **Complete working example for Japanese TTS**:
    The following example demonstrates how to initialize the pipeline for Japanese, list available voices, synthesize text, and save the output as a WAV file.

    ```python
    import torch
    import torchaudio
    from kokoro import KPipeline

    # 1. Initialize the pipeline for Japanese
    # This will automatically download the model on first run (lazy loading)
    print("Initializing TTS pipeline for Japanese...")
    pipeline = KPipeline(lang='ja')

    # 2. List available speakers/voices for the loaded language
    print("Available voices for Japanese:")
    voices = pipeline.list_voices()
    for i, voice in enumerate(voices):
        print(f"{i}: {voice}")

    # 3. Define the text and select a speaker
    # Let's use the first available Japanese voice
    speaker_id = voices[0]
    text = "こんにちは、これはココロTTSのテストです。音声合成はとても簡単です。"

    print(f"\nSynthesizing text with speaker: {speaker_id}")

    # 4. Synthesize text to audio
    # The tts() method returns a dictionary containing the audio tensor and sample rate
    output = pipeline.tts(
        text=text,
        speaker=speaker_id,
        # Optional parameters:
        # speed=1.0,
        # silence_duration_s=0.25,
    )

    # 5. Get the output tensor and sample rate
    waveform = output["waveform"]
    sample_rate = output["sample_rate"]

    print(f"Synthesis complete. Waveform shape: {waveform.shape}, Sample rate: {sample_rate} Hz")

    # 6. Save the audio to a file
    # The output is a PyTorch tensor, needs to be moved to CPU if on CUDA
    if waveform.is_cuda:
        waveform = waveform.cpu()

    # The shape might be (1, N) or (N,). Ensure it's (1, N) for torchaudio.save
    if waveform.ndim == 1:
        waveform = waveform.unsqueeze(0)

    output_filename = "kokoro_output_ja.wav"
    torchaudio.save(output_filename, waveform, sample_rate)

    print(f"Audio saved to {output_filename}")
    ```

-   **Output Format**: The `tts()` method returns a dictionary containing:
    -   `waveform`: A `torch.Tensor` of the audio data.
    -   `sample_rate`: An `int` representing the audio sample rate (e.g., 24000 Hz).

## 4. Common Issues

-   **ImportError Troubleshooting**: An `ImportError: cannot import name 'KPipeline' from 'kokoro'` usually means a dependency is missing or there's a version conflict.
    -   **Solution**: Ensure you have installed all required dependencies. The library relies on `PyTorch`, `torchaudio`, and others. Install them from the `requirements.txt` file in the GitHub repository:
        ```bash
        pip install -r https://raw.githubusercontent.com/hexgrad/kokoro/main/requirements.txt
        ```

-   **PortAudio Dependency Handling**: The `kokoro` library itself does not have a hard dependency on `PortAudio`. However, libraries often used alongside it for real-time audio playback, such as `pyaudio` or `sounddevice`, do require it.
    -   **Solution**: If you need to play audio directly, you must install PortAudio on your system first.
        -   **On Debian/Ubuntu**: `sudo apt-get install libportaudio2`
        -   **On macOS (using Homebrew)**: `brew install portaudio`

-   **Lazy Loading Patterns**: The `kokoro` library uses a lazy loading pattern. Models are not downloaded or loaded into memory when you install the package. They are automatically fetched and cached the first time you instantiate `KPipeline` for a specific language. This keeps the initial installation lightweight.

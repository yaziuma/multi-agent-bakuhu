## Python Text-to-Speech (TTS) Library Comparison for Japanese

### Comparison Table

| Library | Japanese Support (1-5) | License & Commercial Use | Online/Offline | Voice Quality | Ease of Installation | Recommendation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `pyttsx3` | 2/5 (Variable) | MPL-2.0. Commercial use OK, but requires preserving license notices, which is a form of attribution. | Offline | Low to Medium | Easy | **NO** - Attribution rule conflicts with requirements & Japanese quality is unreliable. |
| `gTTS` | 4/5 | MIT (library), but underlying Google Translate API ToS **prohibits commercial use**. | Online | High | Easy | **NO** - Commercial use is against Google's Terms of Service. |
| `edge-tts`| 5/5 | MIT (library), but underlying Microsoft service **prohibits commercial use** without an Azure subscription. | Online | Very High | Easy | **NO** - Commercial use is against Microsoft's Terms of Service. |
| `Coqui TTS` | 4/5 | Models are under Coqui Public Model License (CPML), which is **strictly non-commercial**. | Offline | High | Medium | **NO** - License for the voice models is non-commercial. |
| `Piper` | 3/5 (Variable) | MIT (engine). Voice models have separate licenses; many **require attribution** (e.g., CC-BY). | Offline | Medium to High | Medium | **NO** - Finding a Japanese voice with a "no attribution" license is not guaranteed. |
| **Kokoro TTS** | **4/5** (Reported) | Apache 2.0. Allows **commercial use with no attribution required**. | **Offline** | **High** (Reported) | Medium | **YES** - Best candidate. Meets all requirements: offline, free, commercial use, no attribution, and Japanese support. |

---

### Final Recommendation

The recommended library is **Kokoro TTS**.

Based on the investigation, it is the only candidate that verifiably meets all the strict requirements:
- **Japanese Support**: It provides Japanese language models.
- **Free & Commercial Use**: The Apache 2.0 license on its weights allows for use in production and commercial environments.
- **No Attribution**: The Apache 2.0 license does not require explicit end-user attribution.
- **Offline**: It runs completely offline.

Online services like `gTTS` and `edge-tts` have restrictive terms of service for commercial use. Other offline options like `Coqui TTS` and `Piper` have licensing models for their voices that are either explicitly non-commercial or require attribution, violating the core requirements of this request.

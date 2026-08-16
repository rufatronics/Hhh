# Tinol Distribution Options

Tinol can be built and distributed in two primary ways depending on your needs for file size and user experience.

## 1. Small APK (Model-on-Demand)
This version is lightweight and downloads the AI model only when needed.

*   **Initial Size:** ~15 MB
*   **Total Size:** ~250 MB (after model download)
*   **Best For:** Fast initial downloads, users with limited data, or app stores with strict size limits.
*   **How it works:** 
    - The app checks for the model file at startup.
    - If missing, it displays a "Download" screen.
    - It fetches `Bonsai-1.7B-Q1_0.gguf` directly from Hugging Face.
*   **Build Instruction:** Simply build the project as-is. Do **not** place the model in the `assets/` folder.

## 2. Full APK (All-in-One)
This version comes pre-packaged with the AI model and is ready to use immediately after installation.

*   **Initial Size:** ~250 MB
*   **Total Size:** ~250 MB
*   **Best For:** Offline-only environments, enterprise deployment, or providing the best "out-of-the-box" experience.
*   **How it works:**
    - The model is baked into the APK assets.
    - On first run, the app extracts the model to its local storage.
    - No internet connection is required at any point.
*   **Build Instruction:**
    1. Download the model: `https://huggingface.co/prism-ml/Bonsai-1.7B-gguf/resolve/main/Bonsai-1.7B-Q1_0.gguf`
    2. Place it in: `app/src/main/assets/models/Bonsai-1.7B-Q1_0.gguf`
    3. Build the APK in Android Studio.

---

## Automation Script
We have provided a script to help you prepare the **Full APK** build:

```bash
./scripts/prepare_full_build.sh
```
This script will automatically download the model and place it in the correct directory for baking into the APK.

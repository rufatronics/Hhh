# Tinol: Offline Bonsai Chat for Android

Tinol is a production-ready Android application that provides offline AI chat capabilities using the Bonsai 1.7B model.

## Features
- **Offline Inference**: Powered by PrismML Llama.cpp and the Bonsai 1.7B (1-bit quantized) GGUF model.
- **Dual Distribution Modes**: Choose between a **Small APK** (15MB + in-app download) or a **Full APK** (250MB pre-baked).
- **Low-Latency**: Optimized for arm64-v8a devices with 32-bit compatibility fixes.
- **Privacy-First**: No data leaves the device; all processing is local.
- **Wide Compatibility**: Supports Android devices from API Level 21 (Android 5.0) up to the latest versions.

## Project Structure
- `app/`: Android application source code (Kotlin).
- `app/src/main/cpp/`: JNI wrappers for native integration.
- `scripts/`: Helper scripts for CI/CD, model downloading, and native builds.
- `.github/workflows/`: GitHub Actions for automated builds and releases.

## Local Build Instructions

Tinol supports two build modes. See [DISTRIBUTION.md](DISTRIBUTION.md) for full details.

### Quick Start (Small APK)
1.  **Prerequisites**: Android Studio, NDK (r25), CMake.
2.  **Build**: Open in Android Studio and click **Build APK**.
3.  **Run**: The app will prompt you to download the model on first launch.

### Full Build (Model Pre-baked)
1.  **Prepare**: Run `./scripts/prepare_full_build.sh` to download and place the model in assets.
2.  **Build**: Open in Android Studio and click **Build APK**.
3.  **Result**: A single ~250MB APK that works entirely offline from the start.

## CI/CD Pipeline
The project includes a fully automated GitHub Actions pipeline that:
1. Sets up the Android build environment.
2. Clones the optimized PrismML Llama.cpp runtime.
3. Compiles native libraries for `arm64-v8a` and `armeabi-v7a`.
4. Downloads the Bonsai model and packages it as an asset.
5. Builds and signs (debug/release) APKs.
6. Publishes artifacts to GitHub Releases on tag.

## About
Developed by Aga for users seeking robust, offline-capable AI solutions on Android.

## License
- **App**: Apache-2.0
- **Model**: Apache-2.0 (PrismML)
- **Runtime**: MIT (llama.cpp)

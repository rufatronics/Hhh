# Tinol: Offline Bonsai Chat for Android

Tinol is a production-ready Android application that provides offline AI chat capabilities using the Bonsai 1.7B model.

## Features
- **Offline Inference**: Powered by PrismML Llama.cpp and the Bonsai 1.7B (1-bit quantized) GGUF model.
- **Low-Latency**: Optimized for arm64-v8a devices.
- **Privacy-First**: No data leaves the device; all processing is local.
- **Wide Compatibility**: Supports Android devices from API Level 21 (Android 5.0) up to the latest versions.

## Project Structure
- `app/`: Android application source code (Kotlin).
- `app/src/main/cpp/`: JNI wrappers for native integration.
- `scripts/`: Helper scripts for CI/CD, model downloading, and native builds.
- `.github/workflows/`: GitHub Actions for automated builds and releases.

## Local Build Instructions
1. **Prerequisites**:
   - Android Studio / Android SDK
   - Android NDK (r25 LTS recommended)
   - CMake 3.22+
2. **Clone Native Runtime**:
   ```bash
   git clone --depth 1 -b prism https://github.com/PrismML-Eng/llama.cpp.git
   ```
3. **Download Model**:
   Run `./scripts/download_model.sh` or manually download `Bonsai-1.7B-Q1_0.gguf` to `app/src/main/assets/models/`.
4. **Build**:
   Open the project in Android Studio and click "Build".

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

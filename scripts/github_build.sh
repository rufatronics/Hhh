#!/bin/bash
set -e

echo "Starting Tinol GitHub Build Process..."

# 1. Setup Model
mkdir -p app/src/main/assets/models
echo "Downloading Bonsai 1.7B model for baking..."
wget -q -O app/src/main/assets/models/Bonsai-1.7B-Q1_0.gguf "https://huggingface.co/prism-ml/Bonsai-1.7B-gguf/resolve/main/Bonsai-1.7B-Q1_0.gguf"

# 2. Setup Native Runtime
echo "Cloning PrismML Llama runtime..."
git clone --depth 1 -b prism https://github.com/PrismML-Eng/llama.cpp.git

# 3. Apply Patches
echo "Applying native patches..."
chmod +x scripts/patch_llama.sh
./scripts/patch_llama.sh

# 4. Build
echo "Building APKs..."
chmod +x gradlew
./gradlew assembleDebug assembleRelease

echo "Build Complete!"
find app/build/outputs/apk -name "*.apk"

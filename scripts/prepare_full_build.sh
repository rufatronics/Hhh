#!/bin/bash

# Tinol - Full Build Preparation Script
# This script downloads the Bonsai model and places it in the assets folder for a "Full APK" build.

MODEL_URL="https://huggingface.co/prism-ml/Bonsai-1.7B-gguf/resolve/main/Bonsai-1.7B-Q1_0.gguf"
ASSET_DIR="../app/src/main/assets/models"
MODEL_NAME="Bonsai-1.7B-Q1_0.gguf"

echo "----------------------------------------------------"
echo "Tinol: Preparing Full Build (Baking model into APK)"
echo "----------------------------------------------------"

# Create directory if it doesn't exist
mkdir -p "$ASSET_DIR"

echo "Downloading Bonsai 1.7B model..."
if command -v wget > /dev/null; then
    wget -O "$ASSET_DIR/$MODEL_NAME" "$MODEL_URL"
elif command -v curl > /dev/null; then
    curl -L -o "$ASSET_DIR/$MODEL_NAME" "$MODEL_URL"
else
    echo "Error: Neither wget nor curl found. Please download the model manually."
    exit 1
fi

echo ""
echo "Success! The model is now in $ASSET_DIR."
echo "You can now build the APK in Android Studio to get the 'Full' version."
echo "----------------------------------------------------"

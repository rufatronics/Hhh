#!/bin/bash
set -e
# Create the directory in the standard location
mkdir -p app/src/main/assets/models
# Copy assets
cp -f downloads/Bonsai-1.7B-Q1_0.gguf app/src/main/assets/models/
cp -f downloads/tokenizer.json app/src/main/assets/models/
cp -f downloads/vocab.json app/src/main/assets/models/
echo "Assets packaged successfully."
ls -lh app/src/main/assets/models/

#!/bin/bash
set -e
mkdir -p app/src/main/assets/models
cp downloads/Bonsai-1.7B-Q1_0.gguf app/src/main/assets/models/
cp downloads/tokenizer.json app/src/main/assets/models/
cp downloads/vocab.json app/src/main/assets/models/

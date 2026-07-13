#!/bin/bash
set -e
MODEL_URL="https://huggingface.co/prism-ml/Bonsai-1.7B-gguf/resolve/main/Bonsai-1.7B-Q1_0.gguf"
TOKENIZER_URL="https://huggingface.co/Qwen/Qwen3-8B/resolve/main/tokenizer.json"
VOCAB_URL="https://huggingface.co/Qwen/Qwen3-8B/resolve/main/vocab.json"

mkdir -p downloads

echo "Downloading Bonsai model..."
if [ ! -f "downloads/Bonsai-1.7B-Q1_0.gguf" ]; then
  for i in {1..3}; do
    curl -L "$MODEL_URL" -o downloads/Bonsai-1.7B-Q1_0.gguf && break || sleep 10
  done
else
  echo "Model already exists in downloads/"
fi

echo "Downloading Tokenizer..."
if [ ! -f "downloads/tokenizer.json" ]; then
  for i in {1..3}; do
    curl -L "$TOKENIZER_URL" -o downloads/tokenizer.json && break || sleep 5
  done
else
  echo "Tokenizer already exists in downloads/"
fi

echo "Downloading Vocab..."
if [ ! -f "downloads/vocab.json" ]; then
  for i in {1..3}; do
    curl -L "$VOCAB_URL" -o downloads/vocab.json && break || sleep 5
  done
else
  echo "Vocab already exists in downloads/"
fi

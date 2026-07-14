#!/bin/bash
# Patch llama.cpp for Android compatibility

LLAMA_MMAP="llama.cpp/src/llama-mmap.cpp"
if [ -f "$LLAMA_MMAP" ]; then
    if ! grep -q "POSIX_MADV_WILLNEED" "$LLAMA_MMAP"; then
        echo "POSIX_MADV_WILLNEED not found in $LLAMA_MMAP, skipping patch."
    elif grep -q "#ifdef __ANDROID__" "$LLAMA_MMAP"; then
        echo "$LLAMA_MMAP already patched."
    else
        echo "Patching $LLAMA_MMAP for Android POSIX_MADV_* compatibility..."
        sed -i '/#include <algorithm>/a \
#ifdef __ANDROID__ \
#include <sys/mman.h> \
#ifndef POSIX_MADV_WILLNEED \
#define POSIX_MADV_WILLNEED MADV_WILLNEED \
#endif \
#ifndef POSIX_MADV_RANDOM \
#define POSIX_MADV_RANDOM MADV_RANDOM \
#endif \
#endif' "$LLAMA_MMAP"
    fi
fi

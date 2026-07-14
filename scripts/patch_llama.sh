#!/bin/bash
# Patch llama.cpp for Android compatibility

LLAMA_MMAP="llama.cpp/src/llama-mmap.cpp"
if [ -f "$LLAMA_MMAP" ]; then
    echo "Patching $LLAMA_MMAP for Android compatibility..."
    # Replace posix_madvise with madvise and POSIX_MADV_* with MADV_*
    sed -i 's/posix_madvise/madvise/g' "$LLAMA_MMAP"
    sed -i 's/POSIX_MADV_WILLNEED/MADV_WILLNEED/g' "$LLAMA_MMAP"
    sed -i 's/POSIX_MADV_RANDOM/MADV_RANDOM/g' "$LLAMA_MMAP"
    # Ensure <sys/mman.h> is included
    if ! grep -q "#include <sys/mman.h>" "$LLAMA_MMAP"; then
        sed -i '1i #include <sys/mman.h>' "$LLAMA_MMAP"
    fi
fi

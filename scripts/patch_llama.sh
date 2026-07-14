#!/bin/bash
set -e

# 1. Fix posix_madvise in llama-mmap.cpp
LLAMA_MMAP="llama.cpp/src/llama-mmap.cpp"
if [ -f "$LLAMA_MMAP" ]; then
    echo "Patching $LLAMA_MMAP for Android compatibility..."
    # Ensure sys/mman.h is included
    if ! grep -q "#include <sys/mman.h>" "$LLAMA_MMAP"; then
        sed -i '1i #include <sys/mman.h>' "$LLAMA_MMAP"
    fi
    # Replace posix_madvise with madvise and map POSIX_MADV_* constants
    sed -i 's/\bposix_madvise\b/madvise/g' "$LLAMA_MMAP"
    sed -i 's/\bPOSIX_MADV_WILLNEED\b/MADV_WILLNEED/g' "$LLAMA_MMAP"
    sed -i 's/\bPOSIX_MADV_RANDOM\b/MADV_RANDOM/g' "$LLAMA_MMAP"
    sed -i 's/\bPOSIX_MADV_SEQUENTIAL\b/MADV_SEQUENTIAL/g' "$LLAMA_MMAP"
    sed -i 's/\bPOSIX_MADV_NORMAL\b/MADV_NORMAL/g' "$LLAMA_MMAP"
fi

# 2. Fix vqtbl1q_u8 in ARMv7
# We define an emulation for vqtbl1q_u8 that uses ARMv7's vtbl2_u8 (16-byte table lookup)
EMU_FUNC='
#if defined(__arm__) && !defined(__aarch64__)
#include <arm_neon.h>
#ifndef GGML_VQTBL1Q_U8_EMU_DEFINED
#define GGML_VQTBL1Q_U8_EMU_DEFINED
static inline uint8x16_t vqtbl1q_u8_android_emu(uint8x16_t a, uint8x16_t b) {
    uint8x8x2_t table;
    table.val[0] = vget_low_u8(a);
    table.val[1] = vget_high_u8(a);
    return vcombine_u8(vtbl2_u8(table, vget_low_u8(b)), vtbl2_u8(table, vget_high_u8(b)));
}
#define vqtbl1q_u8 vqtbl1q_u8_android_emu
#define ggml_vqtbl1q_u8 vqtbl1q_u8_android_emu
#endif
#endif
'

GGML_CPU_IMPL="llama.cpp/ggml/src/ggml-cpu/ggml-cpu-impl.h"
if [ -f "$GGML_CPU_IMPL" ]; then
    echo "Patching $GGML_CPU_IMPL for ARMv7 compatibility..."
    echo "$EMU_FUNC" > emu.txt
    cat emu.txt "$GGML_CPU_IMPL" > tmp.h && mv tmp.h "$GGML_CPU_IMPL"
    rm emu.txt
fi

GGML_ARM_QUANTS="llama.cpp/ggml/src/ggml-cpu/arch/arm/quants.c"
if [ -f "$GGML_ARM_QUANTS" ]; then
    echo "Patching $GGML_ARM_QUANTS for ARMv7 compatibility..."
    echo "$EMU_FUNC" > emu.txt
    cat emu.txt "$GGML_ARM_QUANTS" > tmp.c && mv tmp.c "$GGML_ARM_QUANTS"
    rm emu.txt
fi

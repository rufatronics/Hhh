#!/bin/bash
set -e

python3 -c "
import os, re

def patch_file(path, patch_func):
    if not os.path.exists(path):
        print(f'File {path} not found, skipping.')
        return
    with open(path, 'r') as f:
        content = f.read()
    new_content = patch_func(content)
    if new_content != content:
        with open(path, 'w') as f:
            f.write(new_content)
        print(f'Successfully patched {path}.')
    else:
        print(f'No changes needed for {path}.')

def patch_mmap(c):
    if '#include <sys/mman.h>' not in c:
        c = '#include <sys/mman.h>\n' + c

    # Map posix_madvise to madvise
    c = re.sub(r'\bposix_madvise\b', 'madvise', c)

    # Map POSIX_MADV_* constants
    const_map = {
        'POSIX_MADV_WILLNEED': 'MADV_WILLNEED',
        'POSIX_MADV_RANDOM': 'MADV_RANDOM',
        'POSIX_MADV_SEQUENTIAL': 'MADV_SEQUENTIAL',
        'POSIX_MADV_NORMAL': 'MADV_NORMAL'
    }
    for k, v in const_map.items():
        c = re.sub(r'\b' + k + r'\b', v, c)
    return c

def patch_cpu_impl(c):
    if 'GGML_VQTBL1Q_U8_ANDROID_PATCH' in c:
        return c

    # 1. Provide emulation
    emu = '''
#if defined(__arm__) && !defined(__aarch64__)
#include <arm_neon.h>
#ifndef GGML_VQTBL1Q_U8_ANDROID_PATCH
#define GGML_VQTBL1Q_U8_ANDROID_PATCH
static inline uint8x16_t ggml_vqtbl1q_u8_emu(uint8x16_t a, uint8x16_t b) {
    uint8x8x2_t t; t.val[0] = vget_low_u8(a); t.val[1] = vget_high_u8(a);
    return vcombine_u8(vtbl2_u8(t, vget_low_u8(b)), vtbl2_u8(t, vget_high_u8(b)));
}
#define vqtbl1q_u8 ggml_vqtbl1q_u8_emu
#define ggml_vqtbl1q_u8 ggml_vqtbl1q_u8_emu
#endif
#endif
'''
    # 2. Suppress original definition using a very flexible regex
    # Matches: [inline] [static] uint8x16_t ggml_vqtbl1q_u8 (...) { ... }
    pattern = r'((?:inline\s+static|static\s+inline)\s+uint8x16_t\s+ggml_vqtbl1q_u8\s*\(.*?\)\s*\{.*?^\})'
    replacement = r'#ifndef GGML_VQTBL1Q_U8_ANDROID_PATCH\n\1\n#endif'

    new_c = re.sub(pattern, replacement, c, flags=re.DOTALL | re.MULTILINE)
    if new_c == c:
        # Try without the ^ for the closing brace if it failed
        pattern2 = r'((?:inline\s+static|static\s+inline)\s+uint8x16_t\s+ggml_vqtbl1q_u8\s*\(.*?\)\s*\{.*?\})'
        new_c = re.sub(pattern2, replacement, c, flags=re.DOTALL)

    return emu + new_c

def patch_quants(c):
    # Ensure any bare vqtbl1q_u8 uses are mapped to ggml_vqtbl1q_u8
    # Only if it's not already prefixed
    return re.sub(r'(?<!ggml_)\bvqtbl1q_u8\b', 'ggml_vqtbl1q_u8', c)

patch_file('llama.cpp/src/llama-mmap.cpp', patch_mmap)
patch_file('llama.cpp/ggml/src/ggml-cpu/ggml-cpu-impl.h', patch_cpu_impl)
patch_file('llama.cpp/ggml/src/ggml-cpu/arch/arm/quants.c', patch_quants)
"

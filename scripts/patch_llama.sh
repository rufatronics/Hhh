#!/bin/bash
set -e

# Use Python for reliable, idempotent, surgical patching
python3 -c "
import os, re

def patch_file(path, patch_id, patch_func):
    if not os.path.exists(path):
        print(f'File {path} not found, skipping.')
        return
    with open(path, 'r') as f:
        content = f.read()

    if patch_id in content:
        print(f'File {path} already patched with {patch_id}.')
        return

    new_content = patch_func(content)
    if new_content != content:
        with open(path, 'w') as f:
            f.write(new_content)
        print(f'Successfully applied {patch_id} to {path}.')
    else:
        print(f'No changes performed for {patch_id} on {path}.')

def apply_mmap_patch(c):
    # Ensure sys/mman.h is included for madvise
    if '#include <sys/mman.h>' not in c:
        c = '#include <sys/mman.h>\n' + c
    # Map posix_madvise to madvise and associated constants
    c = re.sub(r'\bposix_madvise\b', 'madvise', c)
    c = re.sub(r'\bPOSIX_MADV_', 'MADV_', c)
    return '/* ANDROID_POSIX_PATCH */\n' + c

def apply_cpu_impl_patch(c):
    # Define emulation for vqtbl1q_u8 using vtbl2_u8 (available on ARMv7)
    emu = '''
/* ANDROID_VQTBL1Q_PATCH */
#if defined(__arm__) && !defined(__aarch64__)
#include <arm_neon.h>
#ifndef GGML_VQTBL1Q_U8_PATCHED
#define GGML_VQTBL1Q_U8_PATCHED
static inline uint8x16_t ggml_vqtbl1q_u8_emu(uint8x16_t a, uint8x16_t b) {
    uint8x8x2_t t; t.val[0] = vget_low_u8(a); t.val[1] = vget_high_u8(a);
    return vcombine_u8(vtbl2_u8(t, vget_low_u8(b)), vtbl2_u8(t, vget_high_u8(b)));
}
#define vqtbl1q_u8 ggml_vqtbl1q_u8_emu
#define ggml_vqtbl1q_u8 ggml_vqtbl1q_u8_emu
#endif
#endif
'''
    # Wrap original ggml_vqtbl1q_u8 definition to avoid redefinition
    pattern = r'((?:inline\s+static|static\s+inline)\s+uint8x16_t\s+ggml_vqtbl1q_u8\s*\(uint8x16_t\s+a,\s*uint8x16_t\s+b\)\s*\{.*?^\})'
    replacement = r'#ifndef GGML_VQTBL1Q_U8_PATCHED\n\1\n#endif'
    new_c = re.sub(pattern, replacement, c, flags=re.DOTALL | re.MULTILINE)

    return emu + new_c

def apply_quants_patch(c):
    # Map bare vqtbl1q_u8 uses to ggml_ prefix (which we patched)
    return re.sub(r'(?<!ggml_)\bvqtbl1q_u8\b', 'ggml_vqtbl1q_u8', c)

patch_file('llama.cpp/src/llama-mmap.cpp', 'ANDROID_POSIX_PATCH', apply_mmap_patch)
patch_file('llama.cpp/ggml/src/ggml-cpu/ggml-cpu-impl.h', 'ANDROID_VQTBL1Q_PATCH', apply_cpu_impl_patch)
patch_file('llama.cpp/ggml/src/ggml-cpu/arch/arm/quants.c', 'GGML_VQTBL1Q_PREFIX_PATCH', apply_quants_patch)
"

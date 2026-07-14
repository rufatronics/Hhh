#!/bin/bash
set -e

python3 -c "
import os, re

def patch_file(path, search_pattern, replacement, flags=0):
    if not os.path.exists(path):
        print(f'File {path} not found.')
        return
    with open(path, 'r') as f:
        content = f.read()
    new_content = re.sub(search_pattern, replacement, content, flags=flags)
    if new_content != content:
        with open(path, 'w') as f:
            f.write(new_content)
        print(f'Successfully patched {path}.')
    else:
        print(f'No changes needed for {path}.')

# 1. POSIX Compatibility (madvise)
mmap_path = 'llama.cpp/src/llama-mmap.cpp'
if os.path.exists(mmap_path):
    with open(mmap_path, 'r') as f:
        c = f.read()
    if '#include <sys/mman.h>' not in c:
        c = '#include <sys/mman.h>\n' + c
    c = re.sub(r'\bposix_madvise\b', 'madvise', c)
    c = re.sub(r'\bPOSIX_MADV_', 'MADV_', c)
    with open(mmap_path, 'w') as f:
        f.write(c)
    print(f'Patched {mmap_path}')

# 2. ARMv7 Intrinsic Emulation (vqtbl1q_u8)
cpu_impl_path = 'llama.cpp/ggml/src/ggml-cpu/ggml-cpu-impl.h'
pattern = r'(?:inline\s+static|static\s+inline)\s+uint8x16_t\s+ggml_vqtbl1q_u8\s*\(uint8x16_t\s+a,\s*uint8x16_t\s+b\)\s*\{.*?\}'
replacement = r'''static inline uint8x16_t ggml_vqtbl1q_u8(uint8x16_t a, uint8x16_t b) {
#if defined(__arm__) && !defined(__aarch64__)
    uint8x8x2_t t; t.val[0] = vget_low_u8(a); t.val[1] = vget_high_u8(a);
    return vcombine_u8(vtbl2_u8(t, vget_low_u8(b)), vtbl2_u8(t, vget_high_u8(b)));
#else
    uint8x16_t res;
    res[ 0] = a[b[ 0]]; res[ 1] = a[b[ 1]]; res[ 2] = a[b[ 2]]; res[ 3] = a[b[ 3]];
    res[ 4] = a[b[ 4]]; res[ 5] = a[b[ 5]]; res[ 6] = a[b[ 6]]; res[ 7] = a[b[ 7]];
    res[ 8] = a[b[ 8]]; res[ 9] = a[b[ 9]]; res[10] = a[b[10]]; res[11] = a[b[11]];
    res[12] = a[b[12]]; res[13] = a[b[13]]; res[14] = a[b[14]]; res[15] = a[b[15]];
    return res;
#endif
}'''
patch_file(cpu_impl_path, pattern, replacement, flags=re.DOTALL)

# 3. Direct uses in quants.c
quants_path = 'llama.cpp/ggml/src/ggml-cpu/arch/arm/quants.c'
patch_file(quants_path, r'(?<!ggml_)\bvqtbl1q_u8\b', 'ggml_vqtbl1q_u8')
"

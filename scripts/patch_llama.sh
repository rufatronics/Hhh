#!/bin/bash
set -e

# Use Python for reliable, one-time patching
python3 -c "
import os

def patch_file(path, patches):
    if not os.path.exists(path):
        print(f'File {path} not found, skipping.')
        return
    with open(path, 'r') as f:
        content = f.read()

    modified = False
    for search, replace in patches:
        if search in content and replace not in content:
            content = content.replace(search, replace)
            modified = True

    if modified:
        with open(path, 'w') as f:
            f.write(content)
        print(f'Patched {path}.')
    else:
        print(f'No changes needed for {path}.')

# 1. Fix posix_madvise in llama-mmap.cpp
mmap_path = 'llama.cpp/src/llama-mmap.cpp'
mmap_patches = [
    ('posix_madvise', 'madvise'),
    ('POSIX_MADV_WILLNEED', 'MADV_WILLNEED'),
    ('POSIX_MADV_RANDOM', 'MADV_RANDOM'),
    ('POSIX_MADV_SEQUENTIAL', 'MADV_SEQUENTIAL'),
    ('POSIX_MADV_NORMAL', 'MADV_NORMAL')
]
if os.path.exists(mmap_path):
    with open(mmap_path, 'r') as f:
        content = f.read()
    if '#include <sys/mman.h>' not in content:
        content = '#include <sys/mman.h>\n' + content
    for search, replace in mmap_patches:
        content = content.replace(search, replace)
    with open(mmap_path, 'w') as f:
        f.write(content)
    print(f'Patched {mmap_path} for Android POSIX compatibility.')

# 2. Fix vqtbl1q_u8 redefinition in ARMv7
cpu_impl_path = 'llama.cpp/ggml/src/ggml-cpu/ggml-cpu-impl.h'
if os.path.exists(cpu_impl_path):
    with open(cpu_impl_path, 'r') as f:
        lines = f.readlines()

    new_lines = []
    patched = False
    for line in lines:
        if 'inline static uint8x16_t ggml_vqtbl1q_u8' in line and 'GGML_VQTBL1Q_U8_EMU' not in line:
            # Inject our emulation before the function definition
            new_lines.append('#if defined(__arm__) && !defined(__aarch64__)\n')
            new_lines.append('#include <arm_neon.h>\n')
            new_lines.append('#ifndef GGML_VQTBL1Q_U8_EMU\n')
            new_lines.append('#define GGML_VQTBL1Q_U8_EMU\n')
            new_lines.append('static inline uint8x16_t ggml_vqtbl1q_u8(uint8x16_t a, uint8x16_t b) {\n')
            new_lines.append('    uint8x8x2_t table; table.val[0] = vget_low_u8(a); table.val[1] = vget_high_u8(a);\n')
            new_lines.append('    return vcombine_u8(vtbl2_u8(table, vget_low_u8(b)), vtbl2_u8(table, vget_high_u8(b)));\n')
            new_lines.append('}\n')
            new_lines.append('#endif\n')
            new_lines.append('#define GGML_VQTBL1Q_U8_SKIP\n')
            new_lines.append('#endif\n')
            new_lines.append('#ifndef GGML_VQTBL1Q_U8_SKIP\n')
            new_lines.append(line)
            patched = True
        elif patched and line.strip() == '}':
            new_lines.append(line)
            new_lines.append('#endif // GGML_VQTBL1Q_U8_SKIP\n')
            patched = False
        else:
            new_lines.append(line)

    with open(cpu_impl_path, 'w') as f:
        f.writelines(new_lines)
    print(f'Patched {cpu_impl_path} for ARMv7 intrinsic compatibility.')
"

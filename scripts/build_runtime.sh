#!/bin/bash
set -e

# Expected ANDROID_HOME or ANDROID_SDK_ROOT to be set by CI
NDK_VERSION="25.2.9519653"
ANDROID_NDK=$ANDROID_HOME/ndk/$NDK_VERSION

ABI=$1
if [ "$ABI" == "arm64" ]; then
  ABI_NAME=arm64-v8a
  PLATFORM=android-28
  CFLAGS="-march=armv8.7a"
else
  ABI_NAME=armeabi-v7a
  PLATFORM=android-21
  CFLAGS="-march=armv7-a"
fi

echo "Building optimized llama.cpp shared library for $ABI_NAME..."

if [ ! -d "llama.cpp" ]; then
  echo "ERROR: llama.cpp directory not found. Please clone it first."
  # Using return instead of exit to avoid session issues if sourced,
  # but this is a script, so we use (exit 1) in a subshell or just let set -e handle it.
  false
fi

cd llama.cpp
mkdir -p build-android-$ABI_NAME

cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=$ABI_NAME \
      -DANDROID_PLATFORM=$PLATFORM \
      -DCMAKE_C_FLAGS="$CFLAGS" \
      -DCMAKE_CXX_FLAGS="$CFLAGS" \
      -DGGML_OPENMP=OFF \
      -DGGML_LLAMAFILE=OFF \
      -DBUILD_SHARED_LIBS=ON \
      -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_SERVER=OFF \
      -DLLAMA_BUILD_BENCHMARKS=OFF \
      -DLLAMA_CUDA=OFF \
      -B build-android-$ABI_NAME 2>&1 | tee cmake_config_$ABI_NAME.log || {
        echo "ERROR: CMake configuration failed for $ABI_NAME. See llama.cpp/cmake_config_$ABI_NAME.log for details."
        false
      }

cmake --build build-android-$ABI_NAME --config Release --target llama -j$(nproc) 2>&1 | tee cmake_build_$ABI_NAME.log || {
  echo "ERROR: Compilation failed for $ABI_NAME. See llama.cpp/cmake_build_$ABI_NAME.log for details."
  false
}

cd ..
mkdir -p app/src/main/jniLibs/$ABI_NAME
if [ -f "llama.cpp/build-android-$ABI_NAME/bin/libllama.so" ]; then
  cp llama.cpp/build-android-$ABI_NAME/bin/libllama.so app/src/main/jniLibs/$ABI_NAME/
elif [ -f "llama.cpp/build-android-$ABI_NAME/lib/libllama.so" ]; then
  cp llama.cpp/build-android-$ABI_NAME/lib/libllama.so app/src/main/jniLibs/$ABI_NAME/
else
  echo "ERROR: libllama.so not found after build for $ABI_NAME"
  false
fi

echo "Successfully built and deployed libllama.so for $ABI_NAME"

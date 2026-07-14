#!/bin/bash
set -e
set -o pipefail

if [ -n "$ANDROID_NDK_HOME" ]; then
  ANDROID_NDK="$ANDROID_NDK_HOME"
else
  NDK_VERSION="25.2.9519653"
  ANDROID_NDK=$ANDROID_HOME/ndk/$NDK_VERSION
fi

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

echo "Building optimized llama.cpp shared library for $ABI_NAME using NDK at $ANDROID_NDK..."

if [ ! -d "llama.cpp" ]; then
  echo "ERROR: llama.cpp directory not found."
  exit 1
fi

mkdir -p build-native-$ABI_NAME
cd build-native-$ABI_NAME

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
      -DLLAMA_BUILD_TOOLS=OFF \
      -DLLAMA_BUILD_APP=OFF \
      -B . ../app/src/main/cpp 2>&1 | tee cmake_config_$ABI_NAME.log

if ! cmake --build . --config Release -j$(nproc) 2>&1 | tee cmake_build_$ABI_NAME.log; then
  if [ "$ABI" == "arm32" ]; then
    echo "WARNING: ARMv7 build failed. Continuing..."
    cd ..
    exit 0
  else
    echo "ERROR: Compilation failed for $ABI_NAME."
    exit 1
  fi
fi

cd ..
mkdir -p app/src/main/jniLibs/$ABI_NAME
find build-native-$ABI_NAME -name "*.so" -exec cp {} app/src/main/jniLibs/$ABI_NAME/ \;

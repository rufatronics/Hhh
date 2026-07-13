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

echo "Building llama.cpp for $ABI_NAME..."

cd llama.cpp
mkdir -p build-android-$ABI_NAME
cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=$ABI_NAME -DANDROID_PLATFORM=$PLATFORM \
      -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CFLAGS" \
      -DGGML_OPENMP=OFF -DGGML_LLAMAFILE=OFF -DBUILD_SHARED_LIBS=ON \
      -B build-android-$ABI_NAME
cmake --build build-android-$ABI_NAME --config Release -j$(nproc)

cd ..
mkdir -p app/src/main/jniLibs/$ABI_NAME
cp llama.cpp/build-android-$ABI_NAME/bin/libllama.so app/src/main/jniLibs/$ABI_NAME/

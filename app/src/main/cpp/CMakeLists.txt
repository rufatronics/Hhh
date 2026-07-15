cmake_minimum_required(VERSION 3.22.1)

project("tinol")

# Project root relative to this file
# This file is at app/src/main/cpp/CMakeLists.txt
# llama.cpp is at llama.cpp/ in the root
# From app/src/main/cpp, ../../../ is app/, ../../../../ is root
get_filename_component(LLAMA_CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../llama.cpp" ABSOLUTE)

if (NOT EXISTS "${LLAMA_CPP_ROOT}/CMakeLists.txt")
    # Try one more level up just in case of environment differences
    get_filename_component(LLAMA_CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../llama.cpp" ABSOLUTE)
endif()

if (NOT EXISTS "${LLAMA_CPP_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found. Resolved path: ${LLAMA_CPP_ROOT}")
endif()

# Disable llama.cpp features for Android JNI
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_APP OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)

# Fix ARMv7 build by disabling NEON if needed to avoid intrinsic conflicts
if (ANDROID_ABI STREQUAL "armeabi-v7a")
    set(GGML_NEON OFF CACHE BOOL "" FORCE)
endif()

add_subdirectory("${LLAMA_CPP_ROOT}" ${CMAKE_CURRENT_BINARY_DIR}/llama.cpp_build)

add_library(tinol SHARED bonsai-native.cpp)

target_include_directories(tinol PRIVATE
    "${LLAMA_CPP_ROOT}/include"
    "${LLAMA_CPP_ROOT}/common"
    "${LLAMA_CPP_ROOT}/ggml/include"
)

find_library(log-lib log)
target_link_libraries(tinol PRIVATE llama ${log-lib})

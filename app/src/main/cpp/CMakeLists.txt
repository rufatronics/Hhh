cmake_minimum_required(VERSION 3.22.1)

project("tinol")

# Set llama.cpp root path relative to project root
get_filename_component(LLAMA_CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../llama.cpp" ABSOLUTE)

# Re-check path assuming CI checkout location
if (NOT EXISTS "${LLAMA_CPP_ROOT}/CMakeLists.txt")
    get_filename_component(LLAMA_CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../llama.cpp" ABSOLUTE)
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
    message(STATUS "Disabling NEON for ARMv7 build to avoid intrinsic conflicts")
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

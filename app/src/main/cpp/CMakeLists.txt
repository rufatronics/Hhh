cmake_minimum_required(VERSION 3.22.1)

project("tinol")

# Set llama.cpp root path
set(LLAMA_CPP_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../llama.cpp)

if (NOT EXISTS ${LLAMA_CPP_ROOT}/CMakeLists.txt)
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_ROOT}. Please clone it first.")
endif()

# Disable llama.cpp features we don't need for Android JNI
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "llama: build examples" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "llama: build tests" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "llama: build server example" FORCE)
set(LLAMA_BUILD_BENCHMARKS OFF CACHE BOOL "llama: build benchmarks" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "llama: build tools" FORCE)
set(LLAMA_BUILD_APP OFF CACHE BOOL "llama: build the unified binary" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "ggml: use OpenMP" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "ggml: use llamafile" FORCE)

# Add llama.cpp as a sub-project
add_subdirectory(${LLAMA_CPP_ROOT} ${CMAKE_CURRENT_BINARY_DIR}/llama.cpp_build)

# Add our JNI library
add_library(tinol SHARED bonsai-native.cpp)

# Include directories for llama.cpp and ggml
target_include_directories(tinol PRIVATE
    ${LLAMA_CPP_ROOT}/include
    ${LLAMA_CPP_ROOT}/common
    ${LLAMA_CPP_ROOT}/ggml/include
)

find_library(log-lib log)

# Link against llama (the target exported by llama.cpp)
target_link_libraries(tinol PRIVATE llama ${log-lib})

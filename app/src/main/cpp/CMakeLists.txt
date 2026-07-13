cmake_minimum_required(VERSION 3.22.1)

project("tinol")

# Note: llama.cpp will be cloned by CI into a specific directory.
# For local builds, you would need to clone it manually.
# In a real production setup, we might use a git submodule or fetch_content.
# Given the spec, we expect llama.cpp to be at the root or a known path.

set(LLAMA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../llama.cpp)

add_library(tinol SHARED
        bonsai-native.cpp
)

# We link against libllama.so which is built by the CI or manually.
# In the Gradle build, we assume libllama.so is in jniLibs.
# However, for the build to succeed during development, we might need to handle headers.

include_directories(${LLAMA_DIR})
include_directories(${LLAMA_DIR}/common)

find_library(log-lib log)

target_link_libraries(tinol
        ${log-lib}
)

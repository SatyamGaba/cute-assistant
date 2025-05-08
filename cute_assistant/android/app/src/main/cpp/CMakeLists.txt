cmake_minimum_required(VERSION 3.10) # Or newer if your NDK/toolchain requires

project(ai_bridge)

# message(STATUS "FLUTTER_ROOT: ${FLUTTER_ROOT}")
set(FLUTTER_ROOT "C:\\Users\\sgaba\\flutter")
include_directories(${FLUTTER_ROOT}/bin/cache/dart-sdk/include)
# Add the C++ source file for the bridge
# add_library(ai_bridge SHARED ai_bridge.cpp)

# Find and link the Android log library (for __android_log_print)
# find_library(log-lib log)

# Link against your prebuilt shared libraries for STT, LLM, TTS
# These paths are illustrative. You might place .so files in jniLibs
# or specify paths to their build directories if linking them as external projects.
# Example:
# target_link_libraries(ai_bridge PUBLIC
#    ${CMAKE_SOURCE_DIR}/../../../path/to/libwhisper.so
#    ${CMAKE_SOURCE_DIR}/../../../path/to/libllama.so
#    ${CMAKE_SOURCE_DIR}/../../../path/to/libcustom_tts.so
#    ${log-lib}
# )
# A more common approach is to place them in android/app/src/main/jniLibs/<ABI>/
# and let Gradle handle packaging. In that case, you might not need to specify full paths here,
# but ensure the linker can find them by name (e.g., -lwhisper -lllama)
# This depends on how those libraries are built (e.g. if they have SONAME set).

# target_link_libraries(ai_bridge PUBLIC whisper llama tts ${log-lib})

# You might need to include directories for headers of whisper, llama, tts
# target_include_directories(ai_bridge PUBLIC
#    ${CMAKE_SOURCE_DIR}/../../../path/to/whisper_headers
#    ${CMAKE_SOURCE_DIR}/../../../path/to/llama_headers
#    ${CMAKE_SOURCE_DIR}/../../../path/to/tts_headers
# )
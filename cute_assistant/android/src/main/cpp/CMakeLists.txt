cmake_minimum_required(VERSION 3.10)

project(ai_bridge)

# Try to find Dart SDK include directory (user may need to set this manually if not found)
# Option 1: User sets DART_SDK_ROOT
if(DEFINED ENV{DART_SDK_ROOT})
    set(DART_SDK_INCLUDE_DIR "$ENV{DART_SDK_ROOT}/include")
    message(STATUS "Using DART_SDK_ROOT from environment: $ENV{DART_SDK_ROOT}")
elseif(DEFINED DART_SDK_ROOT_FROM_FLUTTER) # Passed from Flutter build environment (experimental)
    set(DART_SDK_INCLUDE_DIR "${DART_SDK_ROOT_FROM_FLUTTER}/include")
    message(STATUS "Using DART_SDK_ROOT_FROM_FLUTTER: ${DART_SDK_ROOT_FROM_FLUTTER}")
else()
    # Fallback - User must ensure this path is correct or set DART_SDK_ROOT env variable
    # Example path, ADJUST THIS IF NEEDED:
    set(DART_SDK_INCLUDE_DIR "C:\\Users\\satya\\flutter\\bin\\cache\\dart-sdk\\include")
    message(WARNING "DART_SDK_ROOT environment variable not set. Using fallback include path: ${DART_SDK_INCLUDE_DIR}. This may need adjustment.")
endif()

if(NOT EXISTS "${DART_SDK_INCLUDE_DIR}/dart_api_dl.h")
    message(FATAL_ERROR "dart_api_dl.h not found in ${DART_SDK_INCLUDE_DIR}. Please set DART_SDK_ROOT environment variable correctly or check DART_SDK_INCLUDE_DIR in CMakeLists.txt.")
else()
    message(STATUS "Found dart_api_dl.h at: ${DART_SDK_INCLUDE_DIR}")
endif()

include_directories(
    ${DART_SDK_INCLUDE_DIR}
    # Add other include directories for your AI engines if needed
    # e.g., include_directories(path/to/whisper_cpp/include)
)

# Add your ai_bridge.cpp source file
add_library(ai_bridge SHARED ai_bridge.cpp)

# Set C++ standard (C++17 is good for modern features like std::atomic, std::thread)
set_property(TARGET ai_bridge PROPERTY CXX_STANDARD 17)
set_property(TARGET ai_bridge PROPERTY CXX_STANDARD_REQUIRED ON)

# --- Linking against precompiled AI engine libraries ---
# This assumes your .so files are in android/src/main/jniLibs/<ABI>/
# and that your Gradle setup makes them available for linking.
# The names (whisper, llama, tts) should match the library names without "lib" prefix and ".so" suffix.

# Example: find_library(WHISPER_LIB whisper PATHS ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})
# find_library(LLAMA_LIB llama PATHS ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})
# find_library(TTS_LIB tts PATHS ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})

# if(NOT WHISPER_LIB)
#     message(WARNING "libwhisper.so not found. Ensure it is in jniLibs for the target ABI.")
# endif()
# Similar checks for LLAMA_LIB and TTS_LIB

# Link your ai_bridge to these libraries and Android NDK libraries
target_link_libraries(ai_bridge
    PUBLIC
    # Link against your AI engines. 
    # If you use find_library, use ${WHISPER_LIB}, ${LLAMA_LIB}, ${TTS_LIB}
    # If they are directly in jniLibs and picked up by Gradle, you might just list their names:
    # whisper llama tts 
    # For now, we'll comment these out as they depend on your setup.
    # Ensure these are correctly linked based on how you include them in your Android project.

    android     # For Android-specific APIs if needed
    log         # For __android_log_print
    # Add other NDK libraries as needed, e.g., OpenSLES for audio
)

# Optional: If your Dart SDK's libdart.so is needed for FFI (usually not for dart_api_dl.h usage with Native Ports)
# You might need to link against libdart.so from the Dart SDK if you were using more extensive Dart C APIs.
# For Native Ports and Dart_PostCObject_DL, dart_api_dl.h and the VM's internal handling are usually sufficient.

message(STATUS "CMake: Configured ai_bridge library for ABI: ${ANDROID_ABI}") 
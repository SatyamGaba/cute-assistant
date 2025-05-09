# cmake_minimum_required(VERSION 3.10) # Or your NDK/toolchain version

# project(ai_bridge)

# # It's better to let Flutter's build process pass the Dart SDK include path.
# # Avoid hardcoding paths like C:\Users\sgaba\flutter.
# # If needed for local non-Flutter builds, use environment variables.
# # include_directories(${DART_SDK_INCLUDE_DIR}) # Example if DART_SDK_INCLUDE_DIR is set

# add_library(ai_bridge SHARED ai_bridge.cpp)

# find_library(log-lib log)

# # Only link LLM related libraries now.
# # Ensure your Llama.cpp (with QNN) is built as a shared library (e.g., libllama.so)
# # and placed in jniLibs or linked correctly.
# target_link_libraries(ai_bridge PUBLIC llama ${log-lib}) # Example: linking libllama.so

# # If Llama.cpp needs specific headers:
# # target_include_directories(ai_bridge PUBLIC path/to/llama_cpp/headers)
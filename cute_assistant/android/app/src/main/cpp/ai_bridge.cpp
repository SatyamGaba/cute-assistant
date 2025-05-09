// #include <jni.h>
// #include <string>
// #include <vector>
// #include <thread>
// #include <mutex>
// #include <atomic>
// // Remove deque if TTS ring buffer is no longer needed here

// #include "dart_api_dl.h"
// #include <android/log.h>
// #define APPNAME "AIBridgeCPP_LLM"

// // --- Global State for LLM ---
// std::atomic<bool> g_is_llm_processing_active(false); // To control the LLM loop if needed
// std::thread g_llm_thread;
// // Mutex and CV for LLM input queue if you implement one
// std::mutex g_llm_input_mutex;
// std::condition_variable g_llm_input_cv;
// std::string g_llm_input_text;


// Dart_Port g_llm_token_port = ILLEGAL_PORT;
// Dart_Port g_llm_error_port = ILLEGAL_PORT;


// void SendStringToDart(Dart_Port port_id, const std::string& message) {
//     if (port_id == ILLEGAL_PORT) return;
//     Dart_CObject dart_object;
//     dart_object.type = Dart_CObject_kString;
//     char* cstr = new char[message.length() + 1];
//     strcpy(cstr, message.c_str());
//     dart_object.value.as_string = cstr;

//     const bool result = Dart_PostCObject_DL(port_id, &dart_object);
//     if (!result) {
//         __android_log_print(ANDROID_LOG_ERROR, APPNAME, "Dart_PostCObject_DL failed for string to port %lld", port_id);
//     }
//     delete[] cstr; // Free the copied string
// }

// // --- LLM Thread Function (Placeholder - Integrate your Llama.cpp here) ---
// void llm_processing_loop() {
//     // Initialize Llama.cpp (with QNN delegate on NPU) ONCE when thread starts
//     // llama_context * ctx = llama_init_from_file(...);
//     // if (!ctx) { SendStringToDart(g_llm_error_port, "Failed to load LLM model"); return; }

//     __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM processing thread started.");

//     while (g_is_llm_processing_active) {
//         std::string current_input;
//         {
//             std::unique_lock<std::mutex> lock(g_llm_input_mutex);
//             g_llm_input_cv.wait(lock, [] { return !g_llm_input_text.empty() || !g_is_llm_processing_active; });

//             if (!g_is_llm_processing_active && g_llm_input_text.empty()) {
//                 break; // Exit if shutting down and no pending input
//             }
//             current_input = std::move(g_llm_input_text);
//             g_llm_input_text.clear(); // Clear after moving
//         }

//         if (current_input.empty()) continue;

//         __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM received input: %s", current_input.c_str());

//         // --- LLAMA.CPP INFERENCE ---
//         // 1. Tokenize input: std::vector<llama_token> tokens_list = llama_tokenize(ctx, current_input.c_str(), true);
//         // 2. Configure batch, eval: llama_batch batch = llama_batch_get_one(tokens_list.data(), tokens_list.size(), 0, 0);
//         //                          if (llama_decode(ctx, batch) != 0) { /* error */ }
//         // 3. Sampling loop to generate output tokens:
//         //    while (current_token != llama_token_eos(ctx) && g_is_llm_processing_active) {
//         //        auto logits = llama_get_logits_ith(ctx, batch.n_tokens - 1);
//         //        // ... (apply samplers: temp, top_k, top_p etc.) ...
//         //        current_token = llama_sample_token(ctx, nullptr /* candidates */);
//         //        if (current_token == llama_token_eos(ctx)) break;
//         //        std::string token_text = llama_token_to_piece(ctx, current_token);
//         //        SendStringToDart(g_llm_token_port, token_text);
//         //        llama_batch_clear(&batch);
//         //        llama_batch_add(&batch, current_token, batch.n_tokens, { 0 }, true);
//         //        if (llama_decode(ctx, batch) != 0) { /* error */ break; }
//         //    }
//         // --- END LLAMA.CPP ---
        
//         // Placeholder simulation:
//         SendStringToDart(g_llm_token_port, "LLM got: " + current_input + ". ");
//         std::this_thread::sleep_for(std::chrono::milliseconds(500));
//         SendStringToDart(g_llm_token_port, "Thinking... ");
//         std::this_thread::sleep_for(std::chrono::milliseconds(500));
//         SendStringToDart(g_llm_token_port, "Response part 1. ");
//          std::this_thread::sleep_for(std::chrono::milliseconds(300));
//         SendStringToDart(g_llm_token_port, "Response part 2.\n");


//         // Ensure a small yield to prevent busy-looping if input comes fast
//         std::this_thread::sleep_for(std::chrono::milliseconds(10));
//     }

//     // llama_free(ctx); // Cleanup Llama.cpp context
//     __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM processing thread finished.");
// }


// extern "C" {
//     DART_EXPORT void native_initialize_dart_api(void* data) {
//         if (Dart_InitializeApiDL(data) != 0) {
//             __android_log_print(ANDROID_LOG_ERROR, APPNAME, "Failed to initialize Dart API DL for LLM");
//         } else {
//              __android_log_print(ANDROID_LOG_INFO, APPNAME, "Dart API DL Initialized successfully for LLM.");
//         }
//     }

//     DART_EXPORT void native_initialize_llm_ports(Dart_Port llm_token_port, Dart_Port llm_error_port_id) {
//         g_llm_token_port = llm_token_port;
//         g_llm_error_port = llm_error_port_id;
//         __android_log_print(ANDROID_LOG_INFO, APPNAME, "Native LLM ports initialized.");

//         // Start the LLM processing thread ONCE here
//         if (!g_llm_thread.joinable()) {
//              g_is_llm_processing_active = true;
//              g_llm_thread = std::thread(llm_processing_loop);
//         }
//     }

//     DART_EXPORT void native_process_llm_input(const char* text_input) {
//         if (text_input == nullptr) {
//             SendStringToDart(g_llm_error_port, "Received null input for LLM.");
//             return;
//         }
//         std::string input_str(text_input);
//         {
//             std::lock_guard<std::mutex> lock(g_llm_input_mutex);
//             g_llm_input_text = input_str; // Set new input
//         }
//         g_llm_input_cv.notify_one(); // Notify the LLM thread
//         __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM input queued via FFI: %s", input_str.c_str());
//     }

//     DART_EXPORT void native_dispose_llm() {
//         __android_log_print(ANDROID_LOG_INFO, APPNAME, "Disposing LLM native resources...");
//         g_is_llm_processing_active = false;
//         {
//             std::lock_guard<std::mutex> lock(g_llm_input_mutex);
//             g_llm_input_text.clear(); // Clear any pending input
//         }
//         g_llm_input_cv.notify_all(); // Wake up thread to exit

//         if (g_llm_thread.joinable()) {
//             g_llm_thread.join();
//         }
//         g_llm_token_port = ILLEGAL_PORT;
//         g_llm_error_port = ILLEGAL_PORT;
//         __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM native resources disposed.");
//     }
// }
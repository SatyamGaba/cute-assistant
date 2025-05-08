#include <jni.h>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <deque> // For a simple ring buffer implementation

// Crucial: Dart C DL API for interacting with Dart from C
#include "dart_api_dl.h"

// For logging
#include <android/log.h>
#define APPNAME "AIBridgeCPP"

// --- Global State (Illustrative) ---
std::atomic<bool> g_is_processing(false);
std::thread g_stt_thread;
std::thread g_llm_thread;
std::thread g_tts_thread;

// Dart SendPort IDs for callbacks
Dart_Port g_transcript_port = ILLEGAL_PORT;
Dart_Port g_llm_token_port = ILLEGAL_PORT;
Dart_Port g_speaking_state_port = ILLEGAL_PORT;

// --- TTS Ring Buffer Concept ---
template<typename T>
class RingBuffer {
public:
    explicit RingBuffer(size_t capacity) : capacity_(capacity) {}

    bool push(T item) {
        std::unique_lock<std::mutex> lock(mutex_);
        if (buffer_.size() >= capacity_) {
            // Buffer full, optional: wait or drop oldest
            // For simplicity, let's make it a blocking push or drop oldest
            // For TTS, we might want to drop if it gets too full to prevent latency
            // Or, LLM should pause if TTS buffer is too full (backpressure)
            buffer_.pop_front(); // Drop oldest if full
        }
        buffer_.push_back(std::move(item));
        lock.unlock();
        cv_.notify_one();
        return true;
    }

    T pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return !buffer_.empty() || !g_is_processing; });
        if (buffer_.empty()) {
            return T(); // Return empty/default if not processing and buffer empty
        }
        T item = std::move(buffer_.front());
        buffer_.pop_front();
        return item;
    }

    bool is_empty() {
        std::lock_guard<std::mutex> lock(mutex_);
        return buffer_.empty();
    }

    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        buffer_.clear();
    }

private:
    std::deque<T> buffer_;
    size_t capacity_;
    std::mutex mutex_;
    std::condition_variable cv_;
};

RingBuffer<std::string> g_tts_text_buffer(20); // Buffer up to 20 text segments/tokens for TTS

// --- Helper to send string to Dart ---
void SendStringToDart(Dart_Port port_id, const std::string& message) {
    if (port_id == ILLEGAL_PORT) return;

    Dart_CObject dart_object;
    dart_object.type = Dart_CObject_kString;
    // Dart_PostCObject expects char*, not const char*. So, we might need a copy.
    // However, for literals or short-lived strings, it might be okay if Dart copies it immediately.
    // Safest: char* str = strdup(message.c_str()); dart_object.value.as_string = str; Dart_PostCObject_DL(port_id, &dart_object); free(str);
    // For now, assuming Dart handles it:
    dart_object.value.as_string = const_cast<char*>(message.c_str());

    const bool result = Dart_PostCObject_DL(port_id, &dart_object);
    if (!result) {
        __android_log_print(ANDROID_LOG_ERROR, APPNAME, "Dart_PostCObject_DL failed for string");
    }
}

void SendBoolToDart(Dart_Port port_id, bool value) {
    if (port_id == ILLEGAL_PORT) return;
    Dart_CObject dart_object;
    dart_object.type = Dart_CObject_kBool;
    dart_object.value.as_bool = value;
    Dart_PostCObject_DL(port_id, &dart_object);
}


// --- STT Thread Function (Placeholder) ---
void stt_thread_func() {
    __android_log_print(ANDROID_LOG_INFO, APPNAME, "STT thread started");
    // Initialize Whisper.cpp / VAD here

    while(g_is_processing) {
        // Simulate STT work
        std::this_thread::sleep_for(std::chrono::seconds(2));
        if (!g_is_processing) break;

        // Get final transcript
        std::string transcript = "User said: Hello world at " + std::to_string(time(nullptr));
        
        // Send transcript to UI immediately
        SendStringToDart(g_transcript_port, transcript);
        
        // Log and pass to LLM
        __android_log_print(ANDROID_LOG_INFO, APPNAME, "Final transcript going to LLM: %s", transcript.c_str());
        
        // Here you would pass to LLM's input queue
        // For now simulated - in real implementation you'd:
        // 1. Pass to LLM input buffer
        // 2. Signal LLM thread that new input is available
    }
    
    __android_log_print(ANDROID_LOG_INFO, APPNAME, "STT thread finished");
}

// --- LLM Thread Function (Placeholder) ---
void llm_thread_func() {
    __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM thread started");
    // Initialize Llama.cpp (with QNN delegate on NPU)
    // Loop while g_is_processing
    //  - Wait for input text from STT (e.g., from a queue)
    //  - Process text with Llama.cpp, generating tokens in a streaming fashion
    //  - For each token/chunk:
    //      - SendStringToDart(g_llm_token_port, token_str);
    //      - g_tts_text_buffer.push(token_str); // Push to TTS ring buffer
    while(g_is_processing) {
        // Simulate LLM work based on STT input (which is missing here for true pipeline)
        std::this_thread::sleep_for(std::chrono::seconds(3));
        if (!g_is_processing) break;

        std::string llm_response_token = "AI token part 1 ";
        SendStringToDart(g_llm_token_port, llm_response_token);
        g_tts_text_buffer.push(llm_response_token);

        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        if (!g_is_processing) break;

        llm_response_token = "and part 2. ";
        SendStringToDart(g_llm_token_port, llm_response_token);
        g_tts_text_buffer.push(llm_response_token);
         __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM produced tokens");
    }
    // Cleanup Llama.cpp
    __android_log_print(ANDROID_LOG_INFO, APPNAME, "LLM thread finished");
}

// --- TTS Thread Function (Placeholder) ---
void tts_thread_func() {
    __android_log_print(ANDROID_LOG_INFO, APPNAME, "TTS thread started");
    // Initialize TTS Engine (e.g., FastSpeech2 on GPU)
    // Loop while g_is_processing or g_tts_text_buffer is not empty
    //  - std::string text_to_speak = g_tts_text_buffer.pop();
    //  - If text_to_speak is not empty:
    //      - SendBoolToDart(g_speaking_state_port, true);
    //      - Synthesize audio using TTS engine
    //      - Play audio (e.g., using Android's AudioTrack via JNI or OpenSL ES)
    //      - SendBoolToDart(g_speaking_state_port, false); // After audio chunk finishes
    //  - If g_tts_text_buffer is empty and not g_is_processing, break.
    while(g_is_processing || !g_tts_text_buffer.is_empty()) {
        std::string text_chunk = g_tts_text_buffer.pop();
        if (!text_chunk.empty()) {
            SendBoolToDart(g_speaking_state_port, true);
            __android_log_print(ANDROID_LOG_INFO, APPNAME, "TTS consuming: %s", text_chunk.c_str());
            // Simulate TTS synthesis and playback
            std::this_thread::sleep_for(std::chrono::milliseconds(text_chunk.length() * 50)); // Rough estimate
            SendBoolToDart(g_speaking_state_port, false);
        } else if (!g_is_processing) {
            break; // Exit if no more processing and buffer is drained
        }
    }
    // Cleanup TTS Engine
    __android_log_print(ANDROID_LOG_INFO, APPNAME, "TTS thread finished");
    SendBoolToDart(g_speaking_state_port, false); // Ensure final state is not speaking
}


// --- FFI Exported Functions ---
extern "C" {
    DART_EXPORT void native_initialize_dart_api(void* data) {
        if (Dart_InitializeApiDL(data) != 0) {
            __android_log_print(ANDROID_LOG_ERROR, APPNAME, "Failed to initialize Dart API DL");
        } else {
             __android_log_print(ANDROID_LOG_INFO, APPNAME, "Dart API DL Initialized successfully.");
        }
    }

    DART_EXPORT void native_initialize_ports(Dart_Port transcript_port, Dart_Port llm_token_port, Dart_Port speaking_state_port) {
        g_transcript_port = transcript_port;
        g_llm_token_port = llm_token_port;
        g_speaking_state_port = speaking_state_port;
        __android_log_print(ANDROID_LOG_INFO, APPNAME, "Native ports initialized.");
    }

    DART_EXPORT void native_start_processing() {
        if (g_is_processing) return;
        g_is_processing = true;
        __android_log_print(ANDROID_LOG_INFO, APPNAME, "Starting processing threads...");

        // Clear any stale data in TTS buffer from previous runs
        g_tts_text_buffer.clear();

        // Start your STT, LLM, TTS threads
        // TODO: Proper error handling for thread creation
        g_stt_thread = std::thread(stt_thread_func);
        g_llm_thread = std::thread(llm_thread_func);
        g_tts_thread = std::thread(tts_thread_func);
        __android_log_print(ANDROID_LOG_INFO, APPNAME, "Processing threads launched.");
    }

    DART_EXPORT void native_stop_processing() {
        if (!g_is_processing) return;
        g_is_processing = false;
        __android_log_print(ANDROID_LOG_INFO, APPNAME, "Stopping processing threads...");

        // Notify condition variables in any blocking queues/buffers
        // (The RingBuffer's pop() checks g_is_processing)
        // g_stt_input_cv.notify_all();
        // g_llm_input_cv.notify_all();
        g_tts_text_buffer.push(""); // Push an empty signal to potentially wake TTS

        if (g_stt_thread.joinable()) g_stt_thread.join();
        if (g_llm_thread.joinable()) g_llm_thread.join();
        if (g_tts_thread.joinable()) g_tts_thread.join();

        __android_log_print(ANDROID_LOG_INFO, APPNAME, "Processing threads stopped and joined.");
        SendBoolToDart(g_speaking_state_port, false); // Ensure UI knows AI is not speaking
    }

    DART_EXPORT void native_dispose() {
        native_stop_processing(); // Ensure everything is stopped
        g_transcript_port = ILLEGAL_PORT;
        g_llm_token_port = ILLEGAL_PORT;
        g_speaking_state_port = ILLEGAL_PORT;
        __android_log_print(ANDROID_LOG_INFO, APPNAME, "Native resources disposed.");
        // Any other global cleanup
    }
} // extern "C"
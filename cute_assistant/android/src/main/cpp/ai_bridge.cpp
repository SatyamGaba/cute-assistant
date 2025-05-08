#include <thread>
#include <atomic>
#include <vector>
#include <string>
#include <cstring> // For strlen, strcpy_s (if on Windows) or strncpy
#include <iostream> // For debugging, remove in production

// It's crucial to include the Dart C API header for Native Ports.
// This path might vary based on your Dart SDK setup for C FFI.
// Typically, it's part of the Dart SDK in include/dart_api_dl.h
// Ensure your build system (CMake) can find this header.
#include "dart_api_dl.h" 

// --- Ring Buffer Template (from previous plan) ---
#include <queue>
#include <mutex>
#include <condition_variable>

template<typename T>
class SafeQueue {
public:
    SafeQueue(size_t capacity) : capacity_(capacity) {}

    // Push an item. Blocks if the queue is full.
    void push(T item) {
        std::unique_lock<std::mutex> lock(mutex_);
        cond_not_full_.wait(lock, [&] { return buffer_.size() < capacity_ || !running_; });
        if (!running_) return;
        buffer_.push(std::move(item));
        lock.unlock();
        cond_not_empty_.notify_one();
    }

    // Pop an item. Blocks if the queue is empty.
    // Returns true if an item was popped, false if shutting down.
    bool pop(T& item) {
        std::unique_lock<std::mutex> lock(mutex_);
        cond_not_empty_.wait(lock, [&] { return !buffer_.empty() || !running_; });
        if (!running_ && buffer_.empty()) return false;
        item = std::move(buffer_.front());
        buffer_.pop();
        lock.unlock();
        cond_not_full_.notify_one();
        return true;
    }

    void shutdown() {
        std::unique_lock<std::mutex> lock(mutex_);
        running_ = false;
        lock.unlock();
        cond_not_empty_.notify_all();
        cond_not_full_.notify_all();
    }
    
    void start() {
        std::unique_lock<std::mutex> lock(mutex_);
        running_ = true;
        lock.unlock();
    }

    size_t size() {
        std::lock_guard<std::mutex> lock(mutex_);
        return buffer_.size();
    }

    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        std::queue<T> empty;
        std::swap(buffer_, empty);
    }

private:
    std::queue<T> buffer_;
    size_t capacity_;
    std::mutex mutex_;
    std::condition_variable cond_not_empty_;
    std::condition_variable cond_not_full_;
    std::atomic<bool> running_{true};
};

// --- Global State ---
std::atomic<bool> pipeline_running{false};
Dart_Port_DL transcript_dart_port = 0;
Dart_Port_DL llm_token_dart_port = 0;

// --- Buffers / Queues ---
// Using SafeQueue which is a more robust ring buffer for inter-thread communication
SafeQueue<std::string> stt_to_llm_queue(10);    // STT output to LLM input
SafeQueue<std::string> llm_to_tts_queue(100);   // LLM tokens to TTS input

// --- Pipeline Threads ---
std::thread vad_stt_thread; // Combined VAD & STT for this example
std::thread llm_thread;
std::thread tts_thread;

// --- Helper: Post string to Dart port safely ---
void post_string_to_dart(Dart_Port_DL port, const std::string& str) {
    if (port == 0) return; // Port not initialized

    Dart_CObject dart_object;
    dart_object.type = Dart_CObject_kString;
    // Dart_PostCObject_DL expects a char*, not const char* for as_string
    // Need to copy string to a temporary buffer if it might be modified,
    // or ensure it's null-terminated and from stable memory.
    // For strings from std::string::c_str(), they are null-terminated.
    // The critical part is that the memory must remain valid until Dart processes it.
    // If Dart copies it immediately, c_str() is fine. If Dart uses the pointer later,
    // we need to ensure lifetime. For SendPort, Dart usually copies.
    char* cstr = new char[str.length() + 1];
    #if defined(_MSC_VER)
    strcpy_s(cstr, str.length() + 1, str.c_str());
    #else
    strncpy(cstr, str.c_str(), str.length());
    cstr[str.length()] = '\0'; // Ensure null termination for strncpy
    #endif
    
    dart_object.value.as_string = cstr;

    bool posted = Dart_PostCObject_DL(port, &dart_object);
    if (!posted) {
        std::cerr << "Failed to post message to Dart port: " << port << std::endl;
        // Handle error, e.g., by not deleting cstr if Dart might still pick it up,
        // though if !posted it usually means the port is invalid/closed.
    }
    delete[] cstr; // Dart copies the string, so we can delete our copy.
}

// --- Simulated Pipeline Functions (replace with real model calls) ---
void vad_stt_pipeline_func() {
    std::cout << "VAD/STT thread started." << std::endl;
    int counter = 0;
    while (pipeline_running) {
        std::this_thread::sleep_for(std::chrono::seconds(2)); // Simulate audio input and STT processing time
        if (!pipeline_running) break;

        std::string user_transcript = "User said: hello number " + std::to_string(++counter);
        std::cout << "[STT] Detected: " << user_transcript << std::endl;

        // Send transcript to Dart UI
        if (transcript_dart_port != 0) {
            post_string_to_dart(transcript_dart_port, user_transcript);
        }
        // Send transcript to LLM queue
        stt_to_llm_queue.push(user_transcript);
    }
    std::cout << "VAD/STT thread finished." << std::endl;
}

void llm_pipeline_func() {
    std::cout << "LLM thread started." << std::endl;
    while (pipeline_running) {
        std::string transcript;
        if (!stt_to_llm_queue.pop(transcript)) { // Pop blocks until item or shutdown
            if (!pipeline_running) break; // Check running again after wakeup
            continue;
        }
        if (!pipeline_running) break;

        std::cout << "[LLM] Processing: " << transcript << std::endl;
        // Simulate LLM processing - generate tokens
        std::vector<std::string> tokens = {"Assistant: ", "Okay, ", "I ", "can ", "help ", "with ", "that! "};
        for (const auto& token : tokens) {
            if (!pipeline_running) break;
            std::cout << "[LLM] Token: " << token << std::endl;
            if (llm_token_dart_port != 0) {
                post_string_to_dart(llm_token_dart_port, token);
            }
            llm_to_tts_queue.push(token); // Send token to TTS
            std::this_thread::sleep_for(std::chrono::milliseconds(100)); // Simulate token generation interval
        }
    }
    std::cout << "LLM thread finished." << std::endl;
}

void tts_pipeline_func() {
    std::cout << "TTS thread started." << std::endl;
    while (pipeline_running) {
        std::string token_chunk;
        if (!llm_to_tts_queue.pop(token_chunk)) { // Pop blocks until item or shutdown
            if (!pipeline_running) break;
            continue;
        }
        if (!pipeline_running) break;

        // Simulate TTS processing (e.g., playing audio of the token_chunk)
        std::cout << "[TTS] Speaking: " << token_chunk << std::endl;
        std::this_thread::sleep_for(std::chrono::milliseconds(150)); // Simulate TTS audio playback time for the chunk
    }
    std::cout << "TTS thread finished." << std::endl;
}

// --- FFI Entrypoints ---
extern "C" __attribute__((visibility("default"))) __attribute__((used))
void native_start(Dart_Port_DL transcript_port_id, Dart_Port_DL llm_token_port_id) {
    if (pipeline_running) {
        std::cout << "Native pipeline already running." << std::endl;
        return;
    }
    std::cout << "Native_start called." << std::endl;

    // It is crucial that Dart_InitializeApiDL is called before using Dart_PostCObject_DL.
    // This should be done once per process. dart_api_dl.h provides Dart_InitializeApiDL.
    // The `dart_init_dl_data` is typically passed from Dart using `NativeApi.initializeApiDLData`.
    // However, for SendPort.nativePort, this is often handled implicitly by the Dart VM when the port is used.
    // If issues arise, explicitly initialize: if (Dart_InitializeApiDL(dart_init_dl_data) != 0) { /* handle error */ }
    // For this example, we rely on the Dart VM's handling for NativePorts.

    pipeline_running = true;
    transcript_dart_port = transcript_port_id;
    llm_token_dart_port = llm_token_port_id;
    
    stt_to_llm_queue.start();
    llm_to_tts_queue.start();
    stt_to_llm_queue.clear(); // Clear any stale data
    llm_to_tts_queue.clear();

    vad_stt_thread = std::thread(vad_stt_pipeline_func);
    llm_thread = std::thread(llm_pipeline_func);
    tts_thread = std::thread(tts_pipeline_func);
    std::cout << "Native pipeline started with threads." << std::endl;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void native_stop() {
    if (!pipeline_running) {
        std::cout << "Native pipeline already stopped." << std::endl;
        return;
    }
    std::cout << "Native_stop called." << std::endl;
    pipeline_running = false; // Signal threads to stop

    // Shutdown queues to unblock any waiting threads
    stt_to_llm_queue.shutdown();
    llm_to_tts_queue.shutdown();

    if (vad_stt_thread.joinable()) vad_stt_thread.join();
    if (llm_thread.joinable()) llm_thread.join();
    if (tts_thread.joinable()) tts_thread.join();
    
    transcript_dart_port = 0; // Reset ports
    llm_token_dart_port = 0;

    std::cout << "Native pipeline threads joined and stopped." << std::endl;
} 
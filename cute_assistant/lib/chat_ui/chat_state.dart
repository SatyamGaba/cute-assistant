import 'package:flutter/foundation.dart';
import '../services/on_device_ai_service.dart';
import 'package:permission_handler/permission_handler.dart';

class Message {
  String text;
  final bool isUser;
  final DateTime timestamp;

  Message(this.text, this.isUser, {DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class ChatState extends ChangeNotifier {
  final OnDeviceAIService _aiService;
  final List<Message> _messages = [];
  // bool _isRecording = false; // Now managed by _aiService.isOverallListeningStream
  bool _isOverallListening = false;
  bool _isAISpeaking = false;

  ChatState(this._aiService) {
    _initialize();
  }

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isRecording => _isOverallListening; // Reflects VAD/STT activity
  bool get isAISpeaking => _isAISpeaking;

  Future<void> _initialize() async {
    // Listen to overall listening state (VAD/STT active)
    _aiService.isOverallListeningStream.listen((listening) {
      _isOverallListening = listening;
      if (!listening && _messages.isNotEmpty && _messages.last.isUser && _messages.last.text.endsWith("...")) {
        // Clean up if STT stopped before finalizing, and we were showing "..."
         if (_messages.last.text == "...") _messages.removeLast();
      }
      notifyListeners();
    });

    // Listen to transcription updates from the AI service
    _aiService.transcriptStream.listen((transcriptChunk) {
      if (_isOverallListening) { // Only update user message if actively listening
        if (_messages.isEmpty || !_messages.last.isUser || _messages.last.text.isEmpty) {
          // Add new user message or if previous AI message was last
          _addMessage(Message(transcriptChunk, true));
        } else {
          // Update the last user message with the new transcript
          _messages.last.text = transcriptChunk;
        }
      } else {
        // This might be a final transcript after listening stopped, add as new if not empty
        if (transcriptChunk.isNotEmpty && (_messages.isEmpty || !_messages.last.isUser || _messages.last.text != transcriptChunk)) {
            // Check if this exact message already exists to avoid duplicates from final STT result
            _addMessage(Message(transcriptChunk, true));
        }
      }
      notifyListeners();
    }, onError: (error) {
      _addMessage(Message("Input Error: $error", false));
      _isOverallListening = false;
      notifyListeners();
    });

    _aiService.llmResponseStream.listen((token) {
      if (_messages.isEmpty || _messages.last.isUser) {
        _addMessage(Message(token, false));
      } else {
        _messages.last.text += token;
      }
      notifyListeners();
    }, onError: (error) {
      _addMessage(Message("AI Error: $error", false));
      notifyListeners();
    });

    _aiService.isSpeakingStream.listen((speaking) {
      _isAISpeaking = speaking;
      notifyListeners();
    });
  }

  void _addMessage(Message message) {
    // Prevent adding exact duplicate consecutive messages quickly
    if (_messages.isNotEmpty && _messages.last.text == message.text && _messages.last.isUser == message.isUser) {
      // If it's an update to the last user message, allow it
      if (message.isUser && _isOverallListening) {
         _messages.last.text = message.text; // This case is handled above
      } else {
        return;
      }
    } else {
       _messages.add(message);
    }
   
    if (_messages.length > 50) {
      _messages.removeAt(0);
    }
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    if (_isOverallListening) {
      await _aiService.stopListening();
    } else {
      var micStatus = await Permission.microphone.request();
      if (micStatus.isGranted) {
         // Add a placeholder to indicate listening started
        if (_messages.isEmpty || !_messages.last.isUser) {
            _addMessage(Message("...", true));
        } else if (_messages.last.isUser && _messages.last.text.isNotEmpty) {
            _addMessage(Message("...", true));
        } else {
            _messages.last.text = "..."; // Update existing empty user message
        }
        notifyListeners();
        await _aiService.startListening();
      } else {
        _addMessage(Message("Microphone permission denied.", false));
      }
    }
    // State (_isOverallListening) will be updated by the stream from service
  }

  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    _addMessage(Message(text, true));
    await _aiService.sendText(text); // This now sends to LLM via FFI
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}
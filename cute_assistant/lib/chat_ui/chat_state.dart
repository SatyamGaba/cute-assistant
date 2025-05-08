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
  bool _isRecording = false;
  bool _isAISpeaking = false; // To track if TTS is active
  String _currentTranscript = ""; // To buffer user's speech before sending

  ChatState(this._aiService) {
    _initialize();
  }

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isRecording => _isRecording;
  bool get isAISpeaking => _isAISpeaking; // Expose this if UI needs it

  Future<void> _initialize() async {
    // Listen to transcription updates from the AI service
    _aiService.transcriptStream.listen((transcriptChunk) {
      _currentTranscript = transcriptChunk;
      if (_isRecording) {
        // If this is the first chunk for this recording session, add a new message
        if (_messages.isEmpty || _messages.last.isUser == false) {
          _addMessage(Message(_currentTranscript, true));
        } else {
          // Update the last user message with the new transcript
          _messages.last.text = _currentTranscript;
        }
      }
      notifyListeners();
    }, onError: (error) {
      _addMessage(Message("Error in transcription: $error", false));
      _stopRecordingInternal();
    });

    // Listen to LLM token stream for AI responses
    _aiService.llmResponseStream.listen((token) {
      if (_messages.isEmpty || _messages.last.isUser) {
        _addMessage(Message(token, false)); // Start new AI message
      } else {
        _messages.last.text += token; // Append to existing AI message
      }
      notifyListeners();
    }, onError: (error) {
      _addMessage(Message("Error from LLM: $error", false));
      _stopRecordingInternal(); // Or handle differently
    });

    // Listen to AI speaking state (TTS active or not)
    _aiService.isSpeakingStream.listen((speaking) {
      _isAISpeaking = speaking;
      notifyListeners();
    });
  }

  void _addMessage(Message message) {
    _messages.add(message);
    if (_messages.length > 50) { // Keep history manageable
      _messages.removeAt(0);
    }
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      _aiService.stopProcessing();
      if (_currentTranscript.isNotEmpty) {
        _addMessage(Message(_currentTranscript, true));
        _currentTranscript = ""; // Clear buffer
      }
      _isRecording = false;
    } else {
      // Start recording
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _aiService.startProcessing();
        _isRecording = true;
      } else {
        _addMessage(Message("Microphone permission denied.", false));
      }
    }
    notifyListeners();
  }

  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    _addMessage(Message(text, true));
    await _aiService.processTextInput(text);
  }

  // Internal stop, e.g., on error
  void _stopRecordingInternal() {
    _aiService.stopProcessing();
    _isRecording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}
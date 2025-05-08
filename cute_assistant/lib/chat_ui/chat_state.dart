import 'dart:async';
import 'package:flutter/material.dart';
import '../services/on_device_ai_service.dart';

enum MessageSender { user, assistant }

class Message {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatState extends ChangeNotifier {
  final OnDeviceAIService _aiService;
  final List<Message> _messages = [];
  bool _isRecording = false;
  String _currentTranscript = ''; // Buffer for incoming STT results

  StreamSubscription? _transcriptSubscription;
  StreamSubscription? _llmTokenSubscription;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isRecording => _isRecording;
  String get currentTranscript => _currentTranscript; // Might be useful for UI to show live transcript

  ChatState(this._aiService) {
    _initializeListeners();
  }

  void _initializeListeners() {
    _transcriptSubscription = _aiService.transcriptStream.listen((transcript) {
      _currentTranscript = transcript; // Update live transcript
      // Decide if/when this live transcript should form a message or update UI directly
      print("ChatState: Live transcript: $_currentTranscript");
      notifyListeners(); 
    });

    _llmTokenSubscription = _aiService.llmTokenStream.listen((token) {
      if (_messages.isNotEmpty && _messages.last.sender == MessageSender.assistant) {
        // Append token to the last assistant message
        final lastMessage = _messages.last;
        _messages[_messages.length - 1] = Message(
          id: lastMessage.id,
          text: lastMessage.text + token,
          sender: MessageSender.assistant,
          timestamp: lastMessage.timestamp,
        );
      } else {
        // Start a new assistant message
        _addMessage(token, MessageSender.assistant, isStreamingToken: true);
      }
      notifyListeners();
    });
  }

  void _addMessage(String text, MessageSender sender, {bool isStreamingToken = false}) {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = Message(id: messageId, text: text, sender: sender);
    _messages.add(message);
    if (_messages.length > 50) { // Keep history manageable
        _messages.removeAt(0);
    }
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    _isRecording = !_isRecording;
    if (_isRecording) {
      _currentTranscript = ''; // Clear previous transcript before starting
      await _aiService.start();
      print("ChatState: Recording started.");
      // Optionally, add a placeholder message like "Listening..."
      // _addMessage("Listening...", MessageSender.assistant);
    } else {
      await _aiService.stop();
      print("ChatState: Recording stopped.");
      if (_currentTranscript.isNotEmpty) {
        // After stopping, if there's a final transcript, add it as a user message
        addUserMessage(_currentTranscript);
        _currentTranscript = ''; // Clear after processing
      }
    }
    notifyListeners();
  }

  // Called when user types and sends a message, or when voice input is finalized
  void addUserMessage(String text) {
    if (text.trim().isEmpty) return;
    _addMessage(text.trim(), MessageSender.user);
    // Here you could potentially send the text to the LLM via a different C++ function
    // if you want to support text input directly to the LLM without STT.
    // For now, we assume STT transcript from voice is the primary user input to LLM.
    print("ChatState: User message added: ${text.trim()}");
  }

  @override
  void dispose() {
    _transcriptSubscription?.cancel();
    _llmTokenSubscription?.cancel();
    _aiService.dispose(); // This will also call _nativeStop
    super.dispose();
    print("ChatState: Disposed.");
  }
}
// Simplified OnDeviceAIService
// LLM integration is commented out. The service now echoes user input back
// to the chat and TTS. Once the native bridge is ready, replace the marked
// sections with real FFI calls.

import 'dart:async';
import 'dart:io' show Platform;
// import 'dart:ffi'; // TODO: Re‑enable when native bridge is ready

import 'package:ffi/ffi.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:vad/vad.dart';

import '../vad/vad_settings.dart'; // Adjust import to your path

/// TTS playback state
enum TtsState { playing, stopped, paused, continued }

/// Core service that wires together VAD → STT → (LLM placeholder) → TTS.
class OnDeviceAIService {
  // -------- Public streams for the UI layer --------
  final _transcriptController = StreamController<String>.broadcast();
  final _llmResponseController = StreamController<String>.broadcast();
  final _isSpeakingController = StreamController<bool>.broadcast();
  final _isOverallListeningController = StreamController<bool>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get llmResponseStream => _llmResponseController.stream;
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;
  Stream<bool> get isOverallListeningStream => _isOverallListeningController.stream;

  // -------- Internal state --------
  final _vad = VadHandler.create(isDebug: false);
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _isVadListening = false;
  bool _isSttListening = false;

  final FlutterTts _tts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  // Settings (exposed so the UI dialog can modify them)
  VadSettings vadSettings = VadSettings();

  OnDeviceAIService() {
    _init();
  }

  Future<void> _init() async {
    await _initSTT();
    await _initTTS();
    _initVAD();
  }

  // ---------------- VAD ----------------
  void _initVAD() {
    _vad.onSpeechEnd.listen((samples) {
      if (_isVadListening) {
        _startSTT();
      }
    });
    _vad.onError.listen((err) {
      _transcriptController.addError('VAD error: \$err');
      _stopAll();
    });
  }

  // ---------------- STT ----------------
  Future<void> _initSTT() async {
    try {
      _sttReady = await _stt.initialize(
        onError: _onSttError,
        onStatus: _onSttStatus,
      );
    } catch (e) {
      _transcriptController.addError('STT init failed: \$e');
    }
  }

  void _startSTT() {
    if (!_sttReady || _isSttListening) return;
    _isSttListening = true;
    _stt.listen(
      onResult: _onSttResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
    );
  }

  void _onSttResult(SpeechRecognitionResult res) {
    _transcriptController.add(res.recognizedWords);
    if (res.finalResult) {
      _isSttListening = false;
      _isOverallListeningController.add(false);
      if (res.recognizedWords.isNotEmpty) {
        _handleText(res.recognizedWords);
      }
    }
  }

  void _onSttStatus(String status) {
    if (status == stt.SpeechToText.notListeningStatus) {
      _isSttListening = false;
    }
  }

  void _onSttError(SpeechRecognitionError err) {
    _transcriptController.addError('STT error: \${err.errorMsg}');
    _stopAll();
  }

  // ---------------- LLM Placeholder ----------------
  Future<void> _handleText(String text) async {
    // TODO: Replace this block with an FFI call that streams tokens
    _llmResponseController.add(text); // Echo the user text
    await _speak(text);
  }

  // ---------------- TTS ----------------
  Future<void> _initTTS() async {
    _tts.setStartHandler(() {
      _ttsState = TtsState.playing;
      _isSpeakingController.add(true);
    });
    _tts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _isSpeakingController.add(false);
    });
    _tts.setErrorHandler((msg) {
      _llmResponseController.addError('TTS error: \$msg');
      _ttsState = TtsState.stopped;
      _isSpeakingController.add(false);
    });
    await _tts.setSpeechRate(0.8);
  }

  Future<void> _speak(String text) async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  // ---------------- Public API ----------------
  Future<void> startListening() async {
    if (_isVadListening || _isSttListening) return;
    if (await Permission.microphone.request().isDenied) {
      _transcriptController.addError('Microphone permission denied');
      return;
    }
    _isOverallListeningController.add(true);
    _isVadListening = true;
    _vad.startListening(
      frameSamples: vadSettings.frameSamples,
      minSpeechFrames: vadSettings.minSpeechFrames,
      preSpeechPadFrames: vadSettings.preSpeechPadFrames,
      redemptionFrames: vadSettings.redemptionFrames,
      positiveSpeechThreshold: vadSettings.positiveSpeechThreshold,
      negativeSpeechThreshold: vadSettings.negativeSpeechThreshold,
      submitUserSpeechOnPause: vadSettings.submitUserSpeechOnPause,
      model: vadSettings.modelString,
      baseAssetPath: 'assets/packages/vad/assets/',
    );
  }

  Future<void> stopListening() async => _stopAll();

  void _stopAll() {
    if (_isVadListening) {
      _vad.stopListening();
      _isVadListening = false;
    }
    if (_isSttListening) {
      _stt.stop();
      _isSttListening = false;
    }
    _isOverallListeningController.add(false);
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;
    await _handleText(text);
  }

  // ---------------- Cleanup ----------------
  void dispose() {
    _vad.dispose();
    _stt.cancel();
    _tts.stop();

    _transcriptController.close();
    _llmResponseController.close();
    _isSpeakingController.close();
    _isOverallListeningController.close();
  }
}

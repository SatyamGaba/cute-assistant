import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;
// import 'package:ffi/ffi.dart';
import 'dart:isolate';

// Define C function signatures for FFI

// Called to initialize native part, passing Dart send ports for callbacks
typedef NativeInitializeDartApi = Void Function(Pointer<Void> data);
typedef NativeInitializePorts = Void Function(Int64 transcriptPort, Int64 llmTokenPort, Int64 speakingStatePort);
typedef NativeStartProcessing = Void Function();
typedef NativeStopProcessing = Void Function();
typedef NativeDispose = Void Function();

// Callback signatures from C to Dart (not directly used in FFI lookup)
// These are illustrative of what the native ports will carry
// typedef TranscriptCallback = Void Function(Pointer<Utf8> transcript);
// typedef LlmTokenCallback = Void Function(Pointer<Utf8> token);
// typedef SpeakingStateCallback = Void Function(Bool isSpeaking);


class OnDeviceAIService {
  late final DynamicLibrary _nativeLib;

  // FFI function pointers
  late final void Function(Pointer<Void>) _nativeInitializeDartApi;
  late final void Function(int, int, int) _nativeInitializePorts;
  late final void Function() _nativeStartProcessing;
  late final void Function() _nativeStopProcessing;
  late final void Function() _nativeDispose;

  // Stream controllers to send data from native to Dart UI
  final _transcriptController = StreamController<String>.broadcast();
  final _llmResponseController = StreamController<String>.broadcast();
  final _isSpeakingController = StreamController<bool>.broadcast();

  // ReceivePorts for getting data from native code
  late final ReceivePort _transcriptReceivePort;
  late final ReceivePort _llmTokenReceivePort;
  late final ReceivePort _speakingStateReceivePort;

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get llmResponseStream => _llmResponseController.stream;
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;

  OnDeviceAIService() {
    _loadNativeLibrary();
    _initializeNativeApi();
    _initializePorts();
  }

  void _loadNativeLibrary() {
    final libName = Platform.isAndroid ? "libai_bridge.so" : (Platform.isIOS ? "ai_bridge.framework/ai_bridge" : "libai_bridge.dylib");
    _nativeLib = DynamicLibrary.open(libName);

    // Lookup FFI functions
    _nativeInitializeDartApi = _nativeLib
        .lookup<NativeFunction<NativeInitializeDartApi>>('native_initialize_dart_api')
        .asFunction();
    _nativeInitializePorts = _nativeLib
        .lookup<NativeFunction<NativeInitializePorts>>('native_initialize_ports')
        .asFunction();
    _nativeStartProcessing = _nativeLib
        .lookup<NativeFunction<NativeStartProcessing>>('native_start_processing')
        .asFunction();
    _nativeStopProcessing = _nativeLib
        .lookup<NativeFunction<NativeStopProcessing>>('native_stop_processing')
        .asFunction();
    _nativeDispose = _nativeLib
        .lookup<NativeFunction<NativeDispose>>('native_dispose')
        .asFunction();
  }

  void _initializeNativeApi() {
    // Initialize Dart API for C. This is crucial for C to call back to Dart.
    _nativeInitializeDartApi(NativeApi.initializeApiDLData);
  }

  void _initializePorts() {
    _transcriptReceivePort = ReceivePort();
    _llmTokenReceivePort = ReceivePort();
    _speakingStateReceivePort = ReceivePort();

    _transcriptReceivePort.listen((dynamic message) {
      if (message is String) {
        _transcriptController.add(message);
      }
    });

    _llmTokenReceivePort.listen((dynamic message) {
      if (message is String) {
        _llmResponseController.add(message);
      }
    });

    _speakingStateReceivePort.listen((dynamic message) {
      if (message is bool) {
        _isSpeakingController.add(message);
      }
    });

    // Send native port IDs to C++ side
    _nativeInitializePorts(
      _transcriptReceivePort.sendPort.nativePort,
      _llmTokenReceivePort.sendPort.nativePort,
      _speakingStateReceivePort.sendPort.nativePort,
    );
  }

  void startProcessing() {
    _nativeStartProcessing();
  }

  void stopProcessing() {
    _nativeStopProcessing();
  }

  void dispose() {
    _nativeDispose();
    _transcriptReceivePort.close();
    _llmTokenReceivePort.close();
    _speakingStateReceivePort.close();
    _transcriptController.close();
    _llmResponseController.close();
    _isSpeakingController.close();
  }
}
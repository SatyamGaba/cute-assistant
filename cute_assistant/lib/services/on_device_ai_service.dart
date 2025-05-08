import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:isolate';

// FFI signature for native_start
typedef _NativeStart = Void Function(Int64 transcriptPort, Int64 llmTokenPort);
// Dart type for native_start
typedef _DartStart = void Function(int transcriptPort, int llmTokenPort);

// FFI signature for native_stop
typedef _NativeStop = Void Function();
// Dart type for native_stop
typedef _DartStop = void Function();

class OnDeviceAIService {
  late final DynamicLibrary _nativeLib;
  late final _DartStart _nativeStart;
  late final _DartStop _nativeStop;

  final _transcriptController = StreamController<String>.broadcast();
  final _llmTokenController = StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get llmTokenStream => _llmTokenController.stream;

  ReceivePort? _transcriptPort;
  ReceivePort? _llmTokenPort;

  OnDeviceAIService() {
    _loadNativeLibrary();
    _initializeApiDL();
  }

  void _loadNativeLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      _nativeLib = DynamicLibrary.open('libai_bridge.so');
    } else if (Platform.isIOS) {
      _nativeLib = DynamicLibrary.process(); // iOS static linking
    } else if (Platform.isMacOS) {
      _nativeLib = DynamicLibrary.open('libai_bridge.dylib');
    } else if (Platform.isWindows) {
      _nativeLib = DynamicLibrary.open('ai_bridge.dll');
    } else {
      throw UnsupportedError('Unsupported platform for FFI');
    }

    _nativeStart = _nativeLib
        .lookup<NativeFunction<_NativeStart>>('native_start')
        .asFunction<_DartStart>();
    _nativeStop = _nativeLib
        .lookup<NativeFunction<_NativeStop>>('native_stop')
        .asFunction<_DartStop>();
  }
  
  void _initializeApiDL() {
    // Initialize Dart DL C API. This is essential for NativePort communication.
    // Dart_InitializeApiDL must be called before any Dart_PostCObjectDL can be used from C++.
    // NativeApi.initializeApiDLData ensures this binding is available to the C++ side.
    // The C++ side will call Dart_InitializeApiDL(data) with data obtained from here.
    // For simplicity in this example, we're relying on the C++ side to correctly call
    // Dart_InitializeApiDL. A more robust solution might involve passing the
    // initializeApiDLData.data pointer to a C++ initialization function.
    // However, for Native Ports, the initialization is usually handled by the Dart VM
    // when a SendPort.nativePort is created and used by native code.
    // The key is that the C++ side has access to dart_api_dl.h and links against the Dart API.
  }

  Future<void> start() async {
    _transcriptPort = ReceivePort();
    _llmTokenPort = ReceivePort();

    _transcriptPort!.listen((dynamic message) {
      if (message is String) {
        _transcriptController.add(message);
      }
    });

    _llmTokenPort!.listen((dynamic message) {
      if (message is String) {
        _llmTokenController.add(message);
      }
    });

    _nativeStart(_transcriptPort!.sendPort.nativePort, _llmTokenPort!.sendPort.nativePort);
    print("OnDeviceAIService: Started native pipeline.");
  }

  Future<void> stop() async {
    _nativeStop();
    _transcriptPort?.close();
    _llmTokenPort?.close();
    _transcriptPort = null;
    _llmTokenPort = null;
    print("OnDeviceAIService: Stopped native pipeline.");
  }

  void dispose() {
    stop(); // Ensure pipeline is stopped
    _transcriptController.close();
    _llmTokenController.close();
    print("OnDeviceAIService: Disposed.");
  }
} 
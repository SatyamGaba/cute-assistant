import 'package:flutter/material.dart';
import 'chat_ui/chat_screen.dart';
import 'chat_ui/chat_state.dart';
import 'services/on_device_ai_service.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // It's good practice to initialize services that might need async setup here
  // For OnDeviceAIService, FFI setup is synchronous but permissions might be async
  runApp(const VoiceAssistantApp());
}

class VoiceAssistantApp extends StatelessWidget {
  const VoiceAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // The OnDeviceAIService can be provided here if needed by multiple parts,
        // or instantiated directly within ChatState if only used there.
        // For simplicity, ChatState will instantiate it directly for now.
        ChangeNotifierProvider(create: (_) => ChatState(OnDeviceAIService())),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'On-device Assistant',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF202123), // Main background
          cardColor: const Color(0xFF2A2B32), // Slightly lighter for elements
          primaryColor: const Color(0xFF10A37F), // Accent color (like ChatGPT green)
          textTheme: ThemeData.dark().textTheme.apply(
                bodyColor: const Color(0xFFECECEC), // Light gray text
                displayColor: const Color(0xFFECECEC),
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF202123), // AppBar same as scaffold
            elevation: 0.5, // Subtle shadow
            titleTextStyle: TextStyle(color: Color(0xFFECECEC), fontSize: 20),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: const Color(0xFF10A37F), // Accent for FAB
            foregroundColor: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme( // For potential text input
            filled: true,
            fillColor: const Color(0xFF343541),
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
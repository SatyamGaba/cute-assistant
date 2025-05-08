import 'package:flutter/material.dart';
import 'chat_ui/chat_screen.dart';
import 'chat_ui/chat_state.dart';
import 'services/on_device_ai_service.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Dart_InitializeApiDL will be called by the C++ code when it's loaded.
  // No explicit call needed here if using dart_api_dl.h and linking correctly.
  runApp(const VoiceAssistantApp());
}

class VoiceAssistantApp extends StatelessWidget {
  const VoiceAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide OnDeviceAIService first if ChatState depends on it directly
        Provider<OnDeviceAIService>(create: (_) => OnDeviceAIService()),
        // Then provide ChatState, which takes OnDeviceAIService from the context
        ChangeNotifierProvider<ChatState>(
          create: (context) => ChatState(context.read<OnDeviceAIService>()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'On-Device Assistant',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF202123), // Main background
          cardColor: const Color(0xFF2A2B32), // Slightly lighter for elements (e.g., assistant messages)
          primaryColor: const Color(0xFF10A37F), // Accent color (ChatGPT green for user messages, buttons)
          textTheme: ThemeData.dark().textTheme.apply(
                bodyColor: const Color(0xFFECECEC), // Light gray text
                displayColor: const Color(0xFFECECEC),
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF202123), // AppBar same as scaffold
            elevation: 0.5, // Subtle shadow
            titleTextStyle: TextStyle(color: Color(0xFFECECEC), fontSize: 20, fontWeight: FontWeight.w500),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF10A37F), // Accent for FAB
            foregroundColor: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF343541), // Darker input field background
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(color: Color(0xFF10A37F), width: 1.5), // Accent color on focus
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          ),
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
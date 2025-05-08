import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_state.dart'; // Assuming chat_state.dart is in the same directory

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatState = Provider.of<ChatState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device Assistant'),
        actions: [
          // Optional: display a live transcript or recording status in app bar
          if (chatState.isRecording && chatState.currentTranscript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: Text(chatState.currentTranscript, style: TextStyle(fontStyle: FontStyle.italic))), 
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // To show latest messages at the bottom
              padding: const EdgeInsets.all(16.0),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final message = chatState.messages[chatState.messages.length - 1 - index];
                final isUser = message.sender == MessageSender.user;
                return _buildMessageBubble(context, message, isUser, theme);
              },
            ),
          ),
          _buildTextInputArea(context, chatState, theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message, bool isUser, ThemeData theme) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser 
              ? theme.primaryColor // User message color (ChatGPT green)
              : theme.cardColor, // Assistant message color (slightly lighter dark shade)
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputArea(BuildContext context, ChatState chatState, ThemeData theme) {
    final textController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Or theme.cardColor for a slight contrast
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          )
        ]
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor ?? theme.cardColor, // From theme
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  chatState.addUserMessage(text);
                  textController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 8.0),
          FloatingActionButton(
            mini: true,
            onPressed: () {
              chatState.toggleRecording();
            },
            backgroundColor: theme.floatingActionButtonTheme.backgroundColor ?? theme.primaryColor,
            child: Icon(
              chatState.isRecording ? Icons.stop : Icons.mic,
              color: theme.floatingActionButtonTheme.foregroundColor ?? Colors.white,
            ),
          ),
          const SizedBox(width: 4.0),
          IconButton(
            icon: Icon(Icons.send, color: theme.primaryColor),
            onPressed: () {
              final text = textController.text;
              if (text.isNotEmpty) {
                chatState.addUserMessage(text);
                textController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}
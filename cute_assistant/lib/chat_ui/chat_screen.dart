import 'package:flutter/material.dart';
import 'chat_state.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ChatState>();
    final messages = chatState.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Assistant'),
        actions: [
          // Example: Indicator for AI speaking
          if (chatState.isAISpeaking)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.volume_up, color: Colors.lightBlueAccent),
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // To show latest messages at the bottom
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                return _buildMessageBubble(context, message);
              },
            ),
          ),
          // You could add a text input field here as well for typed messages
          _buildInputArea(context, chatState),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message) {
    final bool isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: isUser ? theme.primaryColor.withOpacity(0.9) : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: isUser ? const Radius.circular(16.0) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Text(
          message.text,
          style: TextStyle(color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatState chatState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 5,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Optional: Text input field
          // Expanded(
          //   child: TextField(
          //     decoration: InputDecoration(hintText: "Type a message..."),
          //   ),
          // ),
          // SizedBox(width: 8),
          FloatingActionButton(
            onPressed: chatState.toggleRecording,
            backgroundColor: chatState.isRecording ? Colors.redAccent : Theme.of(context).primaryColor,
            elevation: 2.0,
            child: Icon(chatState.isRecording ? Icons.stop : Icons.mic, size: 28),
          ),
        ],
      ),
    );
  }
}
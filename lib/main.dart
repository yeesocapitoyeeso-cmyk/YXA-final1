import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // 🟢 Upgrade: For timestamps
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const CampusChatApp());
}

// ✅ Fixed function name + missing code
String getBackendUrl() {
  if (kIsWeb) {
    return "http://127.0.0.1:8000/chat"; // 🌐 For Flutter Web
  } else if (Platform.isAndroid) {
    return "http://10.0.2.2:8000/chat"; // 📱 For Android Emulator
  } else {
    return "http://127.0.0.1:8000/chat"; // 💻 For desktop or iOS simulator
  }
}

class CampusChatApp extends StatelessWidget {
  const CampusChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Chatbot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        fontFamily: 'Roboto', // 🟢 Upgrade: Clean consistent font
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages =
      []; // 🟢 Upgrade: dynamic for timestamp
  bool _isSending = false;

  // ✅ Changed to auto-detect backend
  final String backendUrl = getBackendUrl();

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isSending) return;

    final timestamp = DateFormat('hh:mm a').format(DateTime.now());
    setState(() {
      _messages.add({"sender": "user", "text": message, "time": timestamp});
      _isSending = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      final botTime = DateFormat('hh:mm a').format(DateTime.now());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({
            "sender": "bot",
            "text": data["reply"],
            "time": botTime,
          });
        });
      } else {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text": "⚠️ Server error: ${response.statusCode}",
            "time": botTime,
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "sender": "bot",
          "text": "❌ Cannot connect to backend. Is FastAPI running?",
          "time": DateFormat('hh:mm a').format(DateTime.now()),
        });
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg["sender"] == "user";
    final bubbleColor = isUser
        ? const Color.fromARGB(255, 138, 32, 32)
        : Colors.grey.shade300;
    final textColor = isUser ? Colors.white : Colors.black87;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg["text"] ?? "",
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              msg["time"] ?? "",
              style: TextStyle(
                fontSize: 11,
                color: isUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "⚙️ Settings",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Feature placeholder — you can add options here later."),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text("Close"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎓 Campus Chatbot"),
        backgroundColor: const Color.fromARGB(255, 138, 32, 32),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask me something about campus...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color.fromARGB(255, 138, 32, 32),
                        ),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

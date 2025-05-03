import 'dart:async'; // Import for asynchronous programming
import 'dart:convert'; // Import for JSON encoding/decoding
import 'package:flutter/material.dart'; // Import Flutter material design package
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv for environment variables
import 'package:http/http.dart' as http; // Import HTTP package for API requests
import 'package:logging/logging.dart'; // Import logging package
import 'package:shared_preferences/shared_preferences.dart'; // Import for local data storage
import 'package:flutter_tts/flutter_tts.dart'; // Import for Text-To-Speech functionality

// ChatScreen is the main widget showing the chat UI
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ChatScreenState createState() => ChatScreenState(); // Create the state object
}

// State class for ChatScreen
class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController(); // Controller for input field
  final List<ChatMessage> _messages = []; // List to store messages (user and bot)
  final List<Map<String, String>> _chatHistory = [
    {
      "role": "system",
      "content": "You are a funny chatbot. Respond to all user inputs with humor. Also remember user's name if they tell you."
    },
  ]; // Initial system prompt to guide chatbot behavior
  bool _isTyping = false; // Boolean to track if the bot is currently typing
  DateTime? _lastRequestTime; // Last time a request was sent
  final Duration _rateLimitDuration = const Duration(seconds: 3); // Minimum gap between requests
  final _logger = Logger('ChatScreen'); // Logger instance for logging

  // Voice output using text-to-speech
  late FlutterTts _flutterTts; 

  @override
  void initState() {
    super.initState();
    _loadMessages(); // Load saved messages on startup
    _flutterTts = FlutterTts(); // Initialize FlutterTts instance
  }

  // Save chat messages to shared preferences (local storage)
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonMessages = _messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await prefs.setStringList('chatMessages', jsonMessages);
  }

  // Load chat messages from shared preferences (if any)
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonMessages = prefs.getStringList('chatMessages');
    if (jsonMessages != null) {
      setState(() {
        _messages.addAll(jsonMessages.map((jsonMsg) => ChatMessage.fromJson(jsonDecode(jsonMsg))));
      });
    }
  }

  // Send a message to the chatbot API and get a response
  Future<void> _sendMessage(String text) async {
    if (_isTyping || text.trim().isEmpty) return; // Prevent sending if already typing or text is empty

    final now = DateTime.now();
    if (_lastRequestTime != null && now.difference(_lastRequestTime!) < _rateLimitDuration) {
      // If sending too fast, show a warning message
      setState(() {
        _messages.insert(
          0,
          const ChatMessage(
            text: '🚀 Please wait a few seconds before sending another message.',
            isUser: false,
          ),
        );
      });
      _saveMessages();
      return;
    }
    _lastRequestTime = now; // Update the last request time

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true)); // Add user message
      _chatHistory.add({"role": "user", "content": text}); // Add user message to chat history
      _isTyping = true; // Set typing status
      _controller.clear(); // Clear the input box
    });
    _saveMessages(); // Save messages locally

    try {
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      if (apiKey.isEmpty) throw Exception('GROQ_API_KEY is missing.'); // Ensure API key is available

      // Send HTTP POST request to Groq API
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "meta-llama/llama-4-scout-17b-16e-instruct", // Model name
          "messages": _chatHistory,
          "temperature": 0.9,
          "top_p": 1.0,
          "max_tokens": 1024
        }),
      );

      _logger.info('Response Status: ${response.statusCode}');
      _logger.info('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // If successful, parse and show bot reply
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] ?? 
            "🤖 Oops! I couldn't think of a funny reply. Try again!";
        setState(() {
          _messages.insert(0, ChatMessage(text: reply, isUser: false)); // Show bot reply
          _chatHistory.add({"role": "assistant", "content": reply}); // Update chat history
        });
        _speak(reply); // Speak the reply using TTS
        _saveMessages(); // Save updated chat
      } else {
        // If API returns error
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']['message'] ?? 'Unknown API error';
        throw Exception('API Error: $errorMsg');
      }
    } catch (e) {
      // Handle exceptions
      _logger.severe('Error occurred: $e');
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: '⚠️ ${e.toString().replaceAll(RegExp(r'^Exception: '), '')}',
            isUser: false,
          ),
        );
      });
      _saveMessages();
    } finally {
      setState(() => _isTyping = false); // Reset typing status
    }
  }

  // Speak the text using text-to-speech
  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
    _logger.fine("Speaking: $text");
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose input controller
    super.dispose();
  }

  // Build UI for each message bubble
  Widget _buildMessage(String text, bool isUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start, // Align based on user/bot
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.teal[600]!.withValues()
                    : Colors.blue[50]!.withValues(), // Different color for user and bot
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser ? Colors.teal.withValues() : Colors.grey.withValues(),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🚀 My Funny Chatbot 🤖',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 5,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Clear chat',
            onPressed: () async {
              if (_messages.isNotEmpty) {
                // Confirm clearing chat
                final confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear chat?'),
                    content: const Text('This will delete all messages.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  setState(() {
                    _messages.clear();
                    _chatHistory.clear();
                    _chatHistory.add({
                      "role": "system",
                      "content": "You are a funny chatbot. Respond to all user inputs with humor. Also remember user's name if they tell you."
                    });
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('chatMessages'); // Clear saved messages
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Show newest message at the bottom
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0), // Add extra item if typing
              itemBuilder: (context, index) {
                if (_isTyping && index == 0) {
                  return _buildMessage('🤖 is typing...', false); // Typing indicator
                }
                final message = _messages[index - (_isTyping ? 1 : 0)];
                return _buildMessage(message.text, message.isUser); // Build message bubble
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Type something funny...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.teal,
                        onPressed: () => _sendMessage(_controller.text), // Send message when button pressed
                      ),
                    ),
                    onSubmitted: _sendMessage, // Send when pressing 'enter'
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Model class for ChatMessage (user or bot)
class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});

  // Convert ChatMessage to JSON
  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
      };

  // Create ChatMessage from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isUser: json['isUser'],
      );
}

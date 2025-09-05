import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart'; // Import the new package

// --- Main Chat Screen Widget ---
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _chatHistory = [
    {
      "role": "system",
      "content":
          "You are a funny chatbot. Respond to all user inputs with humor. Also remember user's name if they tell you."
    },
  ];

  bool _isTyping = false;
  DateTime? _lastRequestTime;
  final Duration _rateLimitDuration = const Duration(seconds: 3);
  final _logger = Logger('ChatScreen');

  // TTS and STT state
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String? _currentlySpeakingId; // NEW: Tracks the ID of the message being spoken

  // UI/UX Enhancements
  final ScrollController _scrollController = ScrollController(); // NEW: For auto-scrolling
  final Uuid _uuid = const Uuid(); // NEW: For generating unique IDs

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadMessages();
  }

  Future<void> _initializeServices() async {
    // --- TTS Initialization ---
    _flutterTts = FlutterTts();
    // NEW: Set up handlers to know when speaking starts and stops
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _currentlySpeakingId = null;
        });
      }
    });
    _flutterTts.setErrorHandler((msg) {
       if (mounted) {
        setState(() {
          _currentlySpeakingId = null;
        });
        _logger.severe("TTS Error: $msg");
      }
    });

    // --- STT Initialization ---
    _speech = stt.SpeechToText();
  }

  // --- Speech-to-Text Logic ---
  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => _logger.info("Speech status: $status"),
      onError: (error) => _logger.warning("Speech error: $error"),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // --- Text-to-Speech Logic (MODIFIED) ---
  Future<void> _speak(ChatMessage message) async {
    // Stop any currently playing message before starting a new one
    await _flutterTts.stop();
    setState(() => _currentlySpeakingId = message.id);
    await _flutterTts.speak(message.text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() => _currentlySpeakingId = null);
  }

  // --- Data Persistence ---
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonMessages =
        _messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await prefs.setStringList('chatMessages', jsonMessages);
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonMessages = prefs.getStringList('chatMessages');
    if (jsonMessages != null) {
      setState(() {
        _messages.addAll(jsonMessages
            .map((jsonMsg) => ChatMessage.fromJson(jsonDecode(jsonMsg))));
      });
    }
  }

  // NEW: Helper to auto-scroll to the bottom of the list
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- Core Message Sending Logic (MODIFIED) ---
  Future<void> _sendMessage(String text) async {
    if (_isTyping || text.trim().isEmpty) return;
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    // Rate limiting remains the same
    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!) < _rateLimitDuration) {
      final rateLimitMessage = ChatMessage(
        id: _uuid.v4(),
        text: '🚀 Please wait a few seconds before sending another message.',
        isUser: false,
      );
      setState(() => _messages.insert(0, rateLimitMessage));
      _saveMessages();
      return;
    }
    _lastRequestTime = now;

    // Create a user message with a unique ID
    final userMessage = ChatMessage(id: _uuid.v4(), text: text, isUser: true);

    setState(() {
      _messages.insert(0, userMessage);
      _chatHistory.add({"role": "user", "content": text});
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();
    _saveMessages();

    try {
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      if (apiKey.isEmpty) throw Exception('GROQ_API_KEY is missing.');

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "meta-llama/llama-4-scout-17b-16e-instruct", // Using a faster model
          "messages": _chatHistory,
          "temperature": 0.7,
          "max_tokens": 1024
        }),
      );

      _logger.info('Response Status: ${response.statusCode}');
      _logger.info('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] ??
            "🤖 Oops! I couldn't think of a funny reply. Try again!";
        
        final botMessage = ChatMessage(id: _uuid.v4(), text: reply, isUser: false);
        
        setState(() {
          _messages.insert(0, botMessage);
          _chatHistory.add({"role": "assistant", "content": reply});
        });
        _saveMessages();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']['message'] ?? 'Unknown API error';
        throw Exception('API Error: $errorMsg');
      }
    } catch (e) {
      _logger.severe('Error occurred: $e');
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        text: '⚠️ ${e.toString().replaceAll(RegExp(r'^Exception: '), '')}',
        isUser: false,
      );
      setState(() => _messages.insert(0, errorMessage));
      _saveMessages();
    } finally {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  // --- Clear Chat Logic ---
  Future<void> _clearChat() async {
    if (_messages.isEmpty) return;

    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This will permanently delete all messages.'),
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
        _chatHistory.removeRange(1, _chatHistory.length); // Keep system prompt
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chatMessages');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose(); // NEW: Dispose the scroll controller
    _flutterTts.stop();
    super.dispose();
  }

  // --- Build Method & UI Widgets ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '🚀 My Funny Chatbot 🤖',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear chat',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState() // NEW: Show empty state
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == 0) {
                        return _buildBotMessage(
                          ChatMessage(id: 'typing', text: '...', isUser: false),
                          isTyping: true
                        );
                      }
                      final message = _messages[index - (_isTyping ? 1 : 0)];
                      return message.isUser
                          ? _buildUserMessage(message)
                          : _buildBotMessage(message);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // NEW: Widget for the empty chat screen
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Ask me anything!',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // NEW: Refactored widget for building user messages
  Widget _buildUserMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: Colors.teal[600],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  // NEW: Refactored widget for building bot messages
  Widget _buildBotMessage(ChatMessage message, {bool isTyping = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.teal,
            child: Text('🤖', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 8.0),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(),
                    spreadRadius: 1,
                    blurRadius: 3,
                  )
                ],
              ),
              child: isTyping 
              ? const Text("Typing...", style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        message.text,
                        style: const TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // --- THE NEW TTS & STOP BUTTON ---
                    InkWell(
                      onTap: _currentlySpeakingId == message.id
                          ? _stopSpeaking
                          : () => _speak(message),
                      child: Icon(
                        _currentlySpeakingId == message.id
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        color: Colors.teal,
                        size: 24,
                      ),
                    )
                  ],
                ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Refactored widget for the text input area
  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 3,
            color: Colors.grey.withValues(),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              color: Colors.teal,
              onPressed: _isListening ? _stopListening : _startListening,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type something funny...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              mini: true,
              backgroundColor: Colors.teal,
              onPressed: () => _sendMessage(_controller.text),
              child: const Icon(Icons.send, color: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}

// --- ChatMessage Model (MODIFIED) ---
class ChatMessage {
  final String id; // NEW: Unique ID for each message
  final String text;
  final bool isUser;

  ChatMessage({required this.id, required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        // Use a new Uuid if the loaded message doesn't have one (for backwards compatibility)
        id: json['id'] ?? const Uuid().v4(),
        text: json['text'],
        isUser: json['isUser'],
      );
}
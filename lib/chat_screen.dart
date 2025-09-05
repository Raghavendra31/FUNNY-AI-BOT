import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _chatHistory = [
    {
      "role": "system",
      "content": "You are a funny chatbot. Respond to all user inputs with humor. Also remember user's name if they tell you."
    },
  ];
  bool _isTyping = false;
  DateTime? _lastRequestTime;
  final Duration _rateLimitDuration = const Duration(seconds: 3);
  final _logger = Logger('ChatScreen');
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _speechText = '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _flutterTts = FlutterTts();
    _speech = stt.SpeechToText();
  }

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
            _speechText = result.recognizedWords;
            _controller.text = _speechText;
          });
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

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
        _messages.addAll(
            jsonMessages.map((jsonMsg) => ChatMessage.fromJson(jsonDecode(jsonMsg))));
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (_isTyping || text.trim().isEmpty) return;

    final now = DateTime.now();
    if (_lastRequestTime != null &&
        now.difference(_lastRequestTime!) < _rateLimitDuration) {
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
    _lastRequestTime = now;

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));
      _chatHistory.add({"role": "user", "content": text});
      _isTyping = true;
      _controller.clear();
    });
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
          "model": "meta-llama/llama-4-scout-17b-16e-instruct",
          "messages": _chatHistory,
          "temperature": 0.9,
          "top_p": 1.0,
          "max_tokens": 1024
        }),
      );

      _logger.info('Response Status: ${response.statusCode}');
      _logger.info('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] ??
            "🤖 Oops! I couldn't think of a funny reply. Try again!";
        setState(() {
          _messages.insert(0, ChatMessage(text: reply, isUser: false));
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
      setState(() => _isTyping = false);
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
    _logger.fine("Speaking: $text");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMessage(String text, bool isUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.teal[600] : Colors.blue[50],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser ? Colors.teal.shade300 : Colors.grey.shade400,
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
                  await prefs.remove('chatMessages');
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
              reverse: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == 0) {
                  return _buildMessage('🤖 is typing...', false);
                }
                final message = _messages[index - (_isTyping ? 1 : 0)];
                return _buildMessage(message.text, message.isUser);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  color: Colors.teal,
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  color: Colors.teal,
                  tooltip: 'Speak last response',
                  onPressed: () {
                    for (final msg in _messages) {
                      if (!msg.isUser) {
                        _speak(msg.text);
                        break;
                      }
                    }
                  },
                ),
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
                      fillColor: const Color.fromARGB(255, 5, 218, 168),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.teal,
                        onPressed: () => _sendMessage(_controller.text),
                      ),
                    ),
                    onSubmitted: _sendMessage,
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

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isUser: json['isUser'],
      );
}

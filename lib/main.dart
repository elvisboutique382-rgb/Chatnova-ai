import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nova AI',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: const ChatScreen(),
    );
  }
}

class Message {
  final String role;
  final String content;

  const Message({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class ApiService {
  // Your Railway backend.
  static const String baseUrl =
      'https://nova-ai-production-25eb.up.railway.app/api';

  static Future<String> sendMessage({
    required List<Message> messages,
    required String provider,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/chat'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'provider': provider.toLowerCase(),
            'messages': messages.map((m) => m.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Server error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      if (data['success'] == true && data['message'] != null) {
        return data['message'].toString();
      }

      if (data['message'] != null) {
        return data['message'].toString();
      }

      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }
    }

    throw Exception('Unexpected response from server.');
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

  final List<Message> _messages = [];

  String _provider = 'Auto';
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isLoading) return;

    _controller.clear();

    setState(() {
      _messages.add(
        Message(
          role: 'user',
          content: text,
        ),
      );
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final reply = await ApiService.sendMessage(
        messages: List<Message>.from(_messages),
        provider: _provider,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          Message(
            role: 'assistant',
            content: reply,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          Message(
            role: 'assistant',
            content: 'Sorry, something went wrong.\n\n$e',
          ),
        );
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _newChat() {
    setState(() {
      _messages.clear();
    });
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Icon(Icons.auto_awesome),
            ),
            SizedBox(width: 10),
            Text(
              'Nova AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildProviderSelector(),
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : _buildMessages(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Text(
            'AI:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _provider,
            items: const [
              DropdownMenuItem(
                value: 'Auto',
                child: Text('Auto'),
              ),
              DropdownMenuItem(
                value: 'OpenAI',
                child: Text('OpenAI'),
              ),
              DropdownMenuItem(
                value: 'Claude',
                child: Text('Claude'),
              ),
              DropdownMenuItem(
                value: 'Gemini',
                child: Text('Gemini'),
              ),
            ],
            onChanged: _isLoading
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _provider = value;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Nova AI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your all in one assistant',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ask questions, learn, write, brainstorm and get help with your studies.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SpinKitThreeBounce(
                size: 20,
                color: Colors.deepPurple,
              ),
            ),
          );
        }

        final message = _messages[index];
        final isUser = message.role == 'user';

        return Align(
          alignment:
              isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 340,
            ),
            margin: const EdgeInsets.symmetric(
              vertical: 6,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.content,
                  style: TextStyle(
                    color: isUser
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (!isUser)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      tooltip: 'Copy',
                      iconSize: 18,
                      onPressed: () {
                        _copyMessage(message.content);
                      },
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Message Nova AI...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              mini: true,
              onPressed: _isLoading ? null : _sendMessage,
              child: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AIChatOpenAIScreen extends StatefulWidget {
  @override
  _AIChatOpenAIScreenState createState() => _AIChatOpenAIScreenState();
}

class _AIChatOpenAIScreenState extends State<AIChatOpenAIScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  int _remainingQuestions = 10;
  DateTime? _lastResetDate;

  final String openaiApiKey =
      'YOUR_OPENAI_API_KEY'; // Thay thế bằng API key của bạn
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_remainingQuestions <= 0) {
      _showLimitExceededDialog();
      return;
    }

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add({
        'text': userMessage,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openaiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Bạn là Dora, trợ lý AI thân thiện, trả lời bằng tiếng Việt.',
            },
            {'role': 'user', 'content': userMessage},
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];

        setState(() {
          _messages.add({
            'text': aiResponse.trim(),
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
          _remainingQuestions--;
        });

        await _updateUserLimits();
        _scrollToBottom();
      } else {
        throw Exception('OpenAI error: ${response.body}');
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _isLoading = false;
        _messages.add({
          'text': 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại sau.',
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
      _scrollToBottom();
    }
  }

  Future<void> _updateUserLimits() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('ai_chat_limits').doc(userId).update({
      'remaining_questions': _remainingQuestions,
      'last_reset': _lastResetDate,
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  void _showLimitExceededDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đã hết lượt hỏi'),
          content: const Text('Bạn đã dùng hết số lượt hỏi trong ngày.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser ? Colors.blue[100] : Colors.grey[300];
    final textColor = Colors.black;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(message['text'], style: TextStyle(color: textColor)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dora Chat'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessage(message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập câu hỏi...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  child: const Text('Gửi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

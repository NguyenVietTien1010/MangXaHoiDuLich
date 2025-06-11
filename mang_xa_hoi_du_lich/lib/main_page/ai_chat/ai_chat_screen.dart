import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  int _remainingQuestions = 10;
  DateTime? _lastResetDate;
  static const String _apiKey = 'your_api_key';
  final url = Uri.parse(
    "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$_apiKey",
  );
  final String _apiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  @override
  void initState() {
    super.initState();
    _loadUserLimits();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages.add({
          'text': 'Xin chào, tôi là Dora, tôi có thể giúp gì cho bạn?',
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserLimits() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await _firestore.collection('ai_chat_limits').doc(userId).get();

    if (!userDoc.exists) {
      // First time user
      await _firestore.collection('ai_chat_limits').doc(userId).set({
        'remaining_questions': 10,
        'last_reset': DateTime.now(),
      });
      setState(() {
        _remainingQuestions = 10;
        _lastResetDate = DateTime.now();
      });
      return;
    }

    final data = userDoc.data()!;
    final lastReset = (data['last_reset'] as Timestamp).toDate();

    if (!_isSameDay(lastReset, DateTime.now())) {
      // Reset for new day
      await _firestore.collection('ai_chat_limits').doc(userId).update({
        'remaining_questions': 10,
        'last_reset': DateTime.now(),
      });
      setState(() {
        _remainingQuestions = 10;
        _lastResetDate = DateTime.now();
      });
    } else {
      setState(() {
        _remainingQuestions = data['remaining_questions'] as int;
        _lastResetDate = lastReset;
      });
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
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
        Uri.parse('$_apiEndpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": userMessage},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        setState(() {
          _messages.add({
            'text': aiResponse,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
          _isLoading = false;
          _remainingQuestions--;
        });

        await _updateUserLimits();
        _scrollToBottom();
      } else {
        throw Exception('Failed to get AI response: ${response.body}');
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

  void _showLimitExceededDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Giới hạn đã đạt'),
            content: const Text(
              'Bạn đã sử dụng hết 10 câu hỏi cho ngày hôm nay. Vui lòng quay lại vào ngày mai.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trò chuyện với AI (${_remainingQuestions}/10)',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF63AB83),
        leading: SizedBox.shrink(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundImage: AssetImage('assets/icon/avatar_ai.jpg'),
                radius: 16,
              ),
            ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color:
                    isUser
                        ? const Color(0xFF63AB83)
                        : const Color.fromARGB(255, 255, 255, 255),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                message['text'] as String,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF63AB83),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
                radius: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText:
                    _remainingQuestions > 0
                        ? 'Nhập tin nhắn...'
                        : 'Đã hết lượt hỏi hôm nay',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              enabled: _remainingQuestions > 0,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor:
                _remainingQuestions > 0 ? const Color(0xFF63AB83) : Colors.grey,
            child: IconButton(
              icon: const Icon(LineIcons.paperPlane, color: Colors.white),
              onPressed: _remainingQuestions > 0 ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }
}

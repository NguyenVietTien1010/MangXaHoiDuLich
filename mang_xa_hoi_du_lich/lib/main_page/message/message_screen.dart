import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import 'package:mang_xa_hoi_du_lich/main_page/message/chat_with_friends.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _conversationLimit = 20;
  DocumentSnapshot? _lastConversation;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(
          child: Text(
            'Vui lòng đăng nhập để xem tin nhắn',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Tin nhắn',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF63AB83),
        elevation: 2,
        leading: SizedBox.shrink(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF63AB83),
        elevation: 4,
        onPressed: () => _showCreateGroupDialog(context),
        child: const Icon(LineIcons.objectGroup, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('conversations')
                .where('members', arrayContains: currentUserId)
                .orderBy('lastMessageTime', descending: true)
                .limit(_conversationLimit)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorMessage(
              'Lỗi kết nối với máy chủ. Vui lòng thử lại.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = snapshot.data!.docs;
          _lastConversation =
              conversations.isNotEmpty ? conversations.last : null;

          if (conversations.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có cuộc trò chuyện nào. Hãy bắt đầu một nhóm mới!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == conversations.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final conversation = conversations[index];
              final data = conversation.data() as Map<String, dynamic>? ?? {};
              final isGroup = data['type'] == 'group';
              final members = List<String>.from(data['members'] ?? []);
              final lastMessage =
                  data['lastMessage'] as String? ?? 'Chưa có tin nhắn';
              final lastMessageTime =
                  (data['lastMessageTime'] as Timestamp?)?.toDate();
              final formattedTime =
                  lastMessageTime != null
                      ? DateFormat('HH:mm').format(lastMessageTime)
                      : '';

              if (members.isEmpty) {
                return const ListTile(title: Text('Hội thoại không hợp lệ'));
              }

              return FutureBuilder<String>(
                future: _getConversationName(conversation.id, isGroup, members),
                builder: (context, nameSnapshot) {
                  if (nameSnapshot.hasError) {
                    return _buildErrorMessage('Lỗi tải tên hội thoại');
                  }
                  if (!nameSnapshot.hasData) {
                    return const ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('Đang tải...'),
                    );
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: FutureBuilder<String>(
                        future:
                            isGroup
                                ? Future.value(
                                  data['avatarUrl'] as String? ??
                                      'assets/messages/default_avatar.png',
                                )
                                : _getAvatarUrl(members, currentUserId),
                        builder: (context, avatarSnapshot) {
                          if (!avatarSnapshot.hasData) {
                            return const CircleAvatar(
                              radius: 24,
                              backgroundImage: AssetImage(
                                'assets/messages/default_avatar.png',
                              ),
                            );
                          }
                          if (isGroup) {
                            return CircleAvatar(
                              radius: 24,
                              backgroundImage: AssetImage(
                                avatarSnapshot.data ??
                                    'assets/messages/default_avatar.png',
                              ),
                            );
                          } else {
                            return CircleAvatar(
                              radius: 24,
                              backgroundImage: CachedNetworkImageProvider(
                                avatarSnapshot.data ??
                                    'https://via.placeholder.com/150',
                              ),
                            );
                          }
                        },
                      ),
                      title: Text(
                        nameSnapshot.data!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      trailing: Text(
                        formattedTime,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ChatScreen(
                                  conversationId: conversation.id,
                                  isGroup: isGroup,
                                  members: members,
                                  conversationName: nameSnapshot.data!,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _getConversationName(
    String conversationId,
    bool isGroup,
    List<String> members,
  ) async {
    try {
      if (isGroup) {
        final doc =
            await _firestore
                .collection('conversations')
                .doc(conversationId)
                .get();
        final data = doc.data();
        return data?['groupName'] as String? ?? 'Nhóm không tên';
      } else {
        final otherUserId = members.firstWhere(
          (id) => id != _auth.currentUser!.uid,
          orElse: () => '',
        );
        if (otherUserId.isEmpty) return 'Hội thoại không hợp lệ';
        final userDoc =
            await _firestore.collection('users').doc(otherUserId).get();
        final userData = userDoc.data();
        return userData?['name'] as String? ?? 'Ẩn danh';
      }
    } catch (e) {
      return 'Lỗi tải tên';
    }
  }

  Future<String> _getAvatarUrl(
    List<String> members,
    String currentUserId,
  ) async {
    try {
      final otherUserId = members.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      if (otherUserId.isEmpty) return 'https://via.placeholder.com/150';
      final userDoc =
          await _firestore.collection('users').doc(otherUserId).get();
      return userDoc.data()?['photoUrl'] as String? ??
          'https://via.placeholder.com/150';
    } catch (e) {
      return 'https://via.placeholder.com/150';
    }
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _selectedFriends = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _selectedAvatar = 'assets/messages/default_avatar.png';
  String _selectedBackground = 'assets/messages/default_background.png';

  // List of available images in assets/messages/
  final List<String> _availableAvatars = [
    'assets/messages/avatar1.png',
    'assets/messages/avatar2.png',
    'assets/messages/default_avatar.png',
  ];
  final List<String> _availableBackgrounds = [
    'assets/messages/background1.png',
    'assets/messages/background2.png',
    'assets/messages/default_background.png',
  ];

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Lỗi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: const Text(
          'Vui lòng đăng nhập',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Tạo nhóm chat',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Tên nhóm',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF63AB83)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn ảnh đại diện:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableAvatars.length,
                  itemBuilder: (context, index) {
                    final avatar = _availableAvatars[index];
                    return GestureDetector(
                      onTap:
                          _isLoading
                              ? null
                              : () => setState(() => _selectedAvatar = avatar),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: AssetImage(avatar),
                          onBackgroundImageError:
                              (_, __) =>
                                  const Icon(LineIcons.exclamationCircle),
                          child:
                              _selectedAvatar == avatar
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF63AB83),
                                  )
                                  : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn ảnh nền:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableBackgrounds.length,
                  itemBuilder: (context, index) {
                    final background = _availableBackgrounds[index];
                    return GestureDetector(
                      onTap:
                          _isLoading
                              ? null
                              : () => setState(
                                () => _selectedBackground = background,
                              ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(background),
                              fit: BoxFit.cover,
                              onError:
                                  (_, __) =>
                                      const Icon(LineIcons.exclamationCircle),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                _selectedBackground == background
                                    ? Border.all(
                                      color: const Color(0xFF63AB83),
                                      width: 2,
                                    )
                                    : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chọn bạn bè:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('friends')
                          .doc(currentUserId)
                          .collection('friendships')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _buildErrorMessage(
                        'Lỗi khi tải danh sách bạn bè. Vui lòng thử lại.',
                      );
                    }
                    final friends = snapshot.data?.docs ?? [];
                    if (friends.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Bạn chưa có bạn bè nào để thêm vào nhóm',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friendId = friends[index].id;
                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              _firestore
                                  .collection('users')
                                  .doc(friendId)
                                  .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                title: Text('Đang tải...'),
                                leading: CircularProgressIndicator(),
                              );
                            }
                            if (userSnapshot.hasError) {
                              return const ListTile(
                                title: Text('Lỗi tải thông tin'),
                              );
                            }
                            if (!userSnapshot.hasData ||
                                !userSnapshot.data!.exists) {
                              return const ListTile(
                                title: Text('Người dùng không tồn tại'),
                              );
                            }
                            final userData =
                                userSnapshot.data!.data()
                                    as Map<String, dynamic>? ??
                                {};
                            final photoUrl =
                                userData['photoUrl'] as String? ??
                                'https://via.placeholder.com/150';
                            final name =
                                userData['name'] as String? ?? 'Ẩn danh';
                            return CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              secondary: CircleAvatar(
                                radius: 20,
                                backgroundImage: CachedNetworkImageProvider(
                                  photoUrl,
                                ),
                                onBackgroundImageError:
                                    (_, __) =>
                                        const Icon(LineIcons.exclamationCircle),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.black87),
                              ),
                              value: _selectedFriends.contains(friendId),
                              onChanged:
                                  _isLoading
                                      ? null
                                      : (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            _selectedFriends.add(friendId);
                                          } else {
                                            _selectedFriends.remove(friendId);
                                          }
                                        });
                                      },
                              activeColor: const Color(0xFF63AB83),
                              checkColor: Colors.white,
                              enabled: !_isLoading,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF63AB83),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text('Tạo', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty || _selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên nhóm và chọn ít nhất một bạn'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final currentUserId = _auth.currentUser!.uid;
    final members = [currentUserId, ..._selectedFriends];
    try {
      final docRef = await _firestore.collection('conversations').add({
        'type': 'group',
        'members': members,
        'groupName': _groupNameController.text.trim(),
        'lastMessage': '',
        'lastMessageTime': null,
        'admins': [currentUserId], // Set creator as admin
        'avatarUrl': _selectedAvatar,
        'backgroundUrl': _selectedBackground,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo nhóm thành công!'),
          backgroundColor: Color(0xFF63AB83),
        ),
      );
      Navigator.pop(context);
      // Navigate to the newly created group chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChatScreen(
                conversationId: docRef.id,
                isGroup: true,
                members: members,
                conversationName: _groupNameController.text.trim(),
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo nhóm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildErrorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

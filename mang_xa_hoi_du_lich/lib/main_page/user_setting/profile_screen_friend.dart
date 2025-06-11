import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/edit_post_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/friend_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/notification_service.dart';

class ProfileFriend extends StatefulWidget {
  final String userId;

  const ProfileFriend({super.key, required this.userId});

  @override
  _ProfileFriendState createState() => _ProfileFriendState();
}

class _ProfileFriendState extends State<ProfileFriend> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _friendStatus;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _checkFriendStatus();
  }

  Future<void> _fetchUserData() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();
      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu người dùng: $e')),
      );
    }
  }

  Future<void> _checkFriendStatus() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId == widget.userId) {
      setState(() {
        _friendStatus = null; // Không hiển thị nút nếu là chính mình
      });
      return;
    }

    try {
      // Kiểm tra xem đã là bạn bè chưa
      final friendDoc =
          await _firestore
              .collection('friends')
              .doc(currentUserId)
              .collection('friendships')
              .doc(widget.userId)
              .get();
      if (friendDoc.exists) {
        setState(() {
          _friendStatus = 'friends';
        });
        return;
      }

      // Kiểm tra yêu cầu kết bạn đã gửi hoặc nhận
      final requestsSnapshot =
          await _firestore
              .collection('friend_requests')
              .where('status', isEqualTo: 'pending')
              .where('fromUserId', isEqualTo: currentUserId)
              .where('toUserId', isEqualTo: widget.userId)
              .get();

      if (requestsSnapshot.docs.isNotEmpty) {
        setState(() {
          _friendStatus = 'request_sent';
        });
        return;
      }

      final receivedSnapshot =
          await _firestore
              .collection('friend_requests')
              .where('status', isEqualTo: 'pending')
              .where('fromUserId', isEqualTo: widget.userId)
              .where('toUserId', isEqualTo: currentUserId)
              .get();

      if (receivedSnapshot.docs.isNotEmpty) {
        setState(() {
          _friendStatus = 'request_received';
        });
        return;
      }

      // Nếu không có yêu cầu kết bạn hoặc bạn bè, mặc định là not_friends
      setState(() {
        _friendStatus = 'not_friends';
      });
    } catch (e) {
      setState(() {
        _friendStatus = 'not_friends'; // Mặc định not_friends nếu có lỗi
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi kiểm tra trạng thái bạn bè: $e')),
      );
    }
  }

  Future<void> _sendFriendRequest() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('friend_requests').add({
        'fromUserId': currentUserId,
        'toUserId': widget.userId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _friendStatus = 'request_sent';
      });

      // Get current user's name for the notification
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Người dùng';

      // Send notification to the recipient
      await NotificationService.sendChatEventNotification(
        userId: widget.userId,
        title: 'Lời mời kết bạn mới',
        message: '$currentUserName đã gửi cho bạn lời mời kết bạn',
        type: 'friend_request',
        conversationId: null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi yêu cầu kết bạn!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gửi yêu cầu kết bạn: $e')),
      );
    }
  }

  Future<void> _cancelFriendRequest() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final requestDocs =
          await _firestore
              .collection('friend_requests')
              .where('fromUserId', isEqualTo: currentUserId)
              .where('toUserId', isEqualTo: widget.userId)
              .where('status', isEqualTo: 'pending')
              .get();
      for (var doc in requestDocs.docs) {
        await doc.reference.delete();
      }
      setState(() {
        _friendStatus = 'not_friends';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy yêu cầu kết bạn!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi hủy yêu cầu kết bạn: $e')),
      );
    }
  }

  Future<void> _unfriend() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('friends')
          .doc(currentUserId)
          .collection('friendships')
          .doc(widget.userId)
          .delete();
      await _firestore
          .collection('friends')
          .doc(widget.userId)
          .collection('friendships')
          .doc(currentUserId)
          .delete();
      setState(() {
        _friendStatus = 'not_friends';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy kết bạn!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi hủy kết bạn: $e')));
    }
  }

  Widget _buildFriendButton() {
    if (_friendStatus == null) return const SizedBox.shrink();

    switch (_friendStatus) {
      case 'not_friends':
        return ElevatedButton.icon(
          onPressed: _sendFriendRequest,
          icon: const Icon(Icons.person_add, size: 20, color: Colors.white),
          label: const Text(
            'Thêm bạn bè',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF63AB83),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      case 'request_sent':
        return OutlinedButton.icon(
          onPressed: _cancelFriendRequest,
          icon: const Icon(Icons.cancel, size: 20, color: Colors.redAccent),
          label: const Text(
            'Hủy yêu cầu',
            style: TextStyle(color: Colors.redAccent),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      case 'request_received':
        return TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendScreen()),
            );
          },
          child: const Text(
            'Xem yêu cầu kết bạn',
            style: TextStyle(color: Color(0xFF63AB83)),
          ),
        );
      case 'friends':
        return OutlinedButton.icon(
          onPressed: _unfriend,
          icon: const Icon(
            Icons.person_remove,
            size: 20,
            color: Colors.redAccent,
          ),
          label: const Text(
            'Hủy kết bạn',
            style: TextStyle(color: Colors.redAccent),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        backgroundColor: const Color(0xFF63AB83),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userData == null
              ? const Center(child: Text('Không tìm thấy người dùng'))
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF63AB83),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(
                                _userData!['photoUrl'] ??
                                    'https://via.placeholder.com/150',
                              ),
                              radius: 50,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _userData!['name'] ?? 'Ẩn danh',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userData!['email'] ?? 'Không có email',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFriendButton(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Bài viết của ${_userData!['name'] ?? 'người dùng'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          _firestore
                              .collection('posts')
                              .where('userId', isEqualTo: widget.userId)
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final posts = snapshot.data!.docs;
                        if (posts.isEmpty) {
                          return const Center(
                            child: Text('Chưa có bài viết nào'),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            final data = post.data() as Map<String, dynamic>;
                            final timestamp =
                                (data['timestamp'] as Timestamp?)?.toDate();
                            final formattedDate =
                                timestamp != null
                                    ? DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(timestamp)
                                    : 'N/A';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        _userData!['photoUrl'] ??
                                            'https://via.placeholder.com/150',
                                      ),
                                      radius: 24,
                                    ),
                                    title: Text(
                                      _userData!['name'] ?? 'Ẩn danh',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      formattedDate,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    trailing:
                                        _auth.currentUser?.uid == widget.userId
                                            ? IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) => EditPostPage(
                                                          post: post,
                                                        ),
                                                  ),
                                                );
                                              },
                                            )
                                            : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    child: Text(
                                      data['title'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 4.0,
                                    ),
                                    child: Text(
                                      data['content'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if ((data['imageUrl'] as String?)
                                          ?.isNotEmpty ??
                                      false)
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          data['imageUrl'] as String,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
    );
  }
}

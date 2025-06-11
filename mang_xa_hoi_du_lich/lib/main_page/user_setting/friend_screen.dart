import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/profile_screen_friend.dart';
import 'package:mang_xa_hoi_du_lich/main_page/notification_service.dart';

class FriendScreen extends StatefulWidget {
  const FriendScreen({super.key});

  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _acceptFriendRequest(String requestId, String fromUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Cập nhật trạng thái yêu cầu
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'accepted',
      });

      // Thêm vào danh sách bạn bè của cả hai
      await _firestore
          .collection('friends')
          .doc(currentUserId)
          .collection('friendships')
          .doc(fromUserId)
          .set({
            'friendId': fromUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });
      await _firestore
          .collection('friends')
          .doc(fromUserId)
          .collection('friendships')
          .doc(currentUserId)
          .set({
            'friendId': currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Get current user's name for the notification
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Người dùng';

      // Send notification to the user who sent the request
      await NotificationService.sendChatEventNotification(
        userId: fromUserId,
        title: 'Lời mời kết bạn được chấp nhận',
        message: '$currentUserName đã chấp nhận lời mời kết bạn của bạn',
        type: 'friend_request_accepted',
        conversationId: null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã chấp nhận kết bạn!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi chấp nhận kết bạn: $e')));
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã từ chối yêu cầu kết bạn!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi từ chối yêu cầu: $e')));
    }
  }

  Future<void> _unfriend(String friendId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('friends')
          .doc(currentUserId)
          .collection('friendships')
          .doc(friendId)
          .delete();
      await _firestore
          .collection('friends')
          .doc(friendId)
          .collection('friendships')
          .doc(currentUserId)
          .delete();
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text('Vui lòng đăng nhập')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bạn bè'),
          backgroundColor: const Color(0xFF63AB83),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Yêu cầu kết bạn'), Tab(text: 'Bạn bè')],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab Yêu cầu kết bạn
            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('friend_requests')
                      .where('toUserId', isEqualTo: currentUserId)
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Lỗi khi tải yêu cầu kết bạn'),
                  );
                }
                final requests = snapshot.data?.docs ?? [];
                if (requests.isEmpty) {
                  return const Center(
                    child: Text('Không có yêu cầu kết bạn nào'),
                  );
                }

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final data = request.data() as Map<String, dynamic>;
                    final fromUserId = data['fromUserId'] as String;

                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          _firestore.collection('users').doc(fromUserId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(title: Text('Đang tải...'));
                        }
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;
                        final userName = userData?['name'] ?? 'Ẩn danh';
                        final userPhotoUrl =
                            userData?['photoUrl'] ??
                            'https://via.placeholder.com/150';

                        return ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ProfileFriend(userId: fromUserId),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(userPhotoUrl),
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ProfileFriend(userId: fromUserId),
                                ),
                              );
                            },
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    () => _acceptFriendRequest(
                                      request.id,
                                      fromUserId,
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF63AB83),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Đồng ý',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              OutlinedButton(
                                onPressed:
                                    () => _rejectFriendRequest(request.id),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Từ chối',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            // Tab Bạn bè
            StreamBuilder<QuerySnapshot>(
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
                  return const Center(
                    child: Text('Lỗi khi tải danh sách bạn bè'),
                  );
                }
                final friends = snapshot.data?.docs ?? [];
                if (friends.isEmpty) {
                  return const Center(child: Text('Chưa có bạn bè nào'));
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final friendId = friend['friendId'] as String;

                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          _firestore.collection('users').doc(friendId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(title: Text('Đang tải...'));
                        }
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;
                        final userName = userData?['name'] ?? 'Ẩn danh';
                        final userPhotoUrl =
                            userData?['photoUrl'] ??
                            'https://via.placeholder.com/150';

                        return ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ProfileFriend(userId: friendId),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(userPhotoUrl),
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ProfileFriend(userId: friendId),
                                ),
                              );
                            },
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => _unfriend(friendId),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Hủy kết bạn',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        );
                      },
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

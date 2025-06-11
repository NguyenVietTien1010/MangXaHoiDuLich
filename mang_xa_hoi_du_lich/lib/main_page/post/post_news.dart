import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:mang_xa_hoi_du_lich/main_page/notification_service.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/edit_post_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/expandable_content.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/profile_screen_friend.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PostNews extends StatefulWidget {
  final String? selectedTravelType;

  const PostNews({super.key, this.selectedTravelType});

  @override
  _PostNewsState createState() => _PostNewsState();
}

class _PostNewsState extends State<PostNews> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _rating = 1.0;
  Map<String, int> _ratingCounts = {};
  Map<String, double> _averageRatings = {};
  Map<String, double> _userRatings = {};
  Map<String, List<Map<String, dynamic>>> _ratingsDetail = {};
  String? _replyToCommentId;
  Map<String, bool> _showComments = {};
  Map<String, bool> _expandedContent = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [];
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _commentKeys = {};

  @override
  void initState() {
    super.initState();
    _preloadRatings();
    _loadNotifications();
  }

  Future<void> _preloadRatings() async {
    final postsSnapshot = await _firestore.collection('posts').get();
    for (var post in postsSnapshot.docs) {
      await _fetchRatings(post.id);
    }
  }

  Future<void> _fetchRatings(String postId) async {
    final ratingsSnapshot =
        await _firestore
            .collection('posts')
            .doc(postId)
            .collection('ratings')
            .get();

    final currentUserId = _auth.currentUser?.uid;

    if (ratingsSnapshot.docs.isNotEmpty) {
      final ratings =
          ratingsSnapshot.docs
              .map((doc) => (doc['rating'] as num).toDouble())
              .toList();

      QueryDocumentSnapshot? userRatingDoc;
      for (var doc in ratingsSnapshot.docs) {
        if (doc['userId'] == currentUserId) {
          userRatingDoc = doc;
          break;
        }
      }

      final ratingsDetailsList =
          ratingsSnapshot.docs.map((doc) {
            return {
              'userId': doc['userId'],
              'rating': (doc['rating'] as num).toDouble(),
            };
          }).toList();

      setState(() {
        _ratingCounts[postId] = ratings.length;
        _averageRatings[postId] =
            ratings.reduce((a, b) => a + b) / ratings.length;
        _userRatings[postId] =
            userRatingDoc != null
                ? (userRatingDoc['rating'] as num).toDouble()
                : 0.0;
        _ratingsDetail[postId] = ratingsDetailsList;
      });
    } else {
      setState(() {
        _ratingCounts[postId] = 0;
        _averageRatings[postId] = 0.0;
        _userRatings[postId] = 0.0;
        _ratingsDetail[postId] = [];
      });
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String postId,
    required String fromUserId,
  }) async {
    try {
      await NotificationService.sendChatEventNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        conversationId: postId,
      );

      // Save notification to Firestore
      final notificationRef = await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type,
        'message': message,
        'postId': postId,
        'fromUserId': fromUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'title': title,
      });

      // Update local notifications list
      setState(() {
        _notifications.insert(0, {
          'id': notificationRef.id,
          'userId': userId,
          'type': type,
          'message': message,
          'postId': postId,
          'fromUserId': fromUserId,
          'timestamp': Timestamp.now(),
          'isRead': false,
          'title': title,
        });
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  void _showRatingDialog(String postId) async {
    final userRating = _userRatings[postId] ?? 1.0;
    setState(() {
      _rating = userRating;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Đánh giá',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: false,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder:
                        (context, _) =>
                            const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (rating) {
                      setDialogState(() {
                        _rating = rating;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildEmoji(
                        1,
                        Icons.sentiment_very_dissatisfied,
                        setDialogState,
                      ),
                      _buildEmoji(
                        2,
                        Icons.sentiment_dissatisfied,
                        setDialogState,
                      ),
                      _buildEmoji(3, Icons.sentiment_neutral, setDialogState),
                      _buildEmoji(4, Icons.sentiment_satisfied, setDialogState),
                      _buildEmoji(
                        5,
                        Icons.sentiment_very_satisfied,
                        setDialogState,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final currentUser = _auth.currentUser;
                if (currentUser != null) {
                  final ratingRef = _firestore
                      .collection('posts')
                      .doc(postId)
                      .collection('ratings')
                      .where('userId', isEqualTo: currentUser.uid);

                  final existing = await ratingRef.get();

                  if (existing.docs.isNotEmpty) {
                    await existing.docs.first.reference.update({
                      'rating': _rating,
                    });
                  } else {
                    await _firestore
                        .collection('posts')
                        .doc(postId)
                        .collection('ratings')
                        .add({
                          'userId': currentUser.uid,
                          'rating': _rating,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                  }

                  // Get post owner's ID
                  final postDoc =
                      await _firestore.collection('posts').doc(postId).get();
                  final postOwnerId = postDoc.data()?['userId'] as String?;

                  if (postOwnerId != null && postOwnerId != currentUser.uid) {
                    await NotificationService.sendChatEventNotification(
                      userId: postOwnerId,
                      title: 'Đánh giá mới bài viết',
                      message:
                          'Có người đã đánh giá bài viết của bạn $_rating sao',
                      type: 'rating',
                      conversationId: null, // Không phải chat nhóm, để null
                    );
                  }

                  await _fetchRatings(postId);
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Gửi',
                style: TextStyle(color: Color(0xFF63AB83)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRatingsDetailDialog(String postId) {
    final ratingsList = _ratingsDetail[postId] ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Danh sách đánh giá',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child:
                ratingsList.isEmpty
                    ? const Text('Chưa có đánh giá nào')
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: ratingsList.length,
                      itemBuilder: (context, index) {
                        final item = ratingsList[index];
                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              _firestore
                                  .collection('users')
                                  .doc(item['userId'])
                                  .get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const ListTile(title: Text('Đang tải...'));
                            }
                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            final userName = userData?['name'] ?? 'Người dùng';
                            return ListTile(
                              leading: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => ProfileFriend(
                                            userId: item['userId'],
                                          ),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    userData?['photoUrl'] ??
                                        'https://via.placeholder.com/150',
                                  ),
                                ),
                              ),
                              title: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => ProfileFriend(
                                            userId: item['userId'],
                                          ),
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(item['rating'].toString()),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(color: Color(0xFF63AB83)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPostOptions(
    BuildContext parentContext,
    String postId,
    String userId,
  ) {
    if (_auth.currentUser?.uid != userId) return;

    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF63AB83)),
                title: const Text('Chỉnh sửa bài viết'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  final docSnapshot =
                      await _firestore.collection('posts').doc(postId).get();

                  if (docSnapshot.exists) {
                    Navigator.push(
                      parentContext,
                      MaterialPageRoute(
                        builder: (_) => EditPostPage(post: docSnapshot),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Xóa bài viết',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(modalContext);

                  final confirm = await showDialog<bool>(
                    context: parentContext,
                    builder:
                        (dialogContext) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Xác nhận xóa'),
                          content: const Text(
                            'Bạn có chắc chắn muốn xóa bài viết này? Hành động này không thể hoàn tác.',
                          ),
                          actions: [
                            TextButton(
                              child: const Text(
                                'Hủy',
                                style: TextStyle(color: Colors.grey),
                              ),
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                            ),
                            TextButton(
                              child: const Text(
                                'Xóa',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                            ),
                          ],
                        ),
                  );

                  if (confirm != true) return;

                  showDialog(
                    context: parentContext,
                    barrierDismissible: false,
                    builder: (_) => const CustomLoadingDialog(),
                  );

                  try {
                    final docSnapshot =
                        await _firestore.collection('posts').doc(postId).get();

                    if (!docSnapshot.exists) {
                      Navigator.of(parentContext).pop();
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Bài viết không tồn tại.'),
                        ),
                      );
                      return;
                    }

                    final data = docSnapshot.data() as Map<String, dynamic>;

                    if (data['imageUrl'] != null &&
                        (data['imageUrl'] as String).isNotEmpty) {
                      try {
                        final imageUrl = data['imageUrl'] as String;
                        final ref = FirebaseStorage.instance.refFromURL(
                          imageUrl,
                        );
                        await ref.delete();
                      } catch (e) {
                        print('Error deleting image: $e');
                      }
                    }

                    final ratingsSnapshot =
                        await _firestore
                            .collection('posts')
                            .doc(postId)
                            .collection('ratings')
                            .get();
                    for (var doc in ratingsSnapshot.docs) {
                      await doc.reference.delete();
                    }

                    await _firestore.collection('posts').doc(postId).delete();

                    Navigator.of(parentContext).pop();
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Xóa bài viết thành công!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    Navigator.of(parentContext).pop();
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Lỗi khi xóa bài viết: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Hủy'),
                onTap: () => Navigator.pop(modalContext),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmoji(int value, IconData icon, StateSetter setDialogState) {
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          _rating = value.toDouble();
        });
      },
      child: Icon(
        icon,
        color: _rating.round() == value ? const Color(0xFF63AB83) : Colors.grey,
        size: 32,
      ),
    );
  }

  void _launchGoogleMaps(String location) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể mở Google Maps')));
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Lỗi khi lấy dữ liệu người dùng: $e');
      return null;
    }
  }

  Future<String?> _getUserIdFromComment(String postId, String commentId) async {
    try {
      DocumentSnapshot commentDoc =
          await _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(commentId)
              .get();
      if (commentDoc.exists) {
        final data = commentDoc.data();
        if (data is Map<String, dynamic>) {
          return data['userId'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('Lỗi khi lấy userId từ comment: $e');
      return null;
    }
  }

  Future<void> _deleteCommentAndReplies(String postId, String commentId) async {
    try {
      QuerySnapshot subComments =
          await _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .where('parentId', isEqualTo: commentId)
              .get();

      for (var doc in subComments.docs) {
        await _deleteCommentAndReplies(postId, doc.id);
      }

      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa bình luận: $e')));
    }
  }

  void _scrollToComment(String commentId) {
    final context = _commentKeys[commentId]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  Future<void> _addComment(String postId, String content) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userData = await _getUserData(user.uid);
      if (userData == null) return;

      String? replyUserName;
      String? replyUserId;
      if (_replyToCommentId != null) {
        replyUserId = await _getUserIdFromComment(postId, _replyToCommentId!);
        final replyUserData =
            replyUserId != null ? await _getUserData(replyUserId) : null;
        replyUserName =
            replyUserData != null
                ? (replyUserData['name'] as String?) ?? 'Ẩn danh'
                : 'Ẩn danh';
      }

      // Add the comment
      final commentRef = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add({
            'userId': user.uid,
            'userName': userData['name'] ?? 'Ẩn danh',
            'userAvatar':
                userData['photoUrl'] ?? 'https://via.placeholder.com/150',
            'content':
                _replyToCommentId != null
                    ? '@$replyUserName $content'
                    : content,
            'createdAt': Timestamp.now(),
            'parentId': _replyToCommentId,
          });

      // Get post owner's ID and send notification
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postOwnerId = postDoc.data()?['userId'] as String?;
      final currentUserName = userData['name'] ?? 'Người dùng';

      if (postOwnerId != null && postOwnerId != user.uid) {
        await sendNotification(
          userId: postOwnerId,
          title: 'Bình luận mới',
          message: '$currentUserName đã bình luận về bài viết của bạn',
          type: 'comment',
          postId: postId,
          fromUserId: user.uid,
        );
      }

      if (_replyToCommentId != null &&
          replyUserId != null &&
          replyUserId != user.uid) {
        await sendNotification(
          userId: replyUserId,
          title: 'Trả lời bình luận',
          message: '$currentUserName đã trả lời bình luận của bạn',
          type: 'reply_comment',
          postId: postId,
          fromUserId: user.uid,
        );
      }

      setState(() {
        _commentController.clear();
        _replyToCommentId = null;
      });

      // Add a small delay before scrolling to the new comment
      await Future.delayed(const Duration(milliseconds: 500));
      _scrollToComment(commentRef.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bình luận đã được thêm thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi thêm bình luận: $e')));
    }
  }

  Widget _buildCommentInput(String postId) {
    final user = _auth.currentUser;

    return FutureBuilder<Map<String, dynamic>?>(
      future: user != null ? _getUserData(user.uid) : Future.value(null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Lỗi khi tải thông tin người dùng');
        }

        final userData = snapshot.data ?? {};
        String userName = (userData['name'] as String?) ?? 'Ẩn danh';
        String userAvatar =
            (userData['photoUrl'] as String?) ??
            'https://via.placeholder.com/150';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_replyToCommentId != null)
                FutureBuilder<String?>(
                  future: _getUserIdFromComment(postId, _replyToCommentId!),
                  builder: (context, userIdSnapshot) {
                    if (userIdSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text('Đang tải...'),
                      );
                    }
                    if (userIdSnapshot.hasError || !userIdSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text('Đang trả lời @Ẩn danh...'),
                      );
                    }
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getUserData(userIdSnapshot.data!),
                      builder: (context, replySnapshot) {
                        if (replySnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text('Đang tải...'),
                          );
                        }
                        if (replySnapshot.hasError || !replySnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text('Đang trả lời @Ẩn danh...'),
                          );
                        }
                        final replyUserData = replySnapshot.data ?? {};
                        String replyUserName =
                            (replyUserData['name'] as String?) ?? 'Ẩn danh';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Đang trả lời @$replyUserName...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _replyToCommentId = null;
                                    _commentController.clear();
                                  });
                                },
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileFriend(userId: user.uid),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(userAvatar),
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (user != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ProfileFriend(userId: user.uid),
                                ),
                              );
                            }
                          },
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF63AB83),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Viết bình luận...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                _addComment(postId, value.trim());
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF63AB83),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        size: 20,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_commentController.text.trim().isNotEmpty) {
                          _addComment(postId, _commentController.text.trim());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComments(String postId, String? parentId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .orderBy('createdAt', descending: false)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox(
            height: 40,
            child: Center(child: Text('Lỗi khi tải bình luận')),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(
            height: 40,
            child: Center(child: Text('Chưa có bình luận')),
          );
        }

        final comments =
            snapshot.data!.docs
                .where(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>?)?['parentId'] ==
                      parentId,
                )
                .toList();

        const baseIndent = 12.0;
        double indent = parentId != null ? baseIndent + 8.0 : baseIndent;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              comments.map((doc) {
                final commentId = doc.id;
                _commentKeys[commentId] = GlobalKey();

                final data = doc.data();
                if (data is! Map<String, dynamic>) {
                  return const SizedBox.shrink();
                }
                final isCurrentUser =
                    _auth.currentUser?.uid == (data['userId'] as String?);

                return Column(
                  key: _commentKeys[commentId],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parentId != null)
                      Container(
                        margin: const EdgeInsets.only(left: 20.0, bottom: 4.0),
                        child: CustomPaint(
                          painter: CommentLinePainter(),
                          child: const SizedBox(height: 10, width: 2),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: indent.clamp(
                          0.0,
                          MediaQuery.of(context).size.width * 0.8 - 100.0,
                        ),
                        right: 12.0,
                        top: 8.0,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.85,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                parentId != null
                                    ? Colors.grey[50]
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border:
                                parentId != null
                                    ? const Border(
                                      left: BorderSide(
                                        color: Color(0xFF63AB83),
                                        width: 2,
                                      ),
                                    )
                                    : null,
                          ),
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => ProfileFriend(
                                                userId: data['userId'],
                                              ),
                                        ),
                                      );
                                    },
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        (data['userAvatar'] as String?) ??
                                            'https://via.placeholder.com/150',
                                      ),
                                      radius: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) => ProfileFriend(
                                                          userId:
                                                              data['userId'],
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                (data['userName'] as String?) ??
                                                    'Ẩn danh',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (isCurrentUser)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Colors.redAccent,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder:
                                                        (
                                                          context,
                                                        ) => AlertDialog(
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                          ),
                                                          title: const Text(
                                                            'Xác nhận xóa',
                                                          ),
                                                          content: const Text(
                                                            'Bạn có chắc chắn muốn xóa bình luận này?',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed:
                                                                  () =>
                                                                      Navigator.pop(
                                                                        context,
                                                                      ),
                                                              child: const Text(
                                                                'Hủy',
                                                                style: TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .grey,
                                                                ),
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () async {
                                                                await _deleteCommentAndReplies(
                                                                  postId,
                                                                  commentId,
                                                                );
                                                                Navigator.pop(
                                                                  context,
                                                                );
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      'Bình luận đã được xóa!',
                                                                    ),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .green,
                                                                    duration:
                                                                        Duration(
                                                                          seconds:
                                                                              2,
                                                                        ),
                                                                  ),
                                                                );
                                                              },
                                                              child: const Text(
                                                                'Xóa',
                                                                style: TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          (data['content'] as String?) ?? '',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _replyToCommentId = commentId;
                                      });
                                    },
                                    child: const Text(
                                      'Trả lời',
                                      style: TextStyle(
                                        color: Color(0xFF63AB83),
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.grey[100],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(
                                      (data['createdAt'] as Timestamp).toDate(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildComments(postId, commentId),
                  ],
                );
              }).toList(),
        );
      },
    );
  }

  Future<void> _addToFavorites(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final existingFavorite =
          await _firestore
              .collection('favorites')
              .where('userId', isEqualTo: userId)
              .where('postId', isEqualTo: postId)
              .get();

      if (existingFavorite.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bài viết đã có trong danh sách yêu thích'),
            ),
          );
        }
        return;
      }

      await _firestore.collection('favorites').add({
        'userId': userId,
        'postId': postId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postOwnerId = postDoc.data()?['userId'] as String?;

      if (postOwnerId != null && postOwnerId != userId) {
        final currentUserDoc =
            await _firestore.collection('users').doc(userId).get();
        final currentUserName =
            currentUserDoc.data()?['name'] as String? ?? 'Người dùng';

        await NotificationService.sendChatEventNotification(
          userId: postOwnerId,
          title: 'Bài viết được yêu thích',
          message:
              '$currentUserName đã thêm bài viết của bạn vào danh sách yêu thích',
          type: 'favorite',
          conversationId: null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm vào danh sách yêu thích'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thêm vào yêu thích: $e')),
        );
      }
    }
  }

  Future<void> _removeFromFavorites(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final favorites =
          await _firestore
              .collection('favorites')
              .where('userId', isEqualTo: userId)
              .where('postId', isEqualTo: postId)
              .get();

      for (var doc in favorites.docs) {
        await doc.reference.delete();
      }

      // Thông báo cho chủ bài viết (tùy chọn)
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postOwnerId = postDoc.data()?['userId'] as String?;

      if (postOwnerId != null && postOwnerId != userId) {
        final currentUserDoc =
            await _firestore.collection('users').doc(userId).get();
        final currentUserName =
            currentUserDoc.data()?['name'] as String? ?? 'Người dùng';

        await NotificationService.sendChatEventNotification(
          userId: postOwnerId,
          title: 'Bài viết bị xóa khỏi yêu thích',
          message:
              '$currentUserName đã xóa bài viết của bạn khỏi danh sách yêu thích',
          type: 'unfavorite',
          conversationId: null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa khỏi danh sách yêu thích'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa khỏi yêu thích: $e')),
        );
      }
    }
  }

  Future<bool> _isPostFavorited(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    final favorites =
        await _firestore
            .collection('favorites')
            .where('userId', isEqualTo: userId)
            .where('postId', isEqualTo: postId)
            .get();

    return favorites.docs.isNotEmpty;
  }

  // Hàm tải notifications được cải thiện để đảm bảo đồng bộ và thông báo lỗi
  Future<void> _loadNotifications() async {
    if (_auth.currentUser == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _notifications =
            []; // Xóa danh sách cũ để tránh hiển thị dữ liệu không đồng bộ
      });
    }

    try {
      final querySnapshot =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: _auth.currentUser!.uid)
              .orderBy('timestamp', descending: true)
              .get();

      if (mounted) {
        setState(() {
          _notifications =
              querySnapshot.docs
                  .map(
                    (doc) => {
                      ...doc.data() as Map<String, dynamic>,
                      'id': doc.id,
                    },
                  )
                  .toList();
          _isLoading = false;
        });
      }

      // Hiển thị thông báo thành công khi tải xong
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Danh sách thông báo đã được làm mới'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải thông báo: $e')));
      }
    }
  }

  // Hàm đánh dấu đã đọc, cập nhật danh sách cục bộ để đảm bảo đồng bộ
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });

      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n['id'] == notificationId,
          );
          if (index != -1) {
            _notifications[index]['isRead'] = true;
          }
        });
      }
    } catch (e) {
      print('Error marking notification as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi đánh dấu đã đọc: $e')));
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (_auth.currentUser == null) return;

    try {
      final querySnapshot =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: _auth.currentUser!.uid)
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (mounted) {
        setState(() {
          for (var notification in _notifications) {
            notification['isRead'] = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đánh dấu tất cả đã đọc: $e')),
        );
      }
    }
  }

  // Hàm xóa notification, cập nhật danh sách cục bộ
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      if (mounted) {
        setState(() {
          _notifications.removeWhere(
            (notification) => notification['id'] == notificationId,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thông báo'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa thông báo: $e')));
      }
    }
  }

  // Hàm hiển thị dialog thông báo
  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => NotificationDialog(
            notifications: _notifications,
            onMarkAsRead: _markAsRead,
            onDelete: _deleteNotification,
            onMarkAllAsRead: _markAllAsRead,
            onRefresh: _loadNotifications,
            isLoading: _isLoading,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 50,
            right: 16,
            left: 16,
            bottom: 16,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF63AB83),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                widget.selectedTravelType != null
                    ? 'Chạm\nLà Chạy - ${widget.selectedTravelType}'
                    : 'Chạm\nLà Chạy',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _showNotificationDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                widget.selectedTravelType != null
                    ? _firestore
                        .collection('posts')
                        .where(
                          'travelType',
                          isEqualTo: widget.selectedTravelType,
                        )
                        .orderBy('timestamp', descending: true)
                        .snapshots()
                    : _firestore
                        .collection('posts')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snapshot.data!.docs;
              if (posts.isEmpty) {
                return const Center(child: Text('Không có bài viết nào'));
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final postId = post.id;
                  final data = post.data();
                  if (data is! Map<String, dynamic>) {
                    return const SizedBox.shrink();
                  }
                  final userId = data['userId'] as String?;
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                  final formattedDate =
                      timestamp != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
                          : 'N/A';

                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        userId != null
                            ? _firestore.collection('users').doc(userId).get()
                            : Future.value(null),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final userData =
                          userSnapshot.data?.data() as Map<String, dynamic>? ??
                          {};
                      final userName =
                          (userData['name'] as String?) ?? 'Người dùng';
                      final userPhotoUrl =
                          (userData['photoUrl'] as String?) ??
                          'https://via.placeholder.com/150';

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
                              leading: GestureDetector(
                                onTap: () {
                                  if (userId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                ProfileFriend(userId: userId),
                                      ),
                                    );
                                  }
                                },
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(userPhotoUrl),
                                  radius: 24,
                                ),
                              ),
                              title: GestureDetector(
                                onTap: () {
                                  if (userId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                ProfileFriend(userId: userId),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  GestureDetector(
                                    onTap:
                                        () => _launchGoogleMaps(
                                          data['location'] as String,
                                        ),
                                    child: Text(
                                      (data['location'] as String?) ??
                                          'Không xác định',
                                      style: const TextStyle(
                                        color: Color(0xFF63AB83),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '#${(data['travelType'] as String?) ?? 'DuLich'}',
                                    style: const TextStyle(
                                      color: Color(0xFF63AB83),
                                    ),
                                  ),
                                ],
                              ),
                              trailing:
                                  _auth.currentUser?.uid == userId
                                      ? IconButton(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Colors.grey,
                                        ),
                                        onPressed:
                                            () => _showPostOptions(
                                              context,
                                              postId,
                                              userId!,
                                            ),
                                      )
                                      : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Text(
                                (data['title'] as String?) ?? '',
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
                              child: ExpandableContent(
                                content: (data['content'] as String?) ?? '',
                                postId: postId,
                                expandedContent: _expandedContent,
                                onExpandChanged: (id, expanded) {
                                  setState(() {
                                    _expandedContent[id] = expanded;
                                  });
                                },
                              ),
                            ),
                            if ((data['imageUrl'] as String?)?.isNotEmpty ??
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
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        ),
                                        onPressed:
                                            () => _showRatingDialog(postId),
                                      ),
                                      GestureDetector(
                                        onTap:
                                            () => _showRatingsDetailDialog(
                                              postId,
                                            ),
                                        child: Text(
                                          '${_averageRatings[postId]?.toStringAsFixed(1) ?? "0.0"} (${_ratingCounts[postId] ?? 0})',
                                          style: const TextStyle(
                                            color: Color(0xFF63AB83),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StreamBuilder<QuerySnapshot>(
                                        stream:
                                            _firestore
                                                .collection('posts')
                                                .doc(postId)
                                                .collection('comments')
                                                .snapshots(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Text('Đang tải...');
                                          }
                                          final commentCount =
                                              snapshot.hasData
                                                  ? snapshot.data!.docs.length
                                                  : 0;
                                          return ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 150,
                                            ),
                                            child: TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _showComments[postId] =
                                                      !(_showComments[postId] ??
                                                          false);
                                                });
                                              },
                                              child: Text(
                                                (_showComments[postId] ?? false)
                                                    ? 'Ẩn ($commentCount)'
                                                    : 'Bình luận ($commentCount)',
                                                style: const TextStyle(
                                                  color: Color(0xFF63AB83),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      StreamBuilder<QuerySnapshot>(
                                        stream:
                                            _firestore
                                                .collection('favorites')
                                                .where(
                                                  'userId',
                                                  isEqualTo:
                                                      _auth.currentUser?.uid,
                                                )
                                                .where(
                                                  'postId',
                                                  isEqualTo: postId,
                                                )
                                                .snapshots(),
                                        builder: (context, snapshot) {
                                          final isFavorited =
                                              snapshot.hasData &&
                                              snapshot.data!.docs.isNotEmpty;
                                          return TextButton.icon(
                                            onPressed: () {
                                              if (isFavorited) {
                                                _removeFromFavorites(postId);
                                              } else {
                                                _addToFavorites(postId);
                                              }
                                            },
                                            icon: Icon(
                                              isFavorited
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color:
                                                  isFavorited
                                                      ? Colors.red
                                                      : const Color(0xFF63AB83),
                                            ),
                                            label: Text(
                                              isFavorited ? 'Đã lưu' : 'Lưu',
                                              style: TextStyle(
                                                color:
                                                    isFavorited
                                                        ? const Color.fromARGB(
                                                          255,
                                                          235,
                                                          84,
                                                          73,
                                                        )
                                                        : const Color(
                                                          0xFF63AB83,
                                                        ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  if (_showComments[postId] ?? false)
                                    Column(
                                      children: [
                                        _buildComments(postId, null),
                                        _buildCommentInput(postId),
                                      ],
                                    ),
                                ],
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
        ),
      ],
    );
  }
}

class CommentLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey[400]!
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CustomLoadingDialog extends StatefulWidget {
  const CustomLoadingDialog({super.key});

  @override
  _CustomLoadingDialogState createState() => _CustomLoadingDialogState();
}

class _CustomLoadingDialogState extends State<CustomLoadingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63AB83)),
              ),
              const SizedBox(height: 16),
              Text(
                'Đang xử lý...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationDialog extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final Function(String) onMarkAsRead;
  final Function(String) onDelete;
  final Function() onRefresh;
  final Function() onMarkAllAsRead; // Thêm callback mới
  final bool isLoading;

  const NotificationDialog({
    super.key,
    required this.notifications,
    required this.onMarkAsRead,
    required this.onDelete,
    required this.onRefresh,
    required this.onMarkAllAsRead,
    required this.isLoading,
  });

  // Hàm hiển thị dialog xác nhận
  void _showConfirmMarkAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Xác nhận',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Bạn có chắc chắn muốn đánh dấu tất cả thông báo là đã đọc?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onMarkAllAsRead();
                },
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(color: Color(0xFF63AB83)),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Color(0xFF63AB83),
                      size: 24,
                    ),
                    onPressed: isLoading ? null : onRefresh,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : notifications.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_none,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có thông báo mới',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: notifications.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final isRead =
                              notification['isRead'] as bool? ?? false;
                          final timestamp =
                              notification['timestamp'] as Timestamp?;

                          return Dismissible(
                            key: Key(notification['id']),
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => onDelete(notification['id']),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    isRead ? Colors.white : Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    !isRead
                                        ? Border.all(
                                          color: Color(0xFF63AB83),
                                          width: 1,
                                        )
                                        : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading:
                                    !isRead
                                        ? const Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: Color(0xFF63AB83),
                                        )
                                        : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                title: Text(
                                  notification['message'] ?? '',
                                  style: TextStyle(
                                    fontWeight:
                                        isRead
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle:
                                    timestamp != null
                                        ? Text(
                                          DateFormat(
                                            'dd/MM/yyyy HH:mm',
                                          ).format(timestamp.toDate()),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        )
                                        : null,
                                trailing:
                                    !isRead
                                        ? IconButton(
                                          icon: const Icon(
                                            Icons.mark_email_read,
                                            color: Color(0xFF63AB83),
                                            size: 20,
                                          ),
                                          onPressed:
                                              () => onMarkAsRead(
                                                notification['id'],
                                              ),
                                        )
                                        : null,
                                onTap: () {
                                  if (!isRead) {
                                    onMarkAsRead(notification['id']);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed:
                          notifications.any(
                                (n) => !(n['isRead'] as bool? ?? false),
                              )
                              ? () => _showConfirmMarkAllDialog(context)
                              : null, // Vô hiệu hóa nếu không có thông báo chưa đọc
                      child: const Text(
                        'Đọc tất cả',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF63AB83),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/expandable_content.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/edit_post_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/profile_screen_friend.dart';
import 'package:url_launcher/url_launcher.dart';

class MemoryPostsScreen extends StatefulWidget {
  const MemoryPostsScreen({super.key});

  @override
  _MemoryPostsScreenState createState() => _MemoryPostsScreenState();
}

class _MemoryPostsScreenState extends State<MemoryPostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, double> _averageRatings = {};
  Map<String, int> _ratingCounts = {};
  Map<String, bool> _expandedContent = {};
  Map<String, List<Map<String, dynamic>>> _ratingsDetail = {};
  Map<String, bool> _showComments = {};
  final Map<String, GlobalKey> _commentKeys = {};

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final postsSnapshot =
        await _firestore
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .get();

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

    if (ratingsSnapshot.docs.isNotEmpty) {
      final ratings =
          ratingsSnapshot.docs
              .map((doc) => (doc['rating'] as num).toDouble())
              .toList();
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
        _ratingsDetail[postId] = ratingsDetailsList;
      });
    } else {
      setState(() {
        _ratingCounts[postId] = 0;
        _averageRatings[postId] = 0.0;
        _ratingsDetail[postId] = [];
      });
    }
  }

  void _launchGoogleMaps(String location) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở Google Maps')),
        );
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa bài viết'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa bài viết: $e')));
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text(
              'Bạn có chắc chắn muốn xóa bài viết này không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deletePost(postId);
                },
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kỷ niệm của tôi'),
        backgroundColor: const Color(0xFF63AB83),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('posts')
                .where('userId', isEqualTo: _auth.currentUser?.uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Bạn chưa có bài viết nào',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;
              final postId = post.id;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final formattedDate =
                  timestamp != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
                      : 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(
                        formattedDate,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap:
                                () => _launchGoogleMaps(
                                  data['location'] as String,
                                ),
                            child: Text(
                              data['location'] as String? ?? 'Không xác định',
                              style: const TextStyle(
                                color: Color(0xFF63AB83),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            '#${data['travelType'] as String? ?? 'DuLich'}',
                            style: const TextStyle(color: Color(0xFF63AB83)),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditPostPage(post: post),
                              ),
                            );
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(context, postId);
                          }
                        },
                        itemBuilder:
                            (BuildContext context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Color(0xFF63AB83)),
                                    SizedBox(width: 8),
                                    Text('Chỉnh sửa'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        data['title'] as String? ?? '',
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
                    if ((data['imageUrl'] as String?)?.isNotEmpty ?? false)
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
                              const Icon(Icons.star, color: Colors.amber),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _showRatingsDetailDialog(postId),
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
                                              !(_showComments[postId] ?? false);
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
                            ],
                          ),
                          if (_showComments[postId] ?? false)
                            _buildComments(postId, null),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
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

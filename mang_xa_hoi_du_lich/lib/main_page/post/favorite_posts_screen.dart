import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/expandable_content.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/profile_screen_friend.dart';

class FavoritePostsScreen extends StatefulWidget {
  const FavoritePostsScreen({super.key});

  @override
  _FavoritePostsScreenState createState() => _FavoritePostsScreenState();
}

class _FavoritePostsScreenState extends State<FavoritePostsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, double> _averageRatings = {};
  Map<String, int> _ratingCounts = {};
  Map<String, bool> _expandedContent = {};

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final favoritePosts = await _getFavoritePosts();
    for (var post in favoritePosts) {
      await _fetchRatings(post.id);
    }
  }

  Future<List<DocumentSnapshot>> _getFavoritePosts() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    final favorites =
        await _firestore
            .collection('favorites')
            .where('userId', isEqualTo: userId)
            .get();

    final postIds =
        favorites.docs.map((doc) => doc['postId'] as String).toList();

    if (postIds.isEmpty) return [];

    final posts = await Future.wait(
      postIds.map((id) => _firestore.collection('posts').doc(id).get()),
    );

    return posts.where((doc) => doc.exists).toList();
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

      setState(() {
        _ratingCounts[postId] = ratings.length;
        _averageRatings[postId] =
            ratings.reduce((a, b) => a + b) / ratings.length;
      });
    } else {
      setState(() {
        _ratingCounts[postId] = 0;
        _averageRatings[postId] = 0.0;
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

      setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết yêu thích'),
        backgroundColor: const Color(0xFF63AB83),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('favorites')
                .where('userId', isEqualTo: _auth.currentUser?.uid)
                .snapshots(),
        builder: (context, favoritesSnapshot) {
          if (favoritesSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!favoritesSnapshot.hasData ||
              favoritesSnapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có bài viết yêu thích nào',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final postIds =
              favoritesSnapshot.data!.docs
                  .map((doc) => doc['postId'] as String)
                  .toList();

          return StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('posts')
                    .where(FieldPath.documentId, whereIn: postIds)
                    .snapshots(),
            builder: (context, postsSnapshot) {
              if (postsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Không tìm thấy bài viết',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final posts = postsSnapshot.data!.docs;

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final data = post.data() as Map<String, dynamic>;
                  final postId = post.id;
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
                        return const SizedBox(height: 0);
                      }

                      final userData =
                          userSnapshot.data?.data() as Map<String, dynamic>? ??
                          {};
                      final userName =
                          userData['name'] as String? ?? 'Người dùng';
                      final userPhotoUrl =
                          userData['photoUrl'] as String? ??
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
                                      data['location'] as String? ??
                                          'Không xác định',
                                      style: const TextStyle(
                                        color: Color(0xFF63AB83),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '#${data['travelType'] as String? ?? 'DuLich'}',
                                    style: const TextStyle(
                                      color: Color(0xFF63AB83),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeFromFavorites(postId),
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_averageRatings[postId]?.toStringAsFixed(1) ?? "0.0"} (${_ratingCounts[postId] ?? 0})',
                                    style: const TextStyle(
                                      color: Color(0xFF63AB83),
                                    ),
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
          );
        },
      ),
    );
  }
}

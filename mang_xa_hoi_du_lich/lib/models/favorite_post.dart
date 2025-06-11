// import 'package:cloud_firestore/cloud_firestore.dart';

// class FavoritePost {
//   final String id;
//   final String postId;
//   final String userId;
//   final Timestamp timestamp;

//   FavoritePost({
//     required this.id,
//     required this.postId,
//     required this.userId,
//     required this.timestamp,
//   });

//   factory FavoritePost.fromDocument(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return FavoritePost(
//       id: doc.id,
//       postId: data['postId'] ?? '',
//       userId: data['userId'] ?? '',
//       timestamp: data['timestamp'] ?? Timestamp.now(),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {'postId': postId, 'userId': userId, 'timestamp': timestamp};
//   }
// }

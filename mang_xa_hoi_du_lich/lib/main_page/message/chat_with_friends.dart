import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import 'package:mang_xa_hoi_du_lich/main_page/user_setting/profile_screen_friend.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mang_xa_hoi_du_lich/main_page/notification_service.dart';

// Lớp NotificationService để quản lý thông báo
/* class NotificationService {
//   static final FlutterLocalNotificationsPlugin _notificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//   static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   static bool _permissionsRequested = false;

//   static Future<void> initialize() async {
//     const androidSettings = AndroidInitializationSettings(
//       '@mipmap/ic_launcher',
//     );
//     const iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//       requestCriticalPermission: true,
//     );
//     const initializationSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     await _notificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: (response) async {
//         if (response.payload != null) {
//           final payload = jsonDecode(response.payload!);
//           if (payload['type'] == 'new_message') {
//             final doc =
//                 await FirebaseFirestore.instance
//                     .collection('conversations')
//                     .doc(payload['groupId'])
//                     .get();
//             final members = List<String>.from(doc.data()?['members'] ?? []);
//             print('Navigate to chat: ${payload['groupId']}');
//           }
//         }
//       },
//     );

//     const channel = AndroidNotificationChannel(
//       'high_importance_channel',
//       'Thông báo quan trọng',
//       description: 'Kênh này dùng cho thông báo tin nhắn và cập nhật nhóm.',
//       importance: Importance.max,
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound('notification'),
//       enableVibration: true,
//       enableLights: true,
//       showBadge: true,
//       ledColor: Colors.blue,
//     );
//     await _notificationsPlugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(channel);

//     await _requestPermissions();
//   }

//   static Future<void> _requestPermissions() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hasRequested = prefs.getBool('permissions_requested') ?? false;

//     if (!hasRequested) {
//       final notificationStatus = await Permission.notification.status;
//       if (!notificationStatus.isGranted) {
//         final result = await Permission.notification.request();
//         if (result.isDenied || result.isPermanentlyDenied) {
//           print('Quyền thông báo bị từ chối');
//         }
//       }

//       if (Platform.isAndroid) {
//         final batteryStatus =
//             await Permission.ignoreBatteryOptimizations.status;
//         if (!batteryStatus.isGranted) {
//           await Permission.ignoreBatteryOptimizations.request();
//         }
//       }

//       await prefs.setBool('permissions_requested', true);
//       _permissionsRequested = true;
//     }
//   }

//   static Future<void> setupFirebaseMessaging() async {
//     try {
//       final settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//         criticalAlert: true,
//       );
//       if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//         final currentUser = FirebaseAuth.instance.currentUser;
//         if (currentUser == null) {
//           print('No authenticated user found for FCM setup');
//           return;
//         }

//         String? token;
//         for (int i = 0; i < 3; i++) {
//           token = await _messaging.getToken();
//           if (token != null) break;
//           print('FCM token fetch attempt ${i + 1} failed, retrying...');
//           await Future.delayed(const Duration(seconds: 2));
//         }

//         if (token != null) {
//           final userRef = FirebaseFirestore.instance
//               .collection('users')
//               .doc(currentUser.uid);
//           final userDoc = await userRef.get();
//           await userRef.set({
//             'uid': currentUser.uid,
//             'fcmToken': token,
//             'createdAt': FieldValue.serverTimestamp(),
//           }, SetOptions(merge: true));
//           print('Saved FCM token for UID: ${currentUser.uid}');

//           _messaging.onTokenRefresh.listen((newToken) async {
//             if (FirebaseAuth.instance.currentUser != null) {
//               await FirebaseFirestore.instance
//                   .collection('users')
//                   .doc(FirebaseAuth.instance.currentUser!.uid)
//                   .update({'fcmToken': newToken});
//               print('Refreshed FCM token for UID: ${currentUser.uid}');
//             }
//           });
//         } else {
//           print(
//             'Failed to obtain FCM token after retries for UID: ${currentUser.uid}',
//           );
//         }
//       } else {
//         print('FCM permission not granted: ${settings.authorizationStatus}');
//       }
//     } catch (e) {
//       print('Error setting up Firebase Messaging: $e');
//     }

//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       print('Nhận FCM foreground: ${message.messageId}');
//       showLocalNotification(message);
//     });

//     final initialMessage = await _messaging.getInitialMessage();
//     if (initialMessage != null) {
//       print('Nhận FCM initial: ${initialMessage.messageId}');
//     }

//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       print('Mở ứng dụng từ thông báo: ${message.messageId}');
//     });

//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//   }

//   static Future<void> _firebaseMessagingBackgroundHandler(
//     RemoteMessage message,
//   ) async {
//     await Firebase.initializeApp();
//     print('Nhận FCM background: ${message.messageId}');
//     await showLocalNotification(message);
//   }

//   static Future<void> showLocalNotification(RemoteMessage message) async {
//     final notification = message.notification;
//     if (notification != null) {
//       print(
//         'Showing notification: ${notification.title} - ${notification.body}',
//       );
//       const androidDetails = AndroidNotificationDetails(
//         'high_importance_channel',
//         'Thông báo quan trọng',
//         channelDescription:
//             'Kênh này dùng cho thông báo tin nhắn và cập nhật nhóm.',
//         importance: Importance.max,
//         priority: Priority.high,
//         playSound: true,
//         sound: RawResourceAndroidNotificationSound('notification'),
//         enableVibration: true,
//         enableLights: true,
//         ticker: 'ticker',
//         fullScreenIntent: true,
//         visibility: NotificationVisibility.public,
//         styleInformation: BigTextStyleInformation(''),
//       );
//       const iosDetails = DarwinNotificationDetails(
//         sound: 'notification.mp3',
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//         threadIdentifier: 'chat_thread',
//         categoryIdentifier: 'NEW_MESSAGE',
//       );
//       const notificationDetails = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );

//       await _notificationsPlugin.show(
//         notification.hashCode,
//         notification.title,
//         notification.body,
//         notificationDetails,
//         payload: jsonEncode({
//           'groupId': message.data['groupId'],
//           'groupName': message.data['groupName'],
//           'type': message.data['type'],
//         }),
//       );
//     } else {
//       print('No notification data: ${message.data}');
//     }
//   }

//   static Future<void> showSimpleNotification({
//     String title = 'Thông báo',
//     String body = 'Bạn có tin nhắn mới!',
//   }) async {
//     const androidDetails = AndroidNotificationDetails(
//       'high_importance_channel',
//       'Thông báo quan trọng',
//       channelDescription:
//           'Kênh này dùng cho thông báo tin nhắn và cập nhật nhóm.',
//       importance: Importance.max,
//       priority: Priority.high,
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound('notification'),
//       enableVibration: true,
//       enableLights: true,
//       fullScreenIntent: true,
//       visibility: NotificationVisibility.public,
//     );
//     const iosDetails = DarwinNotificationDetails(
//       sound: 'notification.mp3',
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );
//     const notificationDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );

//     await _notificationsPlugin.show(0, title, body, notificationDetails);
//   }

//   static Future<void> listenToChatChanges(String conversationId) async {
//     await Firebase.initializeApp();
//     FirebaseFirestore.instance
//         .collection('conversations')
//         .doc(conversationId)
//         .snapshots()
//         .listen((conversationSnapshot) async {
//           print('Conversation snapshot triggered for $conversationId');
//           if (!conversationSnapshot.exists) {
//             print('Conversation deleted: $conversationId');
//             return;
//           }

//           final data = conversationSnapshot.data();
//           if (data == null) {
//             print('Conversation data is null');
//             return;
//           }

//           final members = List<String>.from(data['members'] ?? []);
//           final currentUserId = FirebaseAuth.instance.currentUser?.uid;

//           if (currentUserId == null || !members.contains(currentUserId)) {
//             print('Current user is null or not in members');
//             return;
//           }

//           final previousMembers = List<String>.from(
//             data['previousMembers'] ?? [],
//           );
//           final newMembers =
//               members
//                   .where((member) => !previousMembers.contains(member))
//                   .toList();
//           final removedMembers =
//               previousMembers
//                   .where((member) => !members.contains(member))
//                   .toList();

//           for (var memberId in newMembers) {
//             if (memberId != currentUserId) {
//               print('Sending notification for new member: $memberId');
//               await sendChatEventNotification(
//                 userId: memberId,
//                 title: 'Thêm vào nhóm',
//                 message:
//                     'Bạn đã được thêm vào nhóm ${data['name'] ?? 'Nhóm chat'}',
//                 type: 'added',
//                 conversationId: conversationId,
//               );
//             }
//           }

//           for (var memberId in removedMembers) {
//             if (memberId != currentUserId) {
//               print('Sending notification for removed member: $memberId');
//               await sendChatEventNotification(
//                 userId: memberId,
//                 title: 'Bị xóa khỏi nhóm',
//                 message:
//                     'Bạn đã bị xóa khỏi nhóm ${data['name'] ?? 'Nhóm chat'}',
//                 type: 'removed',
//                 conversationId: conversationId,
//               );
//             }
//           }

//           await FirebaseFirestore.instance
//               .collection('conversations')
//               .doc(conversationId)
//               .update({'previousMembers': members});
//         });
//   }

//   static Future<void> sendChatEventNotification({
//     required String userId,
//     required String title,
//     required String message,
//     required String type,
//     required String conversationId,
//   }) async {
//     try {
//       final token = await _getUserFCMToken(userId);
//       if (token == null) {
//         print('Không tìm thấy FCM token cho user: $userId, bỏ qua thông báo');
//         return;
//       }

//       final serviceAccountJson = {
//         "type": "service_account",
//         "project_id": "mangxahoidulich-46e6f",
//         "private_key_id": "2d951bfc19bc31c696917b602042fc1ba03d38a0",
//         "private_key":
//             "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDqxxZizr64/D81\nSAsRzPSDI6Okm1lBm3ZK8OsFe3diSvj7Il7jawfVV6y3xaIcqn3TSDKnBdleL9Yu\ncXZ0rvxroJQqxRckvFiqCS78/aw3uG2DgE/qrU/+IBZK9mUyZ6ZSYVDr6yEKYvX+\nYRYh7b8a+3xjzW0Zab5/Qt3NHz+Wwe1qojnNmh5C99Xs13La9OV85GswTSVh30Fk\no95BETuBDWVZG1ISAxXiPfXWiRijUQHKtfKyDjAH21tT3a2wOeaDYgOQqsDZXmnT\nS0Agb7ywTbJDTC0UxjPptEcylUjw0jn07L8wL4ZpURVlzBKWuJ5anGOQHi504xhP\nuLOjEGZ1AgMBAAECggEAFHbbECzGOhiep9XKRThwvbePDYuO+aWD559dVQKAkvxG\n/Jjv3XHYYnO8dd5PtaD0y8RYye88FbYkvLKeKSiRjw4VrC62yDh0oAmh42J3Lvov\n7YzzKlkGBngkiU813fFj8X1TEOVTYXTjzVMIG1f+VutB2e8vic4KUUxySe1l3Q2K\nkLanA32l9lkmlfv4oSifH0Ss6IZbpLxLRRJamN5ypnpnL7XFGxznpME0wkEyCWTN\nQX8C6JyxUxjIrW+jaOYsvj+zBMvMDhKqDu7aZM7OzpWdelKA0yvdzmpMwdD9zuGo\nG6gtdExGqDzDCJA+F+sEFxpmXK+XLG5G4wyDxIEkMQKBgQD+ATa/S7BN3l6fvUkt\nuLaKS8l5CMFm0+9mfnyQjSnyIhOM02TeH/rjszsq1vyQVOe+QO76LqOLmI0uUcjc\nkQvH2jYzjpvayZfE08YsBDuyo8ObRhXXdp0qQXq/iOlZdgLcjAnxydIU0v9mDPue\n0dX2R47A5GJqbhDFimauiK0PCQKBgQDsnzWUW9YqSj4nDhO+U9Grb6y3zDP39P1S\nSiDGiKIuu3349mwAsGbDtcA+WesfKywWBCb9MN1YuyA07it0cduzT/L0N8xmwDil\nPYBnO6GatqJrx67Js18EZrlr33Wuuqvq35ucPXCDmhCO3VbdY3RvpfQ6Olss6bHX\nYhtJsKdLDQKBgQDPGbhEsvbWFrg6MECJWfDjw7VKzTu7lpO8kucHiUGpHeWozfeR\nMKwEme9lF5MoL0Igmpr/O6W3PTPnj2FhjZX4ZlAJK36iHfpzzmPnIbB3EBV99d/7\nJMgyWt81afExMwpUPo4hKXfz6LG6yF0kelylCGU5mz0vH/zmw9jC98d62QKBgEtE\nrbd+qxaSvUiRGsitQwHkqS1iIJncbYRynhBpQCXbcEv0nxBtDJNuyjNLSRaGFiT+\ntyRNGevywmDz7hDBcyCL6v2yjiuVM6+ka6bq+hILzIi6YSg6DZyJzKu6zmWBbdRt\nwsMlbBgAtwmq8MnFrDEjuheXno8f23lm9MUxE1Y1AoGBAPKU3Uu+Ms8Ybh3Fd31/\nhFDPp9Waa2lBvbUCvpDEDcnVmOb+Ur4Cv9iAtVMUtssvi7oZ1bbSo2813b+NnbQH\nNR8LoFoZ6C58fpRiPPeSsjXgik7avTWALaRbNRAzCmJiKTRUZMG4CId2qtctraqh\nOVUhgMIBRiwQcpCv1c89cO5a\n-----END PRIVATE KEY-----\n",
//         "client_email":
//             "firebase-adminsdk-fbsvc@mangxahoidulich-46e6f.iam.gserviceaccount.com",
//         "client_id": "105830038613686891907",
//         "auth_uri": "https://accounts.google.com/o/oauth2/auth",
//         "token_uri": "https://oauth2.googleapis.com/token",
//         "auth_provider_x509_cert_url":
//             "https://www.googleapis.com/oauth2/v1/certs",
//         "client_x509_cert_url":
//             "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40mangxahoidulich-46e6f.iam.gserviceaccount.com",
//         "universe_domain": "googleapis.com",
//       };
//       final credentials = auth.ServiceAccountCredentials.fromJson(
//         serviceAccountJson,
//       );
//       final projectId = serviceAccountJson['project_id'] as String;
//       final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
//       final client = await auth.clientViaServiceAccount(credentials, scopes);
//       try {
//         final accessToken = (await client.credentials.accessToken).data;
//         final url = Uri.parse(
//           'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
//         );
//         for (int i = 0; i < 3; i++) {
//           final response = await http.post(
//             url,
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $accessToken',
//             },
//             body: jsonEncode({
//               'message': {
//                 'token': token,
//                 'notification': {
//                   'title': title,
//                   'body':
//                       message.length > 100
//                           ? '${message.substring(0, 97)}...'
//                           : message,
//                 },
//                 'data': {
//                   'type': type,
//                   'groupId': conversationId,
//                   'groupName': '',
//                   'click_action': 'FLUTTER_NOTIFICATION_CLICK',
//                 },
//                 'android': {
//                   'priority': 'high',
//                   'notification': {
//                     'channel_id': 'high_importance_channel',
//                     'icon': 'ic_notification',
//                     'sound': 'notification',
//                     'visibility': 'public',
//                     'tag': type,
//                   },
//                 },
//                 'apns': {
//                   'headers': {'apns-priority': '10'},
//                   'payload': {
//                     'aps': {
//                       'alert': {
//                         'title': title,
//                         'body':
//                             message.length > 100
//                                 ? '${message.substring(0, 97)}...'
//                                 : message,
//                       },
//                       'sound': 'notification.mp3',
//                       'badge': 1,
//                       'category': 'NEW_MESSAGE',
//                       'content-available': 1,
//                     },
//                   },
//                 },
//               },
//             }),
//           );

//           if (response.statusCode == 200) {
//             print('Gửi FCM thành công for user $userId: ${response.body}');
//             break;
//           } else if (response.statusCode == 404 &&
//               response.body.contains('UNREGISTERED')) {
//             await FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(userId)
//                 .update({'fcmToken': FieldValue.delete()});
//             print('Đã xóa FCM token không hợp lệ cho user: $userId');
//             final newToken = await FirebaseMessaging.instance.getToken();
//             if (newToken != null) {
//               await FirebaseFirestore.instance
//                   .collection('users')
//                   .doc(userId)
//                   .update({'fcmToken': newToken});
//               print('Refreshed FCM token for user: $userId');
//               if (i < 2) continue;
//             }
//           } else {
//             print(
//               'Gửi FCM thất bại for user $userId: ${response.statusCode} - ${response.body}',
//             );
//           }
//           if (i < 2) await Future.delayed(const Duration(seconds: 2));
//         }
//       } catch (e) {
//         print('Lỗi gửi HTTP request for user $userId: $e');
//       } finally {
//         client.close();
//       }
//     } catch (e) {
//       print('Lỗi gửi thông báo cho user $userId: $e');
//     }
//   }

//   static Future<String?> _getUserFCMToken(String userId) async {
//     try {
//       final userDoc =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(userId)
//               .get();
//       if (!userDoc.exists) {
//         print('User document does not exist for UID: $userId');
//         return null;
//       }
//       final token = userDoc.data()?['fcmToken'] as String?;
//       if (token == null) {
//         print('FCM token is null for UID: $userId');
//       }
//       return token;
//     } catch (e) {
//       print('Lỗi lấy FCM token cho UID $userId: $e');
//       return null;
//     }
//   }
// } */

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final bool isGroup;
  final List<String> members;
  final String conversationName;
  final String? creatorId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.isGroup,
    required this.members,
    required this.conversationName,
    this.creatorId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _messageLimit = 20;
  DocumentSnapshot? _lastMessage;
  bool _isLoadingMore = false;
  bool _isLoading = false;
  List<String> _selectedFriends = [];
  String _groupAvatarUrl = 'assets/messages/default_avatar.png';
  String _groupBackgroundUrl = 'assets/messages/default_background.png';
  List<Map<String, dynamic>> _membersInfo = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializeGroupSettings();
    _refreshMembersInfo();
    NotificationService.listenToChatChanges(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels != 0 &&
        !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _initializeGroupSettings() async {
    if (!widget.isGroup) return;
    try {
      final conversationDoc =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .get();
      final data = conversationDoc.data();
      if (data != null && mounted) {
        setState(() {
          _groupAvatarUrl = data['avatarUrl'] as String? ?? _groupAvatarUrl;
          _groupBackgroundUrl =
              data['backgroundUrl'] as String? ?? _groupBackgroundUrl;
          if (data['previousMembers'] == null) {
            _firestore
                .collection('conversations')
                .doc(widget.conversationId)
                .update({'previousMembers': widget.members});
          }
        });
      }
      if (widget.creatorId != null &&
          !(data?['admins']?.contains(widget.creatorId) ?? false)) {
        await _firestore
            .collection('conversations')
            .doc(widget.conversationId)
            .update({
              'admins': FieldValue.arrayUnion([widget.creatorId]),
            });
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải cài đặt nhóm: $e');
    }
  }

  Future<void> _refreshMembersInfo() async {
    final membersInfo = await _getMembersInfo();
    if (mounted) {
      setState(() {
        _membersInfo = membersInfo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage(_groupAvatarUrl),
              onBackgroundImageError:
                  (_, __) => const Icon(LineIcons.exclamationCircle, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.conversationName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF63AB83),
        foregroundColor: Colors.white,
        actions:
            widget.isGroup
                ? [
                  IconButton(
                    icon: const Icon(LineIcons.users, color: Colors.white),
                    onPressed:
                        () => _showGroupMembersDialog(context, currentUserId),
                  ),
                  IconButton(
                    icon: const Icon(LineIcons.userPlus, color: Colors.white),
                    onPressed:
                        () => _showAddMemberDialog(context, currentUserId),
                  ),
                  IconButton(
                    icon: const Icon(LineIcons.image, color: Colors.white),
                    onPressed:
                        () => _showImageSelectionDialog(context, currentUserId),
                  ),
                ]
                : null,
      ),
      body: Container(
        decoration:
            widget.isGroup && _groupBackgroundUrl.isNotEmpty
                ? BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_groupBackgroundUrl),
                    fit: BoxFit.cover,
                    onError: (_, __) => const Icon(LineIcons.exclamationCircle),
                  ),
                )
                : null,
        child: Column(
          children: [
            if (widget.isGroup) _buildGroupMembersInfo(currentUserId),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('conversations')
                        .doc(widget.conversationId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .limit(_messageLimit)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Lỗi khi tải tin nhắn. Vui lòng thử lại.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!.docs;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có tin nhắn nào. Hãy bắt đầu trò chuyện!',
                      ),
                    );
                  }

                  _lastMessage = messages.isNotEmpty ? messages.last : null;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          messages[index].data() as Map<String, dynamic>? ?? {};
                      final senderId = message['senderId'] as String? ?? '';
                      final content = message['content'] as String? ?? '';
                      final timestamp =
                          (message['timestamp'] as Timestamp?)?.toDate();
                      final isMe = senderId == currentUserId;
                      final messageId = messages[index].id;
                      final isRecalled =
                          message['isRecalled'] as bool? ?? false;

                      if (senderId.isEmpty) return const SizedBox.shrink();

                      return FutureBuilder<Map<String, dynamic>>(
                        future: _getUserData(senderId),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Lỗi tải thông tin người dùng'),
                            );
                          }
                          final userData = userSnapshot.data!;
                          final name = userData['name'] as String? ?? 'Ẩn';
                          final photoUrl =
                              userData['photoUrl'] as String? ??
                              'https://via.placeholder.com/150';

                          return _buildCardMessage(
                            isMe: isMe,
                            name: name,
                            photoUrl: photoUrl,
                            content: content,
                            timestamp: timestamp,
                            senderId: senderId,
                            messageId: messageId,
                            isRecalled: isRecalled,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(currentUserId),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMessage({
    required bool isMe,
    required String name,
    required String photoUrl,
    required String content,
    required DateTime? timestamp,
    required String senderId,
    required String messageId,
    required bool isRecalled,
  }) {
    final formattedTime =
        timestamp != null ? DateFormat('HH:mm').format(timestamp) : '';
    return GestureDetector(
      onLongPress:
          isMe && !isRecalled
              ? () => _showMessageOptions(context, messageId, content)
              : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () => _navigateToProfile(senderId),
                  child: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(photoUrl),
                    radius: 16,
                    onBackgroundImageError:
                        (_, __) =>
                            const Icon(LineIcons.exclamationCircle, size: 16),
                  ),
                ),
              ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF63AB83) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe && widget.isGroup)
                      GestureDetector(
                        onTap: () => _navigateToProfile(senderId),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF63AB83),
                          ),
                        ),
                      ),
                    Text(
                      isRecalled ? 'Tin nhắn đã được thu hồi' : content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : Colors.black87,
                        fontStyle:
                            isRecalled ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: () => _navigateToProfile(senderId),
                  child: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(photoUrl),
                    radius: 16,
                    onBackgroundImageError:
                        (_, __) =>
                            const Icon(LineIcons.exclamationCircle, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(
    BuildContext context,
    String messageId,
    String content,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Tùy chọn tin nhắn'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(LineIcons.edit),
                  title: const Text('Chỉnh sửa'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showEditMessageDialog(context, messageId, content);
                  },
                ),
                ListTile(
                  leading: const Icon(LineIcons.trash),
                  title: const Text('Thu hồi'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _confirmRecallMessage(context, messageId);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
  }

  void _showEditMessageDialog(
    BuildContext context,
    String messageId,
    String currentContent,
  ) {
    final editController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Chỉnh sửa tin nhắn'),
            content: TextField(
              controller: editController,
              decoration: const InputDecoration(
                hintText: 'Nhập nội dung mới...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: () {
                  _editMessage(messageId, editController.text.trim());
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Lưu',
                  style: TextStyle(color: Color(0xFF63AB83)),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _editMessage(String messageId, String newContent) async {
    if (newContent.isEmpty) {
      _showSnackBar('Nội dung tin nhắn không được để trống');
      return;
    }
    try {
      // Lấy thông tin tin nhắn hiện tại
      final messageDoc =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .collection('messages')
              .doc(messageId)
              .get();

      // Cập nhật nội dung tin nhắn
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'content': newContent});

      // Kiểm tra xem tin nhắn này có phải là tin nhắn cuối cùng không
      final lastMessageDoc =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .get();

      if (lastMessageDoc.exists) {
        final lastMessage = lastMessageDoc.data()?['lastMessage'];
        final lastMessageTime =
            lastMessageDoc.data()?['lastMessageTime'] as Timestamp?;
        final messageTime = messageDoc.data()?['timestamp'] as Timestamp?;

        // Nếu tin nhắn này là tin nhắn cuối cùng, cập nhật lastMessage
        if (lastMessageTime != null &&
            messageTime != null &&
            lastMessageTime.seconds == messageTime.seconds) {
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .update({'lastMessage': newContent});
        }
      }

      _showSnackBar('Đã chỉnh sửa tin nhắn');
    } catch (e) {
      _showSnackBar('Lỗi khi chỉnh sửa tin nhắn: $e');
    }
  }

  void _confirmRecallMessage(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Thu hồi tin nhắn'),
            content: const Text('Bạn có chắc chắn muốn thu hồi tin nhắn này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: () {
                  _recallMessage(messageId);
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Thu hồi',
                  style: TextStyle(color: Color(0xFF63AB83)),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _recallMessage(String messageId) async {
    try {
      final messageDoc =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .collection('messages')
              .doc(messageId)
              .get();

      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'isRecalled': true}); // Đánh dấu thu hồi thay vì xóa

      final lastMessageDoc =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .get();

      if (lastMessageDoc.exists) {
        final lastMessageTime =
            lastMessageDoc.data()?['lastMessageTime'] as Timestamp?;
        final messageTime = messageDoc.data()?['timestamp'] as Timestamp?;

        if (lastMessageTime != null &&
            messageTime != null &&
            lastMessageTime.seconds == messageTime.seconds) {
          final previousMessages =
              await _firestore
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .get();

          if (previousMessages.docs.isNotEmpty) {
            final previousMessage = previousMessages.docs.first;
            await _firestore
                .collection('conversations')
                .doc(widget.conversationId)
                .update({
                  'lastMessage':
                      previousMessage.data()['isRecalled'] == true
                          ? 'Tin nhắn đã được thu hồi'
                          : previousMessage.data()['content'] ??
                              'Tin nhắn đã bị xóa',
                  'lastMessageTime': previousMessage.data()['timestamp'],
                });
          } else {
            await _firestore
                .collection('conversations')
                .doc(widget.conversationId)
                .update({
                  'lastMessage': 'Chưa có tin nhắn',
                  'lastMessageTime': FieldValue.serverTimestamp(),
                });
          }
        }
      }

      final currentUserId = _auth.currentUser!.uid;
      final notificationFutures =
          widget.members.where((memberId) => memberId != currentUserId).map((
            memberId,
          ) async {
            try {
              await NotificationService.sendChatEventNotification(
                userId: memberId,
                title: 'Tin nhắn thu hồi',
                message:
                    'Một tin nhắn trong nhóm ${widget.conversationName} đã được thu hồi',
                type: 'message_recalled',
                conversationId: widget.conversationId,
              );
            } catch (e) {
              print('Lỗi gửi thông báo cho user $memberId: $e');
            }
          }).toList();

      await Future.wait(notificationFutures);
      _showSnackBar('Đã thu hồi tin nhắn');
    } catch (e) {
      _showSnackBar('Lỗi khi thu hồi tin nhắn: $e');
    }
  }

  Widget _buildMessageInput(String currentUserId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF63AB83),
                child: IconButton(
                  icon: const Icon(LineIcons.paperPlane, color: Colors.white),
                  onPressed: () => _sendMessage(currentUserId),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGroupMembersInfo(String currentUserId) {
    final nonFriends =
        _membersInfo
            .where(
              (member) =>
                  !member['isFriend'] && member['userId'] != currentUserId,
            )
            .toList();

    if (nonFriends.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            nonFriends.map((member) {
              return GestureDetector(
                onTap: () => _navigateToProfile(member['userId'] as String),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          member['photoUrl'] as String,
                        ),
                        radius: 16,
                        onBackgroundImageError:
                            (_, __) => const Icon(LineIcons.exclamationCircle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bạn chưa kết thân với ${member['name'] as String}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  void _showGroupMembersDialog(
    BuildContext context,
    String currentUserId,
  ) async {
    await _refreshMembersInfo();
    if (!mounted) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.7;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  height: dialogHeight,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Thành viên',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FutureBuilder<bool>(
                            future: _isCurrentUserAdmin(currentUserId),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || !snapshot.data!) {
                                return const SizedBox.shrink();
                              }
                              return TextButton(
                                onPressed:
                                    () => _confirmDisbandGroup(
                                      context,
                                      currentUserId,
                                      setDialogState,
                                    ),
                                child: const Text(
                                  'Giải tán nhóm',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot>(
                          stream:
                              _firestore
                                  .collection('conversations')
                                  .doc(widget.conversationId)
                                  .snapshots(),
                          builder: (context, conversationSnapshot) {
                            if (conversationSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!conversationSnapshot.hasData ||
                                !conversationSnapshot.data!.exists) {
                              return const Center(
                                child: Text('Không tìm thấy thông tin nhóm'),
                              );
                            }

                            final data =
                                conversationSnapshot.data!.data()
                                    as Map<String, dynamic>;
                            final members = List<String>.from(
                              data['members'] ?? [],
                            );
                            final admins = List<String>.from(
                              data['admins'] ?? [],
                            );

                            return ListView.builder(
                              itemCount: members.length,
                              itemBuilder: (context, index) {
                                final memberId = members[index];
                                return StreamBuilder<DocumentSnapshot>(
                                  stream:
                                      _firestore
                                          .collection('users')
                                          .doc(memberId)
                                          .snapshots(),
                                  builder: (context, userSnapshot) {
                                    if (!userSnapshot.hasData) {
                                      return const ListTile(
                                        title: Text('Đang tải...'),
                                      );
                                    }

                                    final userData =
                                        userSnapshot.data!.data()
                                            as Map<String, dynamic>?;
                                    final name =
                                        userData?['name'] as String? ??
                                        'Người dùng không xác định';
                                    final photoUrl =
                                        userData?['photoUrl'] as String? ??
                                        'https://via.placeholder.com/150';
                                    final isAdmin = admins.contains(memberId);

                                    return StreamBuilder<DocumentSnapshot>(
                                      stream:
                                          _firestore
                                              .collection('friends')
                                              .doc(currentUserId)
                                              .collection('friendships')
                                              .doc(memberId)
                                              .snapshots(),
                                      builder: (context, friendshipSnapshot) {
                                        final isFriend =
                                            friendshipSnapshot.hasData &&
                                            friendshipSnapshot.data!.exists;
                                        final isCurrentUser =
                                            memberId == currentUserId;

                                        return ListTile(
                                          leading: GestureDetector(
                                            onTap:
                                                () => _navigateToProfile(
                                                  memberId,
                                                ),
                                            child: CircleAvatar(
                                              backgroundImage:
                                                  CachedNetworkImageProvider(
                                                    photoUrl,
                                                  ),
                                              onBackgroundImageError:
                                                  (_, __) => const Icon(
                                                    LineIcons.exclamationCircle,
                                                  ),
                                            ),
                                          ),
                                          title: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            isAdmin
                                                ? 'Trưởng nhóm'
                                                : (isFriend
                                                    ? 'Bạn bè'
                                                    : isCurrentUser
                                                    ? 'Bạn'
                                                    : 'Thành viên'),
                                            style: TextStyle(
                                              color:
                                                  isAdmin
                                                      ? Colors.blue
                                                      : (isFriend
                                                          ? Colors.green
                                                          : Colors.grey),
                                            ),
                                          ),
                                          trailing: FutureBuilder<bool>(
                                            future: _isCurrentUserAdmin(
                                              currentUserId,
                                            ),
                                            builder: (context, adminSnapshot) {
                                              if (!adminSnapshot.hasData ||
                                                  !adminSnapshot.data! ||
                                                  memberId == currentUserId) {
                                                return const SizedBox.shrink();
                                              }
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      isAdmin
                                                          ? LineIcons.userMinus
                                                          : LineIcons
                                                              .userShield,
                                                      color: Colors.blue,
                                                    ),
                                                    onPressed:
                                                        () =>
                                                            isAdmin
                                                                ? _removeAdminRole(
                                                                  memberId,
                                                                  name,
                                                                  setDialogState,
                                                                )
                                                                : _assignAdminRole(
                                                                  memberId,
                                                                  name,
                                                                  setDialogState,
                                                                ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      LineIcons.userMinus,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed:
                                                        () =>
                                                            _confirmRemoveMember(
                                                              memberId,
                                                              name,
                                                              setDialogState,
                                                            ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          onTap:
                                              () =>
                                                  _navigateToProfile(memberId),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  void _showAddMemberDialog(BuildContext context, String currentUserId) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.7;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  height: dialogHeight,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Thêm thành viên vào nhóm',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream:
                              _firestore
                                  .collection('friends')
                                  .doc(currentUserId)
                                  .collection('friendships')
                                  .snapshots(),
                          builder: (context, friendsSnapshot) {
                            if (friendsSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!friendsSnapshot.hasData ||
                                friendsSnapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Bạn chưa có bạn bè nào để thêm vào nhóm',
                                ),
                              );
                            }

                            final friends = friendsSnapshot.data!.docs;
                            return StreamBuilder<DocumentSnapshot>(
                              stream:
                                  _firestore
                                      .collection('conversations')
                                      .doc(widget.conversationId)
                                      .snapshots(),
                              builder: (context, conversationSnapshot) {
                                if (!conversationSnapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final currentMembers = List<String>.from(
                                  conversationSnapshot.data!.get('members') ??
                                      [],
                                );
                                final availableFriends =
                                    friends
                                        .where(
                                          (friend) =>
                                              !currentMembers.contains(
                                                friend.id,
                                              ),
                                        )
                                        .toList();

                                if (availableFriends.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'Tất cả bạn bè đã ở trong nhóm',
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: availableFriends.length,
                                  itemBuilder: (context, index) {
                                    final friendId = availableFriends[index].id;
                                    return StreamBuilder<DocumentSnapshot>(
                                      stream:
                                          _firestore
                                              .collection('users')
                                              .doc(friendId)
                                              .snapshots(),
                                      builder: (context, userSnapshot) {
                                        if (!userSnapshot.hasData) {
                                          return const ListTile(
                                            title: Text('Đang tải...'),
                                          );
                                        }

                                        final userData =
                                            userSnapshot.data!.data()
                                                as Map<String, dynamic>?;
                                        final name =
                                            userData?['name'] as String? ??
                                            'Người dùng không xác định';
                                        final photoUrl =
                                            userData?['photoUrl'] as String? ??
                                            'https://via.placeholder.com/150';

                                        return CheckboxListTile(
                                          value: _selectedFriends.contains(
                                            friendId,
                                          ),
                                          onChanged:
                                              _isLoading
                                                  ? null
                                                  : (selected) {
                                                    setDialogState(() {
                                                      if (selected == true) {
                                                        _selectedFriends.add(
                                                          friendId,
                                                        );
                                                      } else {
                                                        _selectedFriends.remove(
                                                          friendId,
                                                        );
                                                      }
                                                    });
                                                  },
                                          secondary: CircleAvatar(
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                  photoUrl,
                                                ),
                                            onBackgroundImageError:
                                                (_, __) => const Icon(
                                                  LineIcons.exclamationCircle,
                                                ),
                                          ),
                                          title: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          activeColor: const Color(0xFF63AB83),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              _selectedFriends.clear();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Hủy',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => _addMembers(
                                      currentUserId,
                                      context,
                                      setDialogState,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF63AB83),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Thêm',
                                      style: TextStyle(color: Colors.white),
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  void _showImageSelectionDialog(
    BuildContext context,
    String currentUserId,
  ) async {
    if (!mounted) {
      print('Widget is not mounted, cannot show dialog');
      return;
    }

    try {
      final isAdmin = await _isCurrentUserAdmin(currentUserId);
      if (!isAdmin) {
        _showSnackBar('Chỉ trưởng nhóm được phép thay đổi hình ảnh nhóm');
        return;
      }

      showDialog(
        context: context,
        builder:
            (dialogContext) => ImageSelectionDialog(
              currentAvatar: _groupAvatarUrl,
              currentBackground: _groupBackgroundUrl,
              conversationId: widget.conversationId,
              conversationName: widget.conversationName,
              members: widget.members,
              onAvatarUpdated: (newAvatar) {
                if (mounted) {
                  setState(() {
                    _groupAvatarUrl = newAvatar;
                  });
                }
              },
              onBackgroundUpdated: (newBackground) {
                if (mounted) {
                  setState(() {
                    _groupBackgroundUrl = newBackground;
                  });
                }
              },
            ),
      );
    } catch (e) {
      print('Error opening image selection dialog: $e');
      if (mounted) {
        _showSnackBar('Lỗi khi mở tùy chọn ảnh: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getMembersInfo() async {
    final membersInfo = <Map<String, dynamic>>[];
    for (final memberId in widget.members) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(memberId).get();
        final userData = userDoc.exists ? userDoc.data() : {};
        final isFriend = await _checkFriendStatus(memberId);
        final isAdmin = await _checkAdminStatus(memberId);
        membersInfo.add({
          'userId': memberId,
          'name': userData?['name'] as String? ?? 'Ẩn',
          'photoUrl':
              userData?['photoUrl'] as String? ??
              'https://via.placeholder.com/150',
          'isFriend': isFriend,
          'isAdmin': isAdmin,
        });
      } catch (e) {
        membersInfo.add({
          'userId': memberId,
          'name': 'Lỗi tải dữ liệu',
          'photoUrl': 'https://via.placeholder.com/150',
          'isFriend': false,
          'isAdmin': false,
        });
      }
    }
    return membersInfo;
  }

  Future<bool> _checkFriendStatus(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || userId == currentUserId) {
      return true;
    }
    try {
      final friendDoc =
          await _firestore
              .collection('friends')
              .doc(currentUserId)
              .collection('friendships')
              .doc(userId)
              .get();
      return friendDoc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkAdminStatus(String userId) async {
    try {
      final conversationDoc =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .get();
      final admins = conversationDoc.data()?['admins'] as List<dynamic>? ?? [];
      return admins.contains(userId);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isCurrentUserAdmin(String currentUserId) async {
    return _checkAdminStatus(currentUserId);
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data() ??
          {'name': 'Ẩn', 'photoUrl': 'https://via.placeholder.com/150'};
    } catch (e) {
      return {
        'name': 'Lỗi tải dữ liệu',
        'photoUrl': 'https://via.placeholder.com/150',
      };
    }
  }

  Future<void> _sendMessage(String currentUserId) async {
    if (_messageController.text.trim().isEmpty) {
      print('Tin nhắn rỗng, bỏ qua');
      return;
    }

    final message = {
      'senderId': currentUserId,
      'content': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isRecalled': false,
    };

    try {
      print('Bắt đầu gửi tin nhắn từ user: $currentUserId');
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add(message);
      print('Đã thêm tin nhắn vào Firestore');

      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'lastMessage': _messageController.text.trim(),
            'lastMessageTime': FieldValue.serverTimestamp(),
          });
      print('Đã cập nhật lastMessage trong Firestore');

      final senderDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!senderDoc.exists) {
        print('Không tìm thấy tài liệu người gửi cho user: $currentUserId');
        _showSnackBar('Lỗi: Không tìm thấy thông tin người gửi');
        return;
      }
      final senderName = senderDoc.data()?['name'] ?? 'Ẩn danh';
      print('Tên người gửi: $senderName');

      final notificationFutures =
          widget.members
              .where(
                (memberId) => memberId != currentUserId,
              ) // Loại trừ người gửi
              .map((memberId) async {
                try {
                  await NotificationService.sendChatEventNotification(
                    userId: memberId,
                    title: widget.conversationName,
                    message: '$senderName: ${_messageController.text.trim()}',
                    type: 'new_message',
                    conversationId: widget.conversationId,
                  );
                  print('Đã gửi thông báo cho user: $memberId');
                } catch (e) {
                  print('Lỗi gửi thông báo cho user $memberId: $e');
                }
              })
              .toList();

      await Future.wait(notificationFutures);
      print('Hoàn tất gửi thông báo cho tất cả thành viên');

      _messageController.clear();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        print('Đã cuộn xuống dưới danh sách tin nhắn');
      }
    } catch (e) {
      print('Lỗi khi gửi tin nhắn: $e');
      _showSnackBar('Lỗi khi gửi tin nhắn: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_lastMessage == null || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final snapshot =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .startAfterDocument(_lastMessage!)
              .limit(_messageLimit)
              .get();

      if (mounted) {
        setState(() {
          _messageLimit += snapshot.docs.length;
          _lastMessage = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        _showSnackBar('Lỗi tải thêm tin nhắn: $e');
      }
    }
  }

  Future<void> _addMembers(
    String currentUserId,
    BuildContext context,
    StateSetter setDialogState,
  ) async {
    if (_selectedFriends.isEmpty) {
      _showSnackBar('Vui lòng chọn ít nhất một bạn bè');
      return;
    }

    final isAdmin = await _isCurrentUserAdmin(currentUserId);
    if (!isAdmin) {
      _showSnackBar('Chỉ trưởng nhóm mới có thể thêm thành viên');
      return;
    }

    setDialogState(() {
      _isLoading = true;
    });

    try {
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'members': FieldValue.arrayUnion(_selectedFriends)});

      // Gửi thông báo cho các thành viên mới được thêm
      final notificationFutures =
          _selectedFriends
              .where(
                (memberId) => memberId != currentUserId,
              ) // Loại trừ trưởng nhóm
              .map((memberId) async {
                try {
                  await NotificationService.sendChatEventNotification(
                    userId: memberId,
                    title: 'Thêm vào nhóm',
                    message:
                        'Bạn đã được thêm vào nhóm ${widget.conversationName}',
                    type: 'added',
                    conversationId: widget.conversationId,
                  );
                  print('Đã gửi thông báo cho thành viên mới: $memberId');
                } catch (e) {
                  print('Lỗi gửi thông báo cho user $memberId: $e');
                }
              })
              .toList();

      // Gửi thông báo cho trưởng nhóm (tùy chọn)
      try {
        await NotificationService.sendChatEventNotification(
          userId: currentUserId,
          title: 'Đã thêm thành viên',
          message:
              'Bạn đã thêm thành viên mới vào nhóm ${widget.conversationName}',
          type: 'admin_action',
          conversationId: widget.conversationId,
        );
        print('Đã gửi thông báo cho trưởng nhóm: $currentUserId');
      } catch (e) {
        print('Lỗi gửi thông báo cho trưởng nhóm $currentUserId: $e');
      }

      await Future.wait(notificationFutures);
      await _refreshMembersInfo();
      setDialogState(() {
        _selectedFriends.clear();
        _isLoading = false;
      });
      Navigator.pop(context);
      _showSnackBar('Thêm thành viên thành công');
    } catch (e) {
      setDialogState(() {
        _isLoading = false;
      });
      _showSnackBar('Lỗi khi thêm thành viên: $e');
    }
  }

  Future<void> _removeMember(
    String memberId,
    String memberName,
    StateSetter setDialogState,
  ) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'members': FieldValue.arrayRemove([memberId]),
            'admins': FieldValue.arrayRemove([memberId]),
          });

      await NotificationService.sendChatEventNotification(
        userId: memberId,
        title: 'Bị xóa khỏi nhóm',
        message: 'Bạn đã bị xóa khỏi nhóm ${widget.conversationName}',
        type: 'removed',
        conversationId: widget.conversationId,
      );

      final currentUserId = _auth.currentUser!.uid;
      await NotificationService.sendChatEventNotification(
        userId: currentUserId,
        title: 'Đã xóa thành viên',
        message: 'Bạn đã xóa $memberName khỏi nhóm ${widget.conversationName}',
        type: 'admin_action',
        conversationId: widget.conversationId,
      );

      await _refreshMembersInfo();
      setDialogState(() {});
      _showSnackBar('Xóa $memberName thành công');
    } catch (e) {
      _showSnackBar('Lỗi khi xóa thành viên: $e');
    }
  }

  Future<void> _confirmDisbandGroup(
    BuildContext context,
    String currentUserId,
    StateSetter setDialogState,
  ) async {
    final isAdmin = await _isCurrentUserAdmin(currentUserId);
    if (!isAdmin) {
      _showSnackBar('Chỉ trưởng nhóm được giải tán nhóm');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận giải tán nhóm'),
          content: Text(
            'Bạn có chắc chắn muốn giải tán nhóm ${widget.conversationName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Hủy',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final conversationDoc =
                      await _firestore
                          .collection('conversations')
                          .doc(widget.conversationId)
                          .get();
                  final members = List<String>.from(
                    conversationDoc.data()?['members'] ?? [],
                  );

                  final messagesSnapshot =
                      await _firestore
                          .collection('conversations')
                          .doc(widget.conversationId)
                          .collection('messages')
                          .get();

                  for (var message in messagesSnapshot.docs) {
                    await message.reference.delete();
                  }

                  await _firestore
                      .collection('conversations')
                      .doc(widget.conversationId)
                      .delete();

                  final notificationFutures =
                      members.where((member) => member != currentUserId).map((
                        member,
                      ) async {
                        try {
                          await NotificationService.sendChatEventNotification(
                            userId: member,
                            title: 'Nhóm đã giải tán',
                            message:
                                'Nhóm ${widget.conversationName} đã được giải tán.',
                            type: 'disband',
                            conversationId: widget.conversationId,
                          );
                        } catch (e) {
                          print('Lỗi gửi thông báo cho user $member: $e');
                        }
                      }).toList();

                  await Future.wait(notificationFutures);

                  if (mounted) {
                    //Đóng màn hình chat để về MessageScreen
                    Navigator.pop(context);
                    Navigator.pop(context);
                    _showSnackBar('Giải tán nhóm thành công');
                  }
                } catch (e) {
                  _showSnackBar('Lỗi khi giải tán: $e');
                }
              },
              child: const Text(
                'Giải tán',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignAdminRole(
    String memberId,
    String memberName,
    StateSetter setDialogState,
  ) async {
    final currentUserId = _auth.currentUser!.uid;
    final isAdmin = await _isCurrentUserAdmin(currentUserId);
    if (!isAdmin) {
      _showSnackBar('Chỉ trưởng nhóm được thêm trưởng nhóm');
      return;
    }

    try {
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'admins': FieldValue.arrayUnion([memberId]),
          });

      await NotificationService.sendChatEventNotification(
        userId: memberId,
        title: 'Bổ nhiệm trưởng nhóm',
        message:
            'Bạn đã được bổ nhiệm làm trưởng nhóm của ${widget.conversationName}',
        type: 'admin_assigned',
        conversationId: widget.conversationId,
      );

      await NotificationService.sendChatEventNotification(
        userId: currentUserId,
        title: 'Đã bổ nhiệm trưởng nhóm',
        message:
            'Bạn đã bổ nhiệm $memberName làm trưởng nhóm của ${widget.conversationName}',
        type: 'admin_action',
        conversationId: widget.conversationId,
      );

      await _refreshMembersInfo();
      setDialogState(() {});
      _showSnackBar('Thêm $memberName làm trưởng nhóm');
    } catch (e) {
      _showSnackBar('Lỗi khi thêm trưởng nhóm: $e');
    }
  }

  Future<void> _removeAdminRole(
    String memberId,
    String memberName,
    StateSetter setDialogState,
  ) async {
    final currentUserId = _auth.currentUser!.uid;
    final isAdmin = await _isCurrentUserAdmin(currentUserId);
    if (!isAdmin) {
      _showSnackBar('Chỉ trưởng nhóm mới có thể xóa quyền');
      return;
    }

    try {
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'admins': FieldValue.arrayRemove([memberId]),
          });

      await NotificationService.sendChatEventNotification(
        userId: memberId,
        title: 'Xóa quyền trưởng nhóm',
        message:
            'Quyền trưởng nhóm của bạn đã bị xóa từ ${widget.conversationName}',
        type: 'admin_removed',
        conversationId: widget.conversationId,
      );

      await NotificationService.sendChatEventNotification(
        userId: currentUserId,
        title: 'Đã xóa quyền trưởng nhóm',
        message:
            'Bạn đã xóa quyền trưởng nhóm của $memberName từ ${widget.conversationName}',
        type: 'admin_action',
        conversationId: widget.conversationId,
      );

      await _refreshMembersInfo();
      setDialogState(() {});
      _showSnackBar('Xóa quyền của $memberName');
    } catch (e) {
      _showSnackBar('Lỗi khi xóa quyền: $e');
    }
  }

  Future<void> _confirmRemoveMember(
    String memberId,
    String memberName,
    StateSetter setDialogState,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      _showSnackBar('Không thể xác định người dùng hiện tại');
      return;
    }

    final isAdmin = await _isCurrentUserAdmin(currentUserId);
    if (!isAdmin) {
      _showSnackBar('Chỉ trưởng nhóm mới có thể xóa thành viên');
      return;
    }

    if (memberId == currentUserId) {
      _showSnackBar('Bạn không thể tự xóa mình khỏi nhóm');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa thành viên'),
          content: Text('Bạn có chắc chắn muốn xóa $memberName khỏi nhóm?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close the confirmation dialog
                try {
                  await _removeMember(memberId, memberName, setDialogState);
                } catch (e) {
                  _showSnackBar('Lỗi khi xóa thành viên: $e');
                }
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileFriend(userId: userId)),
    );
  }
}

class ImageSelectionDialog extends StatefulWidget {
  final String currentAvatar;
  final String currentBackground;
  final String conversationId;
  final String conversationName;
  final List<String> members;
  final Function(String) onAvatarUpdated;
  final Function(String) onBackgroundUpdated;

  const ImageSelectionDialog({
    super.key,
    required this.currentAvatar,
    required this.currentBackground,
    required this.conversationId,
    required this.conversationName,
    required this.members,
    required this.onAvatarUpdated,
    required this.onBackgroundUpdated,
  });

  @override
  _ImageSelectionDialogState createState() => _ImageSelectionDialogState();
}

class _ImageSelectionDialogState extends State<ImageSelectionDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedAvatar;
  String _selectedBackground;

  // Danh sách tài nguyên ảnh, đồng bộ với CreateGroupDialog
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

  _ImageSelectionDialogState() : _selectedAvatar = '', _selectedBackground = '';

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatar;
    _selectedBackground = widget.currentBackground;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Chọn ảnh nhóm',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.4,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn ảnh đại diện:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _availableAvatars.isEmpty
                  ? const Text('Không có ảnh đại diện nào để chọn')
                  : SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _availableAvatars.length,
                      itemBuilder: (context, index) {
                        final avatar = _availableAvatars[index];
                        return GestureDetector(
                          onTap:
                              _isLoading
                                  ? null
                                  : () =>
                                      setState(() => _selectedAvatar = avatar),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _availableBackgrounds.isEmpty
                  ? const Text('Không có ảnh nền nào để chọn')
                  : SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: AssetImage(background),
                                  fit: BoxFit.cover,
                                  onError:
                                      (_, __) => const Icon(
                                        LineIcons.exclamationCircle,
                                      ),
                                ),
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
          onPressed: _isLoading ? null : _updateImages,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF63AB83),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                  : const Text(
                    'Cập nhật',
                    style: TextStyle(color: Colors.white),
                  ),
        ),
      ],
    );
  }

  Future<void> _updateImages() async {
    if (_selectedAvatar == widget.currentAvatar &&
        _selectedBackground == widget.currentBackground) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có thay đổi để cập nhật'),
          backgroundColor: Colors.grey,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final updates = <String, String>{};
      if (_selectedAvatar != widget.currentAvatar) {
        updates['avatarUrl'] = _selectedAvatar;
      }
      if (_selectedBackground != widget.currentBackground) {
        updates['backgroundUrl'] = _selectedBackground;
      }

      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update(updates);

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final futures =
          widget.members.where((member) => member != currentUserId).map((
            member,
          ) async {
            try {
              if (_selectedAvatar != widget.currentAvatar) {
                await NotificationService.sendChatEventNotification(
                  userId: member,
                  title: 'Cập nhật ảnh đại diện',
                  message:
                      'Ảnh đại diện nhóm ${widget.conversationName} đã được cập nhật',
                  type: 'avatar_updated',
                  conversationId: widget.conversationId,
                );
              }
              if (_selectedBackground != widget.currentBackground) {
                await NotificationService.sendChatEventNotification(
                  userId: member,
                  title: 'Cập nhật ảnh nền',
                  message:
                      'Ảnh nền nhóm ${widget.conversationName} đã được cập nhật',
                  type: 'background_updated',
                  conversationId: widget.conversationId,
                );
              }
            } catch (e) {
              print('Lỗi gửi FCM cho user $member: $e');
            }
          }).toList();

      if (_selectedAvatar != widget.currentAvatar) {
        await NotificationService.sendChatEventNotification(
          userId: currentUserId,
          title: 'Đã cập nhật ảnh đại diện',
          message:
              'Bạn đã cập nhật ảnh đại diện cho nhóm ${widget.conversationName}',
          type: 'admin_action',
          conversationId: widget.conversationId,
        );
      }
      if (_selectedBackground != widget.currentBackground) {
        await NotificationService.sendChatEventNotification(
          userId: currentUserId,
          title: 'Đã cập nhật ảnh nền',
          message:
              'Bạn đã cập nhật ảnh nền cho nhóm ${widget.conversationName}',
          type: 'admin_action',
          conversationId: widget.conversationId,
        );
      }

      await Future.wait(futures);

      if (mounted) {
        if (_selectedAvatar != widget.currentAvatar) {
          widget.onAvatarUpdated(_selectedAvatar);
        }
        if (_selectedBackground != widget.currentBackground) {
          widget.onBackgroundUpdated(_selectedBackground);
        }
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Cập nhật ảnh nhóm thành công'),
            backgroundColor: Color(0xFF63AB83),
          ),
        );
      }
    } catch (e) {
      print('Error updating group images: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

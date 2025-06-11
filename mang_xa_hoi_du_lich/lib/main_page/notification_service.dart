import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Lớp NotificationService để quản lý thông báo
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _permissionsRequested = false;

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null) {
          final payload = jsonDecode(response.payload!);
          if (payload['type'] == 'new_message') {
            final doc =
                await FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(payload['groupId'])
                    .get();
            final members = List<String>.from(doc.data()?['members'] ?? []);
            print('Navigate to chat: ${payload['groupId']}');
          }
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Thông báo quan trọng',
      description: 'Kênh này dùng cho thông báo tin nhắn và cập nhật nhóm.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      enableLights: true,
      showBadge: true,
      ledColor: Colors.blue,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRequested = prefs.getBool('permissions_requested') ?? false;

    if (!hasRequested) {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        final result = await Permission.notification.request();
        if (result.isDenied || result.isPermanentlyDenied) {
          print('Quyền thông báo bị từ chối');
        }
      }

      if (Platform.isAndroid) {
        final batteryStatus =
            await Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }

      await prefs.setBool('permissions_requested', true);
      _permissionsRequested = true;
    }
  }

  static Future<void> setupFirebaseMessaging() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          print('No authenticated user found for FCM setup');
          return;
        }

        String? token;
        for (int i = 0; i < 3; i++) {
          token = await _messaging.getToken();
          if (token != null) break;
          print('FCM token fetch attempt ${i + 1} failed, retrying...');
          await Future.delayed(const Duration(seconds: 2));
        }

        if (token != null) {
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid);
          final userDoc = await userRef.get();
          await userRef.set({
            'uid': currentUser.uid,
            'fcmToken': token,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('Saved FCM token for UID: ${currentUser.uid}');

          _messaging.onTokenRefresh.listen((newToken) async {
            if (FirebaseAuth.instance.currentUser != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .update({'fcmToken': newToken});
              print('Refreshed FCM token for UID: ${currentUser.uid}');
            }
          });
        } else {
          print(
            'Failed to obtain FCM token after retries for UID: ${currentUser.uid}',
          );
        }
      } else {
        print('FCM permission not granted: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('Error setting up Firebase Messaging: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Nhận FCM foreground: ${message.messageId}');
      showLocalNotification(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('Nhận FCM initial: ${initialMessage.messageId}');
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Mở ứng dụng từ thông báo: ${message.messageId}');
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    print('Nhận FCM background: ${message.messageId}');
    await showLocalNotification(message);
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      print(
        'Showing notification: ${notification.title} - ${notification.body}',
      );
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'Thông báo quan trọng',
        channelDescription:
            'Kênh này dùng cho thông báo tin nhắn và cập nhật nhóm.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        enableLights: true,
        ticker: 'ticker',
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(''),
      );
      const iosDetails = DarwinNotificationDetails(
        sound: 'notification.mp3',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: 'chat_thread',
        categoryIdentifier: 'NEW_MESSAGE',
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: jsonEncode({
          'groupId': message.data['groupId'],
          'groupName': message.data['groupName'],
          'type': message.data['type'],
        }),
      );
    } else {
      print('No notification data: ${message.data}');
    }
  }

  static Future<void> showSimpleNotification({
    String title = 'Thông báo',
    String body = 'Bạn có tin nhắn mới!',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Thông báo quan trọng',
      channelDescription:
          'Kênh này dùng cho thông báo tin nhắn và cập nhật nhóm.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      enableLights: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      sound: 'notification.mp3',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(0, title, body, notificationDetails);
  }

  static Future<void> listenToChatChanges(String conversationId) async {
    await Firebase.initializeApp();
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .listen((conversationSnapshot) async {
          print('Conversation snapshot triggered for $conversationId');
          if (!conversationSnapshot.exists) {
            print('Conversation deleted: $conversationId');
            return;
          }

          final data = conversationSnapshot.data();
          if (data == null) {
            print('Conversation data is null');
            return;
          }

          final members = List<String>.from(data['members'] ?? []);
          final admins = List<String>.from(data['admins'] ?? []);
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          if (currentUserId == null || !members.contains(currentUserId)) {
            print('Current user is null or not in members');
            return;
          }

          final previousMembers = List<String>.from(
            data['previousMembers'] ?? [],
          );
          final newMembers =
              members
                  .where((member) => !previousMembers.contains(member))
                  .toList();
          final removedMembers =
              previousMembers
                  .where((member) => !members.contains(member))
                  .toList();

          // Gửi thông báo cho thành viên mới
          for (var memberId in newMembers) {
            if (memberId != currentUserId) {
              print('Sending notification for new member: $memberId');
              await sendChatEventNotification(
                userId: memberId,
                title: 'Thêm vào nhóm',
                message:
                    'Bạn đã được thêm vào nhóm ${data['name'] ?? 'Nhóm chat'}',
                type: 'added',
                conversationId: conversationId,
              );
            }
          }

          // Gửi thông báo cho thành viên bị xóa
          for (var memberId in removedMembers) {
            print('Sending notification for removed member: $memberId');
            await sendChatEventNotification(
              userId: memberId,
              title: 'Bị xóa khỏi nhóm',
              message: 'Bạn đã bị xóa khỏi nhóm ${data['name'] ?? 'Nhóm chat'}',
              type: 'removed',
              conversationId: conversationId,
            );
          }

          // Cập nhật previousMembers
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .update({'previousMembers': members});
        });
  }

  static Future<void> sendChatEventNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String? conversationId,
  }) async {
    try {
      final token = await _getUserFCMToken(userId);
      if (token == null) {
        print('Không tìm thấy FCM token cho user: $userId, bỏ qua thông báo');
        return;
      }

      final serviceAccountJson = {
        //Thay thế bằng thông tin service account của bạn
        'type': 'service_account',
        'project_id': 'your-project-id',
        'private_key_id': 'your-private-key-id',
        'private_key':
            '-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n',
        'client_email': '',
      };
      final credentials = auth.ServiceAccountCredentials.fromJson(
        serviceAccountJson,
      );
      final projectId = serviceAccountJson['project_id'] as String;
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await auth.clientViaServiceAccount(credentials, scopes);
      try {
        final accessToken = (await client.credentials.accessToken).data;
        final url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
        );
        for (int i = 0; i < 2; i++) {
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'message': {
                'token': token,
                'notification': {
                  'title': title,
                  'body':
                      message.length > 100
                          ? '${message.substring(0, 97)}...'
                          : message,
                },
                'data': {
                  'type': type,
                  'groupId': conversationId ?? '',
                  'groupName': '',
                  'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                },
                'android': {
                  'priority': 'high',
                  'notification': {
                    'channel_id': 'high_importance_channel',
                    'icon': 'ic_notification',
                    'sound': 'notification',
                    'visibility': 'public',
                    'tag': type,
                  },
                },
                'apns': {
                  'headers': {'apns-priority': '10'},
                  'payload': {
                    'aps': {
                      'alert': {
                        'title': title,
                        'body':
                            message.length > 100
                                ? '${message.substring(0, 97)}...'
                                : message,
                      },
                      'sound': 'notification.mp3',
                      'badge': 1,
                      'category': 'NEW_MESSAGE',
                      'content-available': 1,
                    },
                  },
                },
              },
            }),
          );

          if (response.statusCode == 200) {
            print('Gửi FCM thành công for user $userId: ${response.body}');
            // Lưu thông báo vào Firestore
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': userId,
              'type': type,
              'message': message,
              'postId': conversationId ?? '',
              'fromUserId': FirebaseAuth.instance.currentUser?.uid ?? '',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
            break;
          } else if (response.statusCode == 404 &&
              response.body.contains('UNREGISTERED')) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .update({'fcmToken': FieldValue.delete()});
            print('Đã xóa FCM token không hợp lệ cho user: $userId');
            final newToken = await FirebaseMessaging.instance.getToken();
            if (newToken != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({'fcmToken': newToken});
              print('Refreshed FCM token for user: $userId');
              if (i < 1) continue;
            }
          } else {
            print(
              'Gửi FCM thất bại for user $userId: ${response.statusCode} - ${response.body}',
            );
          }
          if (i < 1) await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        print('Lỗi gửi HTTP request for user $userId: $e');
      } finally {
        client.close();
      }

      // Hiển thị thông báo cục bộ nếu ứng dụng ở foreground
      // final messageObj = RemoteMessage(
      //   notification: RemoteNotification(title: title, body: message),
      //   data: {'type': type, 'groupId': conversationId ?? '', 'groupName': ''},
      // );
      // await showLocalNotification(messageObj);
    } catch (e) {
      print('Lỗi gửi thông báo cho user $userId: $e');
    }
  }

  static Future<String?> _getUserFCMToken(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      if (!userDoc.exists) {
        print('User document does not exist for UID: $userId');
        return null;
      }
      final token = userDoc.data()?['fcmToken'] as String?;
      if (token == null) {
        print('FCM token is null for UID: $userId');
      }
      return token;
    } catch (e) {
      print('Lỗi lấy FCM token cho UID $userId: $e');
      return null;
    }
  }
}

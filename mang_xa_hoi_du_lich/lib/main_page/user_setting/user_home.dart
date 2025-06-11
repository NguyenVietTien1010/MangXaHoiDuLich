import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mang_xa_hoi_du_lich/login_register/auth_first.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/friend_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/user_profile.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/favorite_posts_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/memory_posts_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _photoUrl;
  String userName = "...";
  final _auth = FirebaseAuth.instance;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        setState(() {
          userName = doc.data()?['name'] ?? 'Người dùng';
        });
      }
    }
  }

  Future<void> _loadUserAvatar() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      setState(() {
        _photoUrl = doc.data()?['photoUrl'] ?? '';
      });
    }
  }

  Future<void> _showAvatarOptions() async {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text('Xem ảnh'),
                  onTap: () {
                    Navigator.pop(context);
                    _viewAvatar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('Tải ảnh mới'),
                  onTap: () {
                    Navigator.pop(context);
                    _selectImageSource();
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _viewAvatar() {
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      print("Không có ảnh avatar");
      return;
    }

    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Image.network(
                _photoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text('Không thể tải ảnh');
                },
              ),
            ),
          ),
    );
  }

  void _selectImageSource() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Chọn từ thư viện'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Chụp ảnh'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 75,
    );
    if (pickedFile == null) return;

    final File file = File(pickedFile.path);
    final storageRef = FirebaseStorage.instance.ref().child(
      'avatars/${user.uid}.jpg',
    );

    try {
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Cập nhật Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoUrl': downloadUrl},
      );

      setState(() {
        _photoUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật ảnh đại diện thành công')),
      );
    } catch (e) {
      print('Upload failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể cập nhật ảnh')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Header màu xanh
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  color: Color(0xFF63AB83),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                padding: const EdgeInsets.only(
                  top: 30,
                  left: 20,
                  right: 20,
                  bottom: 20,
                ),
                child: Row(
                  children: const [
                    Icon(Icons.touch_app, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Chạm\nLà Chạy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Để trống không gian dưới card nổi
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3,
                    children: const [
                      ProfileButton(
                        icon: Icons.info_outline,
                        text: 'Thông tin cá nhân',
                      ),
                      ProfileButton(
                        icon: Icons.photo_album_outlined,
                        text: 'Kỷ niệm',
                      ),
                      ProfileButton(icon: Icons.people_outline, text: 'Bạn bè'),
                      ProfileButton(
                        icon: Icons.bookmark_border,
                        text: 'Kho lưu trữ',
                      ),
                      ProfileButton(
                        icon: Icons.settings_outlined,
                        text: 'Cài đặt',
                      ),
                      ProfileButton(
                        icon: Icons.security_outlined,
                        text: 'Bảo mật',
                      ),
                      ProfileButton(
                        icon: Icons.help_outline,
                        text: 'Trợ giúp và phản hồi',
                      ),
                      ProfileButton(icon: Icons.logout, text: 'Đăng xuất'),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Card nổi lên chứa avatar và tên
          Positioned(
            top: 150,
            left: 50,
            right: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _showAvatarOptions,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage:
                              _photoUrl != null && _photoUrl!.isNotEmpty
                                  ? NetworkImage(_photoUrl!)
                                  : const AssetImage(
                                        'assets/default/default_avt.png',
                                      )
                                      as ImageProvider,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.green, width: 1.5),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.add_a_photo,
                            color: Colors.blue,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileButton extends StatelessWidget {
  final IconData icon;
  final String text;

  const ProfileButton({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          switch (text) {
            case 'Thông tin cá nhân':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen()),
              );
              break;
            case 'Kỷ niệm':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoryPostsScreen()),
              );
              break;
            case 'Bạn bè':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FriendScreen()),
              );
              break;
            case 'Kho lưu trữ':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritePostsScreen()),
              );
              break;
            case 'Cài đặt':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen()),
              );
              break;
            case 'Bảo mật':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen()),
              );
              break;
            case 'Trợ giúp và phản hồi':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen()),
              );
              break;
            case 'Đăng xuất':
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Xác nhận đăng xuất'),
                    content: const Text(
                      'Bạn có chắc chắn muốn đăng xuất không?',
                    ),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF63AB83),
                        ),
                        child: const Text('Hủy'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Color.fromARGB(255, 171, 99, 99),
                        ),
                        child: const Text('Đăng xuất'),
                        onPressed: () async {
                          Navigator.of(context).pop(); // Đóng dialog
                          try {
                            // Đăng xuất Google
                            final GoogleSignIn _googleSignIn = GoogleSignIn();
                            if (await _googleSignIn.isSignedIn()) {
                              await _googleSignIn.signOut();
                            }

                            // Đăng xuất Firebase
                            await FirebaseAuth.instance.signOut();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Đã đăng xuất")),
                            );
                            // Chuyển về màn hình đăng nhập
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const AuthFirst(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Lỗi đăng xuất: $e")),
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.black87),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

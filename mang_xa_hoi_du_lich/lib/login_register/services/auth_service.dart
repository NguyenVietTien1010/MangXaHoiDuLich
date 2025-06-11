import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // Người dùng hủy đăng nhập

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final user = userCredential.user;
      final email =
          user?.email ??
          googleUser.email; // Ưu tiên user.email, fallback là googleUser.email

      if (user != null) {
        // Kiểm tra xem user đã tồn tại trong Firestore chưa
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          // Nếu chưa có thì tạo mới
          await docRef.set({
            'name': user.displayName ?? "",
            'email': email,
            'photoUrl':
                user.photoURL ??
                "https://firebasestorage.googleapis.com/v0/b/mangxahoidulich-46e6f.firebasestorage.app/o/avatars%2Fdefault_avt.png?alt=media&token=566d3cbd-cce2-4c65-9ffc-3e3e5dbe2e8f",
            'birthday': "", // Chưa có ngày sinh
            'gender': "", // Chưa có giới tính
            'location': "", // Chưa có nơi ở
            'maritalStatus': "",
            'phone': "", // Chưa có số điện thoại,
          });
        }

        return user;
      }
    } catch (e) {
      print("Lỗi đăng nhập bằng Google: $e");
    }

    return null;
  }

  // static Future<User?> signInWithFacebook() async {
  //   try {
  //     // Đăng nhập bằng Facebook
  //     final LoginResult result = await FacebookAuth.instance.login();

  //     if (result.status == LoginStatus.success) {
  //       // Lấy Access Token của Facebook
  //       final accessToken = result.accessToken;

  //       // Sử dụng Access Token để đăng nhập với Firebase
  //       final facebookCredential = FacebookAuthProvider.credential(
  //         accessToken!.token,
  //       );
  //       UserCredential userCredential = await FirebaseAuth.instance
  //           .signInWithCredential(facebookCredential);
  //       final user = userCredential.user;

  //       if (user != null) {
  //         // Kiểm tra xem user đã tồn tại trong Firestore chưa
  //         final docRef = FirebaseFirestore.instance
  //             .collection('users')
  //             .doc(user.uid);
  //         final doc = await docRef.get();

  //         if (!doc.exists) {
  //           // Nếu chưa có thì tạo mới
  //           await docRef.set({
  //             'name': user.displayName ?? "",
  //             'email': user.email ?? "",
  //             'photoUrl': user.photoURL ?? "",
  //             'birthday': "", // Chưa có ngày sinh
  //             'gender': "", // Chưa có giới tính
  //             'location': "", // Chưa có nơi ở
  //             'maritalStatus': "", // Chưa có tình trạng hôn nhân
  //           });
  //         }

  //         return user;
  //       }
  //     }
  //   } catch (e) {
  //     print("Lỗi đăng nhập bằng Facebook: $e");
  //   }

  //   return null;
  // }
}

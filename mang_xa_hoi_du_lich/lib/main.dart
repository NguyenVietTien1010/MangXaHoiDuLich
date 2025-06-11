import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mang_xa_hoi_du_lich/login_register/auth_first.dart';
import 'package:mang_xa_hoi_du_lich/splash_screen/splash_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/notification_service.dart';
import 'package:mang_xa_hoi_du_lich/main_page/welcome_page/welcome_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mạng xã hội du lịch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF63AB83),
        scaffoldBackgroundColor: Colors.blueGrey.shade50,
        fontFamily: GoogleFonts.beVietnamPro().fontFamily,
        useMaterial3: true,
      ),
      home: const AppLauncher(),
      routes: {
        '/main':
            (context) => StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasData) return WelcomeScreen();
                return AuthFirst();
              },
            ),
      },
    );
  }
}

class AppLauncher extends StatefulWidget {
  const AppLauncher({super.key});

  @override
  State<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends State<AppLauncher> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(
      const Duration(milliseconds: 3000),
    ); // đảm bảo khung được render

    try {
      await Firebase.initializeApp();
      print("✅ Firebase đã kết nối thành công");

      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );

      print("✅ Firebase App Check đã được bật");

      await NotificationService.initialize();
      await NotificationService.setupFirebaseMessaging();

      print("✅ Dịch vụ thông báo đã được khởi tạo");

      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      print("❌ Lỗi khởi tạo Firebase: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   try {
//     await Firebase.initializeApp();
//     print("✅ Firebase đã kết nối thành công");
//   } catch (e) {
//     print("❌ Lỗi kết nối Firebase: $e");
//   }
//   runApp(MyApp());
// }

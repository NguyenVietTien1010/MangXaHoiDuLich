import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mang_xa_hoi_du_lich/login_register/login_screen.dart';
import 'package:mang_xa_hoi_du_lich/login_register/register_screen.dart';
import 'package:mang_xa_hoi_du_lich/login_register/services/auth_service.dart';
import 'package:mang_xa_hoi_du_lich/main_page/welcome_page/welcome_page.dart';

class AuthFirst extends StatefulWidget {
  const AuthFirst({super.key});

  @override
  State<AuthFirst> createState() => _AuthFirstState();
}

class _AuthFirstState extends State<AuthFirst> {
  bool isLogin = true;
  bool isLoading = false;

  void loginWithGoogle(BuildContext context) async {
    setState(() => isLoading = true);
    final user = await AuthService.signInWithGoogle();
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WelcomeScreen()),
      );
    }
    setState(() => isLoading = false);
  }

  void toggleForm() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF63AB83),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(bottom: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF63AB83),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(100),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 6,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                children: const [
                  Image(
                    image: AssetImage('assets/icon/vietnam.png'),
                    height: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "CHẠM LÀ CHẠY",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Khám phá vùng đất \nnghìn năm văn hiến",
                    style: TextStyle(
                      fontSize: 15,
                      color: Color.fromARGB(198, 255, 255, 255),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tabs Đăng nhập/Đăng ký
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLogin ? Colors.teal : Colors.grey.shade300,
                        foregroundColor: isLogin ? Colors.white : Colors.black,
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(56),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          isLogin = true;
                        });
                      },
                      child: const Text('Đăng nhập'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLogin ? Colors.grey.shade300 : Colors.teal,
                        foregroundColor: isLogin ? Colors.black : Colors.white,
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(56),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          isLogin = false;
                        });
                      },
                      child: const Text('Đăng ký'),
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.only(right: 20, left: 20, top: 10),
              child: isLogin ? LoginScreen() : RegisterScreen(),
            ),

            // Divider + Social Login
            const Divider(thickness: 1),
            const Center(
              child: Text("Hoặc", style: TextStyle(color: Colors.black54)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // IconButton(
                //   icon: Image.asset(
                //     'assets/icon/Facebook_Logo_2023.png',
                //     height: 30,
                //   ),
                //   onPressed: () {},
                // ),
                const SizedBox(width: 20),
                IconButton(
                  icon: Image.asset('assets/icon/google-logo.png', height: 30),
                  onPressed: () => loginWithGoogle(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading)
              Container(
                color: Colors.transparent,
                child: const Center(
                  child: SpinKitThreeBounce(color: Colors.black, size: 40),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

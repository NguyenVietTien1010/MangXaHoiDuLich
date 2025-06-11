import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mang_xa_hoi_du_lich/login_register/forgot_password_screen.dart';
import 'package:mang_xa_hoi_du_lich/login_register/otp_verification_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/welcome_page/welcome_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscureText = true;
  bool isLoading = false;

  void login(BuildContext context) async {
    setState(() => isLoading = true);

    final input = emailController.text.trim();
    final password = passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final phoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');

    if (emailRegex.hasMatch(input)) {
      // Đăng nhập bằng email & mật khẩu
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: password,
        );

        setState(() => isLoading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => WelcomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() => isLoading = false);
        String message = '';
        if (e.code == 'user-not-found') {
          message = 'Email không tồn tại.';
        } else if (e.code == 'wrong-password') {
          message = 'Mật khẩu không chính xác.';
        } else if (e.code == 'invalid-email') {
          message = 'Email không hợp lệ.';
        } else if (e.code == 'user-disabled') {
          message = 'Tài khoản đã bị vô hiệu hóa.';
        } else {
          message = 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } else if (phoneRegex.hasMatch(input)) {
      // Đăng nhập bằng phone auth với OTP, gọi màn OTP có callback
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber:
              input.startsWith('0')
                  ? '+84${input.substring(1)}'
                  : input, // Định dạng quốc tế
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Tự động đăng nhập nếu OTP auto lấy được
            await FirebaseAuth.instance.signInWithCredential(credential);
            setState(() => isLoading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => WelcomeScreen()),
            );
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Xác thực thất bại: ${e.message}')),
            );
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() => isLoading = false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => OTPVerificationScreen(
                      verificationId: verificationId,
                      onVerified: (credential) async {
                        setState(() => isLoading = true);
                        try {
                          await FirebaseAuth.instance.signInWithCredential(
                            credential,
                          );
                          setState(() => isLoading = false);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => WelcomeScreen()),
                          );
                        } catch (e) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi xác thực OTP: $e')),
                          );
                        }
                      },
                    ),
              ),
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      } catch (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã xảy ra lỗi khi xác thực số điện thoại."),
          ),
        );
      }
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email hoặc số điện thoại không hợp lệ")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // // Header with logo and text
            // Container(
            //   padding: const EdgeInsets.all(16.0),
            //   decoration: BoxDecoration(
            //     color: const Color(0xFF2E7D32), // Green background
            //     borderRadius: BorderRadius.circular(16.0),
            //   ),
            //   child: Column(
            //     children: [
            //       Image.network(
            //         'https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Flag_of_Vietnam.svg/1200px-Flag_of_Vietnam.svg.png',
            //         height: 40,
            //         width: 60,
            //       ),
            //       const SizedBox(height: 8),
            //       const Text(
            //         'CHÀM LÀ CHẠY',
            //         style: TextStyle(
            //           fontSize: 24,
            //           fontWeight: FontWeight.bold,
            //           color: Colors.white,
            //         ),
            //       ),
            //       const Text(
            //         'Khám phá vùng đất\nnghìn năm văn hiến',
            //         textAlign: TextAlign.center,
            //         style: TextStyle(fontSize: 16, color: Colors.white),
            //       ),
            //     ],
            //   ),
            // ),
            // const SizedBox(height: 32),
            const SizedBox(height: 32),
            // Input fields
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email hoặc số điện thoại',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Password input có nút bật/tắt hiển thị mật khẩu
            TextField(
              controller: passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Forgot Password link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ForgotPasswordScreen()),
                    ),
                child: const Text(
                  'Quên mật khẩu',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () => login(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26C6DA),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Đăng nhập',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

            // // Login and Register buttons
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     OutlinedButton(
            //       onPressed: () {
            //         Navigator.push(
            //           context,
            //           MaterialPageRoute(builder: (_) => RegisterScreen()),
            //         );
            //       },
            //       style: OutlinedButton.styleFrom(
            //         padding: const EdgeInsets.symmetric(
            //           horizontal: 32,
            //           vertical: 12,
            //         ),
            //         side: const BorderSide(color: Color(0xFF26C6DA)),
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(8),
            //         ),
            //       ),
            //       child: const Text(
            //         'Đăng ký',
            //         style: TextStyle(color: Color(0xFF26C6DA)),
            //       ),
            //     ),
            //     ElevatedButton(
            //       onPressed: () => login(context),
            //       style: ElevatedButton.styleFrom(
            //         backgroundColor: const Color(0xFF26C6DA),
            //         padding: const EdgeInsets.symmetric(
            //           horizontal: 32,
            //           vertical: 12,
            //         ),
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(8),
            //         ),
            //       ),
            //       child: const Text(
            //         'Đăng nhập',
            //         style: TextStyle(color: Colors.white),
            //       ),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 24),

            // // Divider with "Hoặc" text
            // const Row(
            //   children: [
            //     Expanded(child: Divider()),
            //     Padding(
            //       padding: EdgeInsets.symmetric(horizontal: 8.0),
            //       child: Text('Hoặc'),
            //     ),
            //     Expanded(child: Divider()),
            //   ],
            // ),
            // const SizedBox(height: 16),

            // // Social login buttons
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     IconButton(
            //       onPressed: () {
            //         // Add Facebook login logic if needed
            //       },
            //       icon: Image.network(
            //         'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Facebook_Logo_%282019%29.png/1200px-Facebook_Logo_%282019%29.png',
            //         height: 40,
            //         width: 40,
            //       ),
            //     ),
            //     const SizedBox(width: 16),
            //     IconButton(
            //       onPressed: () => loginWithGoogle(context),
            //       icon: Icon(Icons.g_mobiledata_rounded, size: 40),
            //     ),
            //   ],
            // ),
            // Layer loading
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

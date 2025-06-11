import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mang_xa_hoi_du_lich/login_register/auth_first.dart';
import 'package:mang_xa_hoi_du_lich/login_register/forgot_password_screen.dart';
import 'package:mang_xa_hoi_du_lich/login_register/login_screen.dart';
import 'package:mang_xa_hoi_du_lich/login_register/otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final contactController = TextEditingController(); // nhập email hoặc sđt
  final passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool isLoading = false;

  bool isPhoneNumber(String input) {
    final phoneReg = RegExp(r'^\+?[0-9]{9,15}$');
    return phoneReg.hasMatch(input);
  }

  void register(BuildContext context) async {
    String contact = contactController.text.trim();
    String password = passwordController.text.trim();
    String name = nameController.text.trim();
    setState(() => isLoading = true);

    if (name.isEmpty || contact.isEmpty || password.isEmpty) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")));
      return;
    }

    bool isPhoneNumber(String input) {
      final phoneReg = RegExp(r'^(0|\+84)[0-9]{8,14}$');
      return phoneReg.hasMatch(input);
    }

    String formatPhoneNumber(String input) {
      input = input.trim();
      if (input.startsWith('0')) {
        return '+84' + input.substring(1);
      } else if (!input.startsWith('+')) {
        return '+$input';
      }
      return input;
    }

    if (isPhoneNumber(contact)) {
      String formattedPhone = formatPhoneNumber(contact);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Đã đăng ký bằng số điện thoại")),
            );
          } catch (e) {
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Lỗi đăng nhập tự động: $e")),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Lỗi gửi OTP: ${e.message}")));
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
                      try {
                        UserCredential user = await FirebaseAuth.instance
                            .signInWithCredential(credential);

                        Map<String, dynamic> userData = {
                          'name': name,
                          'email': "",
                          'photoUrl':
                              "https://firebasestorage.googleapis.com/v0/b/mangxahoidulich-46e6f.firebasestorage.app/o/avatars%2Fdefault_avt.png?alt=media&token=566d3cbd-cce2-4c65-9ffc-3e3e5dbe2e8f",
                          'birthday': "",
                          'gender': "",
                          'location': "",
                          'maritalStatus': "",
                          'phone': formattedPhone,
                        };

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.user!.uid)
                            .set(userData);

                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Đăng ký thành công")),
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => AuthFirst()),
                        );
                      } catch (e) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Lỗi xác thực OTP: $e")),
                        );
                      }
                    },
                  ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } else {
      // Đăng ký email + password
      try {
        UserCredential user = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: contact, password: password);
        await user.user!.sendEmailVerification();

        Map<String, dynamic> userData = {
          'name': name,
          'email': contact,
          'photoUrl':
              "https://firebasestorage.googleapis.com/v0/b/mangxahoidulich-46e6f.firebasestorage.app/o/avatars%2Fdefault_avt.png?alt=media&token=566d3cbd-cce2-4c65-9ffc-3e3e5dbe2e8f",
          'birthday': "",
          'gender': "",
          'location': "",
          'maritalStatus': "",
          'phone': "",
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.user!.uid)
            .set(userData);

        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Vui lòng kiểm tra email để xác thực tài khoản"),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AuthFirst()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() => isLoading = false);
        String errorMessage;
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Email đã được sử dụng. Vui lòng chọn email khác.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Email không hợp lệ.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Mật khẩu quá yếu. Hãy thử mật khẩu mạnh hơn.';
        } else {
          errorMessage = 'Lỗi: ${e.message}';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      } catch (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi không xác định: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0),
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
            //         'CHẠM LÀ CHẠY',
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

            // Input fields
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: contactController,
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
            TextField(
              controller: passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
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

            ElevatedButton(
              onPressed: () => register(context),
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
                'Đăng ký',
                style: TextStyle(color: Colors.white),
              ),
            ),

            // // Register button
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     OutlinedButton(
            //       onPressed: () {
            //         Navigator.push(
            //           context,
            //           MaterialPageRoute(builder: (_) => LoginScreen()),
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
            //         'Đăng nhập',
            //         style: TextStyle(color: Color(0xFF26C6DA)),
            //       ),
            //     ),
            //     ElevatedButton(
            //       onPressed: () => register(context),
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
            //         'Đăng ký',
            //         style: TextStyle(color: Colors.white),
            //       ),
            //     ),
            //   ],
            // ),

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
            //       onPressed: () => AuthService.signInWithGoogle(),
            //       icon: Icon(Icons.g_mobiledata_rounded, size: 40),
            //     ),
            //   ],
            // ),
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

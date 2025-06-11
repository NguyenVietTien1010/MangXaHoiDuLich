/* -- Tính năng No Internet Screen -- */
// import 'package:flutter/material.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart';

// class NoInternetScreen extends StatelessWidget {
//   final VoidCallback onRetry;

//   const NoInternetScreen({super.key, required this.onRetry});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final Color primaryColor = const Color(0xFF63AB83);

//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Icon(Icons.wifi_off, size: 100, color: primaryColor),
//               const SizedBox(height: 16),
//               Text(
//                 'Mạng không ổn định',
//                 style: theme.textTheme.headlineSmall?.copyWith(
//                   fontWeight: FontWeight.w700,
//                   color: Colors.black87,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Hình như bạn đã mất kết nối mạng. Vui lòng kiểm tra lại Wi-Fi hoặc dữ liệu di động.',
//                 style: theme.textTheme.bodyLarge?.copyWith(
//                   color: Colors.grey[600],
//                   height: 1.4,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 32),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   onPressed: onRetry,
//                   icon: const Icon(Icons.refresh, color: Colors.white),
//                   label: const Text(
//                     'Thử lại',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: primaryColor,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     elevation: 2,
//                     shadowColor: Colors.black.withOpacity(0.2),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

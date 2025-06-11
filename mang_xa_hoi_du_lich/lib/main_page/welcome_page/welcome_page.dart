import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mang_xa_hoi_du_lich/login_register/auth_first.dart';
import 'package:mang_xa_hoi_du_lich/main_page/template.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String userName = '...';
  String currentLocation = 'Đang xác định vị trí...';
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserName();
    getCurrentLocation();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            currentLocation = 'Vui lòng cấp quyền truy cập vị trí';
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          currentLocation =
              '${place.subAdministrativeArea ?? ''}, ${place.administrativeArea ?? ''}';
          if (currentLocation.length > 30) {
            currentLocation = currentLocation.substring(0, 27) + '...';
          }
        });
      }
    } catch (e) {
      setState(() {
        currentLocation = 'Không thể xác định vị trí';
      });
    }
  }

  final List<Map<String, String>> travelTypes = [
    {
      "title": "Du lịch văn hóa",
      "image": "assets/images/culture.png",
      "type": "Văn hóa",
    },
    {
      "title": "Du lịch sinh thái",
      "image": "assets/images/ecotour.jpg",
      "type": "Sinh thái",
    },
    {
      "title": "Du lịch nghỉ dưỡng",
      "image": "assets/images/resort.jpg",
      "type": "Nghỉ dưỡng",
    },
    {
      "title": "Du lịch mạo hiểm",
      "image": "assets/images/adventure.jpg",
      "type": "Mạo hiểm",
    },
    {
      "title": "Du lịch ẩm thực",
      "image": "assets/images/cuisine.jpg",
      "type": "Ẩm thực",
    },
    {
      "title": "Du lịch tâm linh",
      "image": "assets/images/spiritual.jpg",
      "type": "Tâm linh",
    },
  ];

  void navigateToTemplate({String? travelType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatePage(selectedTravelType: travelType),
      ),
    );
  }

  void handleSearch() {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vui lòng nhập loại hình du lịch")),
      );
      return;
    }

    // Prioritize exact match on 'type', then 'title', then partial match
    final matchedType = travelTypes.firstWhere(
      (item) => item['type']!.toLowerCase() == query,
      orElse:
          () => travelTypes.firstWhere(
            (item) => item['title']!.toLowerCase() == query,
            orElse:
                () => travelTypes.firstWhere((item) {
                  final title = item['title']!.toLowerCase();
                  final type = item['type']!.toLowerCase();
                  return title.contains(query) || type.contains(query);
                }, orElse: () => {}),
          ),
    );

    if (matchedType.isNotEmpty) {
      navigateToTemplate(travelType: matchedType['type']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không tìm thấy loại hình du lịch phù hợp")),
      );
    }
  }

  void logout() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await FirebaseAuth.instance.signOut();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Đã đăng xuất")));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AuthFirst()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi đăng xuất: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter travel types for display in GridView
    final filteredTravelTypes =
        travelTypes.where((item) {
          final title = item['title']!.toLowerCase();
          final type = item['type']!.toLowerCase();
          final query = searchQuery.toLowerCase();
          return query.isEmpty || title.contains(query) || type.contains(query);
        }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent resizing when keyboard appears
      body: Stack(
        children: [
          // Hình tròn góc phải trên
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF63AB83),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Hình tròn góc trái dưới
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF63AB83),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16).copyWith(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    32, // Extra padding for keyboard
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: Icon(Icons.logout), onPressed: logout),
                        TextButton.icon(
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF63AB83),
                          ),
                          label: Text(
                            'Đăng bài mới',
                            style: TextStyle(color: Color(0xFF63AB83)),
                          ),
                          onPressed: () => navigateToTemplate(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Xin chào, $userName!',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            currentLocation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, size: 20),
                          onPressed: getCurrentLocation,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: "Tìm loại hình du lịch...",
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => handleSearch(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.search),
                            onPressed: handleSearch,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Chọn đúng trải nghiệm – Hành trình thêm ý nghĩa",
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () => navigateToTemplate(),
                        child: Text(
                          "Chọn chủ đề sau",
                          style: TextStyle(
                            color: Color(0xFF63AB83),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: filteredTravelTypes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 30,
                          ),
                      itemBuilder: (context, index) {
                        final item = filteredTravelTypes[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap:
                              () =>
                                  navigateToTemplate(travelType: item['type']),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      item['image']!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 100,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    item['title']!,
                                    style: GoogleFonts.beVietnamPro(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.15,
                    ), // Extra padding for grid visibility
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

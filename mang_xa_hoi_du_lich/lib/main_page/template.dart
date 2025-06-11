import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'package:mang_xa_hoi_du_lich/main_page/message/chat_with_friends.dart';
import 'package:mang_xa_hoi_du_lich/main_page/message/message_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/ai_chat/ai_chat_screen_openAI.dart';

import 'package:mang_xa_hoi_du_lich/main_page/post/post_news.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/post_upload_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/user_setting/user_home.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/favorite_posts_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/memory_posts_screen.dart';
import 'package:mang_xa_hoi_du_lich/main_page/ai_chat/ai_chat_screen.dart';

class TemplatePage extends StatefulWidget {
  final String? selectedTravelType; // Thêm tham số để nhận loại hình du lịch

  const TemplatePage({Key? key, this.selectedTravelType}) : super(key: key);

  @override
  _TemplatePageState createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  int _selectedIndex = 0;

  // Truyền selectedTravelType vào PostNews
  late final List<Widget> _pages = <Widget>[
    PostNews(selectedTravelType: widget.selectedTravelType),
    MessageScreen(),
    PostScreen(),
    AIChatScreen(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: GNav(
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              rippleColor: Colors.grey.shade300,
              hoverColor: Colors.grey.shade100,
              haptic: true,
              tabBorderRadius: 15,
              curve: Curves.fastOutSlowIn,
              duration: const Duration(milliseconds: 400),
              gap: 6,
              color: Colors.grey[600],
              activeColor: Colors.white,
              iconSize: 24,
              tabBackgroundColor: const Color(0xFF63AB83),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              tabs: const [
                GButton(icon: LineIcons.home, text: 'Trang chủ'),
                GButton(icon: LineIcons.heart, text: 'Trò chuyện'),
                GButton(icon: LineIcons.plusCircle, text: 'Thêm'),
                GButton(icon: LineIcons.robot, text: 'Dora'),
                GButton(icon: LineIcons.user, text: 'Cá nhân'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

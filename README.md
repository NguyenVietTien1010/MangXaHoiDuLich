# 🌍 ỨNG DỤNG MẠNG XÃ HỘI DU LỊCH 📱

> Một nền tảng kết nối cộng đồng đam mê khám phá, chia sẻ địa điểm và trải nghiệm du lịch!

---

## ✨ Giới thiệu

Ứng dụng **Mạng Xã Hội Du Lịch** được xây dựng nhằm tạo nên một không gian nơi người dùng có thể:
- 📸 Chia sẻ hình ảnh và cảm nhận về địa điểm du lịch
- 🗺️ Khám phá những địa điểm nổi bật thông qua bài đăng của cộng đồng
- 🧭 Đánh giá và bình luận về các địa điểm
- 👥 Kết nối và theo dõi những người bạn có cùng đam mê xê dịch

---

## 💡 Tính Năng Nổi Bật

- ✅ Đăng ký / đăng nhập người dùng
- 🖼️ Đăng bài kèm ảnh và vị trí địa lý
- 💬 Bình luận, thả tim và đánh giá bài viết
- 🔍 Tìm kiếm địa điểm, người dùng
- 📍 Bản đồ tích hợp vị trí địa điểm
- Trò chuyện cùng bạn bè, AI tích hợp

---

## 🛠️ Công Nghệ Sử Dụng

| Thành phần         | Công nghệ                    |
|--------------------|------------------------------|
| ⚙️ Backend          | Firebase  |
| 📱 Mobile App      | Flutter  |
| ☁️ Cơ sở dữ liệu    | Firebase Firestore  |
| 🖼️ Media Storage   | Firebase Storage  |
| 🗺️ Bản đồ & định vị | Google Maps API  |
| AI chat Bot          | Gemini 1.5  |

---

## 📷 Giao Diện Minh Họa

<p align="center">
  <img src="assets/home.png" width="18%">
  <img src="assets/post.png" width="18%">
  <img src="assets/chat.png" width="18%">
  <img src="assets/chat.jpg" width="18%">
  <img src="assets/profile.jpg" width="18%">
</p>

<p align="center">
  <strong>Trang chủ | Bài đăng | Trò chuyện | Chat Bot | Profile</strong>
</p>


## 👩‍💻 Nhóm Thực Hiện

- **Nguyễn Trường Duy** – Xây dựng hệ thống chat realtime, chatbot, thông báo sự kiện, tinh chỉnh giao diện. 
- **Nguyễn Viết Tiến**	- Trưởng nhóm, phân tích nghiệp vụ, vẽ sơ đồ phân rã chức năng, Xây dựng chức năng đăng bài, vẽ kiến trúc hệ thống.
- **Nguyễn Minh Khang** -	Xây dựng giao diện thông tin người dùng, lưu bài viết, kỷ niệm.
- **Nguyễn Hải Đăng** - Phân tích nghiệp vụ, vẽ sơ đồ usecase hệ thống, code chức năng đăng bài, vẽ kiến trúc hệ thống.
- **Bùi Kim Hải** - 	Xây dựng giao diện thông tin người dùng, lọc thể loại du lịch.

---

## 📆 Hướng phát triển
- Tích hợp thêm gợi ý địa điểm du lịch
- Màn hình DarkMode, tùy chỉnh cỡ chữ, kiểu chữ
- Đăng nhập bằng Facebook, Twitter,...
- Cho phép đăng video, đa hình ảnh trên bài viết, đoạn chat
- Tích hợp thời tiết, API ChatBot thông minh


---

## 🚀 Khởi Chạy Dự Án
 - File đẩy lên github đã xóa và thay thế toàn bộ API, để chạy được dự án, cần cấu hình lại Firebase, API Google Map, API Firebase Cloud Message, API Gemini, API OpenAI
```bash
git clone https://github.com/NguyenVietTien1010/MangXaHoiDuLich.git
cd Nhom7_Mobile_XayDungDeTaiQuanLyDanhGiaDuLich
flutter pub get
flutter run

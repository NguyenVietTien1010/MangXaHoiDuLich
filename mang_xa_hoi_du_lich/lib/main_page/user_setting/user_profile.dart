import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController();
  final birthdayController = TextEditingController();
  final genderController = TextEditingController();
  final locationController = TextEditingController();
  final maritalStatusController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String email = '';
  String phoneNumber = '';
  String? photoUrl;
  final user = FirebaseAuth.instance.currentUser;
  String? selectedGender;
  String? selectedMaritalStatus;
  final genderOptions = ['Nam', 'Nữ', 'Khác'];
  final maritalStatusOptions = ['Độc thân', 'Tìm hiểu', 'Hẹn hò', 'Đã kết hôn'];
  bool canEditEmail = true;
  bool canEditPhone = true;
  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    birthdayController.dispose();
    genderController.dispose();
    locationController.dispose();
    maritalStatusController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // Lấy dữ liệu người dùng từ Firestore
  void fetchUserData() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

    if (!doc.exists) {
      print("No document found for uid ${user!.uid}");
      return;
    }

    print("Document data: ${doc.data()}");

    setState(() {
      email = doc["email"];
      phoneNumber = doc['phone'];
      canEditEmail = email.isEmpty;
      canEditPhone = phoneNumber.isEmpty;

      nameController.text = doc['name'] ?? '';
      birthdayController.text = doc['birthday'] ?? '';
      emailController.text = email;
      phoneController.text = phoneNumber;
      locationController.text = doc['location'] ?? '';

      final gender = doc['gender'] ?? '';
      if (genderOptions.contains(gender) && gender.isNotEmpty) {
        selectedGender = gender;
      } else {
        selectedGender = null;
      }

      final marital = doc['maritalStatus'] ?? '';
      if (maritalStatusOptions.contains(marital) && marital.isNotEmpty) {
        selectedMaritalStatus = marital;
      } else {
        selectedMaritalStatus = null;
      }

      photoUrl = doc["photoUrl"] ?? '';
    });
  }

  void updateProfile() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
            'name': nameController.text,
            'birthday': birthdayController.text,
            'gender': selectedGender,
            'location': locationController.text,
            'maritalStatus': selectedMaritalStatus,
          });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Cập nhật thành công")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Lỗi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chỉnh sửa thông tin"),
        backgroundColor: const Color(0xFF6DB393),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  (photoUrl != null && photoUrl!.isNotEmpty)
                      ? NetworkImage(photoUrl!)
                      : const AssetImage('assets/default/default_avt.png')
                          as ImageProvider, // hoặc NetworkImage(...)
            ),
            const SizedBox(height: 10),
            buildTextField("Họ và tên", nameController),
            buildBirthdayField(),
            buildDropdownField("Giới tính", selectedGender, genderOptions, (
              value,
            ) {
              setState(() {
                selectedGender = value;
              });
            }),
            buildTextField("Địa chỉ", locationController),
            buildDropdownField(
              "Tình trạng hôn nhân",
              selectedMaritalStatus,
              maritalStatusOptions,
              (value) {
                setState(() {
                  selectedMaritalStatus = value;
                });
              },
            ),
            // Email và SĐT: kiểm tra quyền chỉnh sửa
            canEditEmail
                ? buildTextField("Email", emailController)
                : buildReadOnlyField("Email", emailController.text),
            canEditPhone
                ? buildTextField("Số điện thoại", phoneController)
                : buildReadOnlyField("Số điện thoại", phoneNumber),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6DB393),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text("Lưu thay đổi"),
            ),
          ],
        ),
      ),
    );
  }

  // Widget nhập liệu có thể chỉnh sửa
  Widget buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Widget hiển thị thông tin không cho chỉnh sửa (email, SĐT)
  Widget buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        enabled: false,
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Widget chọn ngày sinh bằng DatePicker
  Widget buildBirthdayField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: birthdayController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: "Ngày sinh",
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate:
                DateTime.tryParse(birthdayController.text) ?? DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (pickedDate != null) {
            String formattedDate =
                "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
            setState(() {
              birthdayController.text = formattedDate;
            });
          }
        },
      ),
    );
  }

  Widget buildDropdownField(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        items:
            options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Row(
                  children: [
                    Icon(_getIconForOption(option)),
                    const SizedBox(width: 8),
                    Text(option),
                  ],
                ),
              );
            }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        hint: Text("Chọn $label"),
      ),
    );
  }

  IconData _getIconForOption(String option) {
    switch (option) {
      case 'Nam':
        return Icons.male;
      case 'Nữ':
        return Icons.female;
      case 'Khác':
        return Icons.transgender;
      case 'Độc thân':
        return Icons.person;
      case 'Tìm hiểu':
        return Icons.search;
      case 'Hẹn hò':
        return Icons.favorite_border;
      case 'Đã kết hôn':
        return Icons.favorite;
      default:
        return Icons.help_outline;
    }
  }
}

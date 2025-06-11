import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mang_xa_hoi_du_lich/main_page/post/map_picker.dart';

class PostScreen extends StatefulWidget {
  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  LatLng? _selectedLocation;
  String? _userName;
  String? _userPhotoUrl;
  String _mapButtonText = 'Chọn trên bản đồ';
  String? _selectedTravelType;
  String? _selectedSatisfaction;
  GoogleMapController? _mapController; // Controller cho bản đồ preview

  final List<String> _travelTypes = [
    'Văn hóa',
    'Sinh thái',
    'Nghỉ dưỡng',
    'Mạo hiểm',
    'Ẩm thực',
    'Tâm linh',
  ];

  final List<String> _satisfactionLevels = [
    'Rất hài lòng',
    'Hài lòng',
    'Bình thường',
    'Chưa hài lòng',
    'Không hài lòng',
  ];

  final Color _primaryColor = const Color(0xFF63AB83);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (userDoc.exists) {
        setState(() {
          _userName = userDoc.data()?['name'] ?? 'Unknown User';
          _userPhotoUrl = userDoc.data()?['photoUrl'];
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_images')
          .child(fileName);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  Future<void> _submitPost() async {
    if (_titleController.text.isEmpty ||
        _contentController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _selectedImage == null ||
        _selectedTravelType == null ||
        _selectedSatisfaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final imageUrl = await _uploadImage(_selectedImage!);
    final user = FirebaseAuth.instance.currentUser;

    if (imageUrl != null && user != null) {
      await FirebaseFirestore.instance.collection('posts').add({
        'title': _titleController.text,
        'content': _contentController.text,
        'location': _locationController.text,
        'coordinates':
            _selectedLocation != null
                ? {
                  'latitude': _selectedLocation!.latitude,
                  'longitude': _selectedLocation!.longitude,
                }
                : null,
        'imageUrl': imageUrl,
        'userId': user.uid,
        'travelType': _selectedTravelType,
        'satisfaction': _selectedSatisfaction,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng bài thành công!')));

      _titleController.clear();
      _contentController.clear();
      _locationController.clear();
      setState(() {
        _selectedImage = null;
        _selectedLocation = null;
        _mapButtonText = 'Chọn trên bản đồ';
        _selectedTravelType = null;
        _selectedSatisfaction = null;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xảy ra lỗi khi đăng bài')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: SizedBox.shrink(),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        title: const Text(
          'Chạm Là Chạy',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Đăng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tiêu đề bài viết',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: Icon(Icons.title, color: _primaryColor),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage:
                              _userPhotoUrl != null
                                  ? NetworkImage(_userPhotoUrl!)
                                  : const AssetImage(
                                        'assets/default/default_avt.png',
                                      )
                                      as ImageProvider,
                          backgroundColor: Colors.grey[200],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _userName ?? 'Đang tải...',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapPickerScreen(),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  String placeName =
                                      result['placeName']?.toString().trim() ??
                                      '';
                                  if (placeName.isEmpty) {
                                    placeName =
                                        result['address']
                                            ?.toString()
                                            .split(',')
                                            .first
                                            .trim() ??
                                        'Không rõ địa điểm';
                                  }

                                  _locationController.text = placeName;
                                  _selectedLocation = result['coordinates'];
                                  _mapButtonText =
                                      placeName.length > 20
                                          ? '${placeName.substring(0, 20)}...'
                                          : placeName;
                                });
                              }
                            },
                            icon: Icon(Icons.map, color: _primaryColor),
                            label: Text(
                              _mapButtonText,
                              style: TextStyle(color: _primaryColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _primaryColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CustomDropdown(
                            hint: 'Loại hình du lịch',
                            value: _selectedTravelType,
                            items: _travelTypes,
                            onChanged:
                                (value) =>
                                    setState(() => _selectedTravelType = value),
                            primaryColor: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_selectedLocation != null)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GoogleMap(
                            key: ValueKey(
                              _selectedLocation,
                            ), // Buộc rebuild khi vị trí thay đổi
                            initialCameraPosition: CameraPosition(
                              target: _selectedLocation!,
                              zoom: 15,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('selected'),
                                position: _selectedLocation!,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen,
                                ),
                              ),
                            },
                            onMapCreated: (controller) {
                              _mapController = controller;
                              // Cập nhật camera ngay khi bản đồ được tạo
                              controller.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  _selectedLocation!,
                                  15,
                                ),
                              );
                            },
                            // Cập nhật camera khi vị trí thay đổi
                            onCameraIdle: () {
                              if (_mapController != null &&
                                  _selectedLocation != null) {
                                _mapController!.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    _selectedLocation!,
                                    15,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _contentController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Chia sẻ cảm nghĩ về hành trình vừa rồi...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: Icon(Icons.edit, color: _primaryColor),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image, color: _primaryColor),
                      label: Text(
                        'Thêm ảnh/Video',
                        style: TextStyle(color: _primaryColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _primaryColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _selectedImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          frameBuilder: (
                            context,
                            child,
                            frame,
                            wasSynchronouslyLoaded,
                          ) {
                            if (frame == null) {
                              return Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return child;
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _CustomDropdown(
                            hint: 'Trải nghiệm/Dịch vụ',
                            value: _selectedSatisfaction,
                            items: _satisfactionLevels,
                            onChanged:
                                (value) => setState(
                                  () => _selectedSatisfaction = value,
                                ),
                            primaryColor: _primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text(
                              'Hủy',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}

// Widget tùy chỉnh cho Dropdown
class _CustomDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final Color primaryColor;

  const _CustomDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(hint, style: TextStyle(color: Colors.grey[500])),
          ),
          isExpanded: true,
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_drop_down, color: primaryColor),
          ),
          dropdownColor: Colors.white,
          items:
              items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

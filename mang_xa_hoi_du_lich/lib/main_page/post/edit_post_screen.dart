import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditPostPage extends StatefulWidget {
  final DocumentSnapshot post;

  const EditPostPage({super.key, required this.post});

  @override
  _EditPostPageState createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _travelType;
  String? _imageUrl;
  File? _selectedImage;
  bool _isLoading = false;

  final List<String> _travelTypes = [
    'Văn hóa',
    'Sinh thái',
    'Nghỉ dưỡng',
    'Mạo hiểm',
    'Ẩm thực',
    'Tâm linh',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.post.data() as Map<String, dynamic>;
    _titleController = TextEditingController(text: data['title']);
    _contentController = TextEditingController(text: data['content']);
    _travelType = data['travelType'] ?? _travelTypes.first;
    _imageUrl = data['imageUrl'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
        _selectedImage = File(pickedFile.path);
      });

      try {
        final fileName =
            'post_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = await ref.putFile(_selectedImage!);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        setState(() {
          _imageUrl = downloadUrl;
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh lên: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePost() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề và nội dung')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedImageUrl = _imageUrl ?? widget.post['imageUrl'];

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'travelType': _travelType,
            'imageUrl': updatedImageUrl ?? '',
            'timestamp': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật bài viết thành công!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật bài viết: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF63AB83),
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa bài viết',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4A8B65),
        elevation: 0,
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Tiêu đề',
                            labelStyle: const TextStyle(
                              color: Color(0xFF4A8B65),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF4A8B65),
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _contentController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Nội dung',
                            labelStyle: const TextStyle(
                              color: Color(0xFF4A8B65),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF4A8B65),
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _travelType,
                          onChanged:
                              (value) => setState(() => _travelType = value!),
                          items:
                              _travelTypes
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ),
                                  )
                                  .toList(),
                          decoration: InputDecoration(
                            labelText: 'Loại hình du lịch',
                            labelStyle: const TextStyle(
                              color: Color(0xFF4A8B65),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF4A8B65),
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          dropdownColor: Colors.white,
                        ),
                        const SizedBox(height: 20),
                        if (_selectedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _imageUrl!,
                              height: 200,
                              fit: BoxFit.cover,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF4A8B65),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.image,
                            color: Color(0xFF4A8B65),
                          ),
                          label: const Text(
                            'Chọn ảnh',
                            style: TextStyle(color: Color(0xFF4A8B65)),
                          ),
                          onPressed: _pickImage,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFF4A8B65),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            'Cập nhật bài viết',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _updatePost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A8B65),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}

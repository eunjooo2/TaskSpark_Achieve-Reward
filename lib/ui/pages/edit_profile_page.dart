import 'dart:io';

import 'package:flutter/material.dart'; 
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../data/user.dart';
import '../../service/user_service.dart';

class EditProfilePage extends StatefulWidget {
  final User user;
  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _tagController;
  File? _selectedImage;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _tagController = TextEditingController(text: widget.user.tag?.toString());
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        await UserService().updateUserProfile(
          userId: widget.user.id!,
          name: _nameController.text.trim(),
          tag: _tagController.text.trim(),
          avatarFile: _selectedImage,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              content: Text("프로필이 성공적으로 업데이트되었습니다.")),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              content: Text("업데이트 실패: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 편집')),
      body: Padding(
        padding: EdgeInsets.all(4.w),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6)
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : widget.user.avatar != null &&
                                  widget.user.avatar!.isNotEmpty
                              ? NetworkImage(
                                  "https://pb.aroxu.me/${widget.user.avatar!}")
                              : const AssetImage(
                                      "assets/images/default_profile.png")
                                  as ImageProvider,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  margin: EdgeInsets.only(bottom: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade600),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'UID: ${widget.user.id ?? "없음"}',
                          style:
                              TextStyle(fontSize: 16.sp, color: Colors.white70),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy,
                            size: 20, color: Colors.white70),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.user.id ?? ''),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UID가 복사되었습니다.')),
                          );
                        },
                      )
                    ],
                  ),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "이름 (5자 이내)"),
                  maxLength: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length > 5) {
                      return "이름은 5자 이내여야 합니다.";
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _tagController,
                  decoration:
                      const InputDecoration(labelText: "태그 (숫자 5자리 이하)"),
                  maxLength: 5,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "태그를 입력하세요.";
                    }
                    final tag = int.tryParse(value);
                    if (tag == null || tag < 0 || value.length > 5) {
                      return "숫자 형식의 5자리 이하 태그여야 합니다.";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 4.h),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text("저장"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

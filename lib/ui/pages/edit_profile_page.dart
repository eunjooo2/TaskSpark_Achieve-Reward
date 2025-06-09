import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../data/user.dart';
import '../../service/user_service.dart';

// 2025. 06. 07 : 프로필 편집 화면 추가(권한 요청 필요)
// - 이름, 태그 업데이트 적용 테스트 완료
// - 아바타 업데이트 구현 필요
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
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 10.w,
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
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                margin: EdgeInsets.only(bottom: 2.h),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 18, 13, 8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'UID: ${widget.user.id ?? "없음"}',
                      style: TextStyle(fontSize: 16.sp), // fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: 8.w,
                      height: 8.w,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 43, 36, 21),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.user.id ?? ''),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UID가 복사되었습니다.')),
                          );
                        },
                        child: const Icon(Icons.copy, size: 20),
                      ),
                    ),
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
                decoration: const InputDecoration(labelText: "태그 (숫자 5자리 이하)"),
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
              ElevatedButton(
                onPressed: _submit,
                child: const Text("저장"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

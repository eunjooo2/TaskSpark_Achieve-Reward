// 📁 ui/widgets/category_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../data/category.dart';
import '../../service/category_service.dart';

class CategoryFormDialog extends StatefulWidget {
  final CategoryService categoryService;
  final Category? categoryToEdit;
  final VoidCallback onSuccess;

  const CategoryFormDialog({
    super.key,
    required this.categoryService,
    this.categoryToEdit,
    required this.onSuccess,
  });

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _emojiCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  bool get _isEditMode => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    final c = widget.categoryToEdit;
    if (c != null) {
      _emojiCtrl.text = c.emoji ?? '';
      _nameCtrl.text = c.name ?? '';
      _colorCtrl.text = c.color ?? '';
    }
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final emoji = _emojiCtrl.text.trim();
    final color = _colorCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack("이름은 필수입니다.");
      return;
    }
    if (emoji.isNotEmpty && emoji.runes.length != 1) {
      _showSnack("이모지는 하나만 입력해주세요.");
      return;
    }
    if (color.isNotEmpty &&
        !RegExp(r'^#[0-9A-F]{6}$', caseSensitive: false).hasMatch(color)) {
      _showSnack("색상 코드는 #RRGGBB 형식이어야 합니다.");
      return;
    }

    try {
      if (_isEditMode) {
        await widget.categoryService.updateCategory(
          widget.categoryToEdit!.id!,
          {"name": name, "emoji": emoji, "color": color},
        );
      } else {
        await widget.categoryService.createCategory(
          Category(name: name, emoji: emoji, color: color),
        );
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack("저장 실패: $e");
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("삭제 확인"),
        content: const Text("정말 이 카테고리를 삭제하시겠습니까?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("취소")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("삭제")),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.categoryService.deleteCategory(widget.categoryToEdit!.id!);
        widget.onSuccess();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        _showSnack("삭제 실패: $e");
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? "카테고리 수정" : "카테고리 추가"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
                controller: _emojiCtrl,
                decoration: const InputDecoration(labelText: "이모지 (예: 📚)")),
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "카테고리 이름")),
            TextField(
                controller: _colorCtrl,
                decoration:
                    const InputDecoration(labelText: "색상 코드 (#RRGGBB)")),
            if (_isEditMode)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label:
                        const Text("삭제", style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text("취소")),
        TextButton(onPressed: _submit, child: const Text("저장")),
      ],
    );
  }
}

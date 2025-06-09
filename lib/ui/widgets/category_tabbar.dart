import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import '../../data/category.dart';
import '../../service/category_service.dart';
import 'category_form.dart';

class CategoryTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final VoidCallback onRefreshCategories;
  final CategoryService categoryService;

  const CategoryTabBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onRefreshCategories,
    required this.categoryService,
  });

  void _openAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        categoryService: categoryService,
        onSuccess: onRefreshCategories,
      ),
    );
  }

  void _openEditDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        categoryService: categoryService,
        categoryToEdit: category,
        onSuccess: onRefreshCategories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip(
                context: context,
                label: "전체",
                borderColor: "#CCBBAA",
                selected: selectedCategoryId == null,
                onSelected: () => onCategorySelected(null),
              ),
              const SizedBox(width: 6),
              ...categories.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onLongPress: () => _openEditDialog(context, c),
                      child: _buildChip(
                        context: context,
                        label: "${c.emoji ?? ''} ${c.name}",
                        borderColor: c.color,
                        selected: selectedCategoryId == c.id,
                        onSelected: () => onCategorySelected(c.id),
                      ),
                    ),
                  )),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Icon(Icons.add, size: 18),
                selected: false,
                onSelected: (_) => _openAddDialog(context),
                backgroundColor: Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    String? borderColor,
  }) {
    // #RRGGBB 형식의 문자열을 Color 로 변환
    Color parseHexColor(String hex) {
      // "FF" 알파값을 붙여서 0xFFRRGGBB 로
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    }

    // 유효한 hex 문자열일 때만 파싱, 아니면 투명 처리
    final Color borderClr = (borderColor != null &&
            RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(borderColor))
        ? parseHexColor(borderColor)
        : Colors.transparent;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.white,
      backgroundColor: Colors.grey[300],
      // 여기에 border 적용
      shape: StadiumBorder(
        side: BorderSide(color: borderClr, width: 2),
      ),
      labelStyle: TextStyle(
        color:
            selected ? Theme.of(context).colorScheme.primary : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

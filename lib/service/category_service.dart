import 'package:pocketbase/pocketbase.dart';
import '../data/category.dart';
import '../util/secure_storage.dart';
import 'package:task_spark/service/achievement_service.dart';

class CategoryService {
  final PocketBase pb;

  CategoryService(this.pb);

  /// 로그인한 사용자의 모든 카테고리를 불러옵니다.
  Future<List<Category>> getAllCategories() async {
    final userId = await SecureStorage().storage.read(key: "userID");

    final result = await pb.collection('category').getFullList(
          filter: "user.id='$userId'",
          sort: "-created",
        );

    return result.map(Category.fromRecord).toList();
  }

  /// 카테고리 ID로 단일 카테고리를 조회합니다.
  Future<Category?> getCategoryById(String id) async {
    try {
      final record = await pb.collection('category').getOne(id);
      return Category.fromRecord(record);
    } catch (_) {
      return null;
    }
  }

  /// 새 카테고리를 생성합니다.
  Future<Category> createCategory(Category category) async {
    final userId = await SecureStorage().storage.read(key: "userID");

    final body = {
      "user": userId,
      ...category.toJson(),
    };

    final record = await pb.collection('category').create(body: body);
    return Category.fromRecord(record);
  }

  /// 카테고리를 수정합니다.
  Future<Category> updateCategory(String id, Map<String, dynamic> data) async {
    final body = <String, dynamic>{
      if (data.containsKey("name")) "name": data["name"],
      if (data.containsKey("emoji")) "emoji": data["emoji"],
      if (data.containsKey("color")) "color": data["color"],
    };

    final record = await pb.collection('category').update(id, body: body);

    // 업적 연동: category_sort_use
    await AchievementService().increaseAchievement('category_sort_use');

    return Category.fromRecord(record);
  }

  /// 카테고리를 삭제합니다.
  Future<void> deleteCategory(String id) async {
    await pb.collection('category').delete(id);
  }
}

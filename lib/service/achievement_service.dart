import 'package:task_spark/data/achievement.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/util/pocket_base.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/data/reward_processor.dart';

class AchievementService {
  // 업적 정렬: 등급 판별
  String getCurrentTierKey(int userValue, Achievement achievement) {
    for (final tier in ['diamond', 'platinum', 'gold', 'silver', 'bronze']) {
      final required = achievement.amount[tier];
      if (required != null && userValue >= required) {
        return tier;
      }
    }
    return 'none';
  }

  Future<List<Achievement>> getAchievementList() async {
    return (await PocketB().pocketBase.collection("achievement").getFullList())
        .map((e) => Achievement.fromRecord(e))
        .toList();
  }

  Future<Map<String, int>> getUserValues(String userId) async {
    final result =
        await PocketB().pocketBase.collection('user_achievement').getFullList(
              filter: 'user.id="$userId"',
              expand: 'achievement',
            );
    final Map<String, int> userValues = {};

    for (final record in result) {
      final metadata = record.data['metadata'] as Map<String, dynamic>?;

      if (metadata == null) continue;

      final String? type = metadata['type'];
      final int? currentValue = metadata['currentValue'];

      if (type == null || currentValue == null) continue;

      userValues[type] = currentValue > (userValues[type] ?? 0)
          ? currentValue
          : userValues[type]!;
    }

    return userValues;
  }

  Future<List<String>> getAchieType() async {
    return (await getAchievementList()).map((e) => e.type).toList();
  }

  ///  메타데이터 값 1 증가시키고, 업적 조건에 부합하면 보상 지급
  Future<void> updateMetaDataWithKey(String key, int value) async {
    final user = await UserService().getProfile();
    final achievements = user.metadata?["achievements"] ?? {};
    final oldValue = achievements[key] ?? 0;
    final newValue = oldValue + value;

    achievements[key] = newValue;
    user.metadata?["achievements"] = achievements;

    //  업적 객체 불러오기
    final allAchievements = await getAchievementList();
    final matched = allAchievements.where((e) => e.type == key);
    for (final achievement in matched) {
      await checkAndRewardIfUpgraded(
        user: user,
        achievement: achievement,
        oldValue: oldValue,
        newValue: newValue,
      );
    }

    await PocketB().pocketBase.collection("users").update(user.id ?? "", body: {
      "metadata": user.metadata,
    });
  }

  Future<Map<String, int>> getCurrentMetaData() async {
    final user = await UserService().getProfile();
    final dynamic rawAchievements = user.metadata?["achievements"];
    return Map<String, int>.from(rawAchievements ?? {});
  }

  /// [업적 증가 전용 ]
  Future<void> increaseAchievement(String key) async {
    await updateMetaDataWithKey(key, 1);
  }

  ///  업적 등급 인덱스 반환 (0: 없음 ~ 5: 다이아)
  int getCurrentTierIndex(
      Map<String, int> userValues, Achievement achievement) {
    final currentValue = userValues[achievement.type] ?? 0;
    final bronzeValue = achievement.amount["bronze"] ?? 0;
    final silverValue = achievement.amount["silver"] ?? 0;
    final goldValue = achievement.amount["gold"] ?? 0;
    final platinumValue = achievement.amount["platinum"] ?? 0;
    final diamondValue = achievement.amount["diamond"] ?? 0;

    if (achievement.isOnce == true) {
      return currentValue >= diamondValue ? 5 : 0;
    }

    if (currentValue < bronzeValue) return 0;
    if (currentValue < silverValue) return 1;
    if (currentValue < goldValue) return 2;
    if (currentValue < platinumValue) return 3;
    if (currentValue < diamondValue) return 4;
    return 5;
  }

  /// 업적 진행률 계산 (0.0 ~ 1.0)
  double getProgress(int currentValue, Achievement achievement) {
    if (achievement.isOnce == true) {
      return currentValue >= (achievement.amount["diamond"] ?? 0) ? 1.0 : 0.0;
    }

    final start = achievement.amount["bronze"] ?? 1;
    final end = achievement.amount["diamond"] ?? 100;

    return ((currentValue - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// 등급 상승 시 보상 지급
  Future<void> checkAndRewardIfUpgraded({
    required User user,
    required Achievement achievement,
    required int oldValue,
    required int newValue,
  }) async {
    final oldTierIndex =
        getCurrentTierIndex({achievement.type: oldValue}, achievement);
    final newTierIndex =
        getCurrentTierIndex({achievement.type: newValue}, achievement);

    if (newTierIndex > oldTierIndex) {
      final tierName = [
        'no_tier',
        'bronze',
        'silver',
        'gold',
        'platinum',
        'diamond'
      ][newTierIndex];
      RewardProcessor.grantReward(
        achievement: achievement,
        tier: tierName,
        user: user,
      );
    }
  }
}

import 'package:task_spark/data/achievement.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/service/achievement_service.dart';
 
/// 업적 보상 지급 유틸리티 (경험치, 아이템)
class RewardProcessor {
  /// 보상 지급: 업적 객체와 등급명 전달 (e.g. 'bronze')
  static void grantReward({
    required Achievement achievement,
    required String tier,
    required User user,
  }) async {
    final rewardData = achievement.reward?[tier.toLowerCase()];
    if (rewardData == null) return;

    // 경험치 보상 지급
    if (rewardData.containsKey('exp')) {
      final expAmount = rewardData['exp'] as int;
      user.exp = (user.exp ?? 0) + expAmount;
      print('[보상 지급] 경험치 +$expAmount');
    }

    // 아이템 보상 지급
    if (rewardData.containsKey('items')) {
      final List<dynamic> items = rewardData['items'];
      for (final item in items) {
        final String id = item['id'];
        final int amount = item['amount'];

        // inventory가 null일 경우 초기화
        user.inventory ??= {};
        final current = user.inventory![id] ?? 0;
        user.inventory![id] = current + amount;

        print('[보상 지급] 아이템 $id x$amount');

        // 업적: 도전장 사용 업적
        if (id == "라이벌 신청권") {
          await AchievementService()
              .updateMetaDataWithKey("rival_challenge", amount);
          print("[업적] rival_challenge +$amount");
        }

        //  업적: 경험치 부스트 아이템 사용
        if (id == "경험치 부스트") {
          await AchievementService().increaseAchievement("use_boost_item");
          print("[업적] use_boost_item +1");
        }

        //  업적: 방어권 아이템 사용
        if (id == "방어권") {
          await AchievementService().increaseAchievement("use_shield_item");
          print("[업적] use_shield_item +1");
        }

        //  경험치 및 레벨 메타데이터 갱신
        user.updateExpAndLevel();

        // 서버에 업데이트 반영
        await UserService().updateUserByID(user.id!, {
          "exp": user.exp,
          "metadata": user.metadata,
          "inventory": user.inventory,
        });
        print('[서버 반영 완료] 경험치 및 메타데이터');
      }
    }
  }
}

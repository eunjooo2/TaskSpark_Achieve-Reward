import 'package:flutter/material.dart';
import 'package:task_spark/data/item.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/data/achievement.dart';
import 'package:task_spark/service/achievement_service.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:task_spark/service/item_service.dart';
import 'package:task_spark/ui/widgets/achievement_tile.dart';
import 'package:task_spark/util/pocket_base.dart';

class AchievementPage extends StatefulWidget {
  final String nickname;
  final num expRate;
  final User myUser;

  const AchievementPage({
    super.key,
    required this.nickname,
    required this.expRate,
    required this.myUser,
  });

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  List<Achievement> achievements = [];
  bool isLoading = true;
  Map<String, int> userValues = {};
  Map<String, Item> itemMap = {};

  @override
  void initState() {
    super.initState();
    _fetchAchiv();
  }

  bool _userHasUnlocked(Achievement achievement) {
    final currentValue = userValues[achievement.type] ?? 0;
    // 해금 조건: 해당 업적의 등급 중 하나라도 만족하면 true
    for (final tier in ['bronze', 'silver', 'gold', 'platinum', 'diamond']) {
      final required = achievement.amount[tier];
      if (required != null && currentValue >= required) {
        return true;
      }
    }
    return false;
  }

  Future<void> _fetchAchiv() async {
    final achivResult = await AchievementService().getAchievementList();
    final userMetaData = await AchievementService().getCurrentMetaData();
    final itemList = await ItemService(PocketB().pocketBase).getAllItems();
    final itemMapData = {for (var item in itemList) item.id: item};

    setState(() {
      achievements = achivResult;
      userValues = userMetaData;
      itemMap = itemMapData;
      isLoading = false;
    });

    setState(() {
      achievements = achivResult;
      isLoading = false;
      userValues = userMetaData;
    });

    print("📦 불러온 아이템 수: ${itemList.length}");
  }

  void _showHelpDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.infoReverse,
      animType: AnimType.rightSlide,
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 3.w),
        child: Text(
          '비공개 업적을 누르면 힌트가 보여요!',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
      btnOkText: "확인",
      btnOkOnPress: () {},
    ).show();
  }

  void _showHintDialog(BuildContext context, Achievement achievement) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      dialogType: DialogType.question,
      body: Column(
        children: [
          Text(
            "업적 힌트",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  "${achievement.hint}",
                  style: TextStyle(fontSize: 15.sp),
                ),
              ),
              SizedBox(width: 10.w),
            ],
          ),
          SizedBox(height: 3.h),
        ],
      ),
      showCloseIcon: true,
    ).show();
  }

  void _showRewardDialog(BuildContext context, Achievement achievement) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      dialogType: DialogType.infoReverse,
      showCloseIcon: true,
      body: Padding(
        padding: EdgeInsets.all(2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '"${achievement.title}" 보상 정보',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // 티어별 보상 표시
            ...["bronze", "silver", "gold", "platinum", "diamond"].map((tier) {
              final rewardData = achievement.reward?[tier];
              if (rewardData == null) return SizedBox.shrink();

              List<Widget> rewardWidgets = [];

              // 경험치 보상
              if (rewardData["exp"] != null) {
                rewardWidgets.add(
                  Text("• $tier: 경험치 ${rewardData["exp"]}XP",
                      style: TextStyle(fontSize: 15.sp)),
                );
              }

              // 아이템 보상
              if (rewardData["items"] != null && rewardData["items"] is List) {
                for (var item in rewardData["items"]) {
                  final String itemId = item["id"];
                  final int amount = item["amount"];
                  final String itemName = itemMap[itemId]?.title ?? itemId;

                  rewardWidgets.add(
                    Text("• $tier: $itemName × $amount",
                        style: TextStyle(fontSize: 15.sp)),
                  );
                }
              }
              print("🎯 보상 아이템 ID들:");
              if (rewardData["items"] != null) {
                for (var item in rewardData["items"]) {
                  final itemId = item["id"];
                  print("🆔 $itemId → ${itemMap[itemId]?.title}");
                }
              }

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 0.5.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rewardWidgets,
                ),
              );
            }).toList(),
          ],
        ),
      ),
      btnOkText: "확인",
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final visibleAchievements = achievements.where((a) {
      if (!a.isHidden) return true;
      return _userHasUnlocked(a); // 히든 업적도 해금됐으면 포함
    }).toList();
    visibleAchievements.sort((a, b) {
      final userValueA = userValues[a.type] ?? 0;
      final userValueB = userValues[b.type] ?? 0;

      final tierA = AchievementService().getCurrentTierKey(userValueA, a);
      final tierB = AchievementService().getCurrentTierKey(userValueB, b);
      final progressA = AchievementService().getProgress(userValueA, a);
      final progressB = AchievementService().getProgress(userValueB, b);

      // 1. 히든 > 해금된 일회성 > 해금된 일반 > 해금 안된(any)
      int priority(Achievement ach, String tier) {
        if (ach.isHidden && tier == 'none') return 0; // 미해금 히든
        if (tier == 'none') return 3; // 미해금 일반
        if (ach.isOnce) return 1; // 해금 일회성
        return 2; // 해금 일반
      }

      // 1) priority 비교
      final pA = priority(a, tierA);
      final pB = priority(b, tierB);
      final priorityCompare = pA.compareTo(pB);
      if (priorityCompare != 0) return priorityCompare;

      // 2) 등급 우선순위(다이아 > 플래티넘 > … > none) – 여기서 none 은 이미 뒤로 밀렸으므로 사실상 등급 비교는 해금된 것들끼리만 합니다.
      int tierValue(String t) => {
            'diamond': 5,
            'platinum': 4,
            'gold': 3,
            'silver': 2,
            'bronze': 1,
            'none': 0,
          }[t]!;
      final tierCompare = tierValue(tierB).compareTo(tierValue(tierA));
      if (tierCompare != 0) return tierCompare;

      // 3) 진행률 높은 순
      final progressCompare = progressB.compareTo(progressA);
      if (progressCompare != 0) return progressCompare;

      // 4) 누적값 높은 순
      return userValueB.compareTo(userValueA);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('업적 리스트',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: BackButton(
          onPressed: () => Navigator.pop(context, true),
          color: Theme.of(context).colorScheme.secondary,
        ),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.circleQuestion),
            color: Theme.of(context).colorScheme.secondary,
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: visibleAchievements.length,
                    itemBuilder: (context, index) {
                      final achievement = visibleAchievements[index];
                      final int userValue = userValues[achievement.type] ?? 0;
                      final isHint = !_userHasUnlocked(achievement);

                      return AchievementTile(
                        achievement: achievement,
                        currentValue: userValue,
                        isUnlocked: _userHasUnlocked(achievement),
                        onTap: () {
                          isHint
                              ? _showHintDialog(context, achievement)
                              : _showRewardDialog(context, achievement);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

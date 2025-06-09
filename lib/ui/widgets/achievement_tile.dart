import 'package:flutter/material.dart';
import 'package:task_spark/data/achievement.dart';
import 'package:task_spark/ui/widgets/achievement_progress_bar.dart';
import 'package:task_spark/util/achievement_utils.dart';

class AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final int currentValue;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const AchievementTile({
    super.key,
    required this.achievement,
    required this.currentValue,
    required this.isUnlocked,
    this.onTap,
  });

  Color _getTierColorByIndex(int index) {
    switch (index) {
      case 1:
        return const Color(0xFFCD7F32); // 브론즈
      case 2:
        return const Color(0xFFC0C0C0); // 실버
      case 3:
        return const Color(0xFFFFD700); // 골드
      case 4:
        return const Color(0xFF00EF55); // 플래티넘
      case 5:
        return const Color(0xFF00FFFF); // 다이아
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 등급 순서 고정
    final List<String> tierOrder = [
      'bronze',
      'silver',
      'gold',
      'platinum',
      'diamond',
    ];
    final List<int> tierAmounts =
        tierOrder.map((t) => achievement.amount[t] ?? 0).toList();

    int tierIndex;
    double progress;

    if (achievement.isOnce) {
      final require = achievement.amount['diamond'] ?? 1;
      final achieved = currentValue >= require;
      tierIndex = achieved ? 5 : 0;
      progress = achieved ? 1.0 : 0.0;
    } else {
      tierIndex = getTierIndex(achievement.amount, currentValue);

      if (tierIndex >= tierOrder.length) {
        if (achievement.title == "멈추지 않는 걸음") {
          print("detected");
        }
        progress = 1.0;
      } else {
        progress = currentValue / (achievement.amount["diamond"] ?? 1.0);
      }
    }

    if (achievement.title == "멈추지 않는 걸음") {
      print("progress: $progress");
    }

    final isHiddenUnlocked = achievement.isHidden && isUnlocked;

    return GestureDetector(
      onTap: () {
        onTap!();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isHiddenUnlocked
                ? Color.fromARGB(255, 221, 0, 255)
                : _getTierColorByIndex(tierIndex),
            width: tierIndex == 0 ? 0 : 2,
          ),
        ),
        elevation: 3,
        color: const Color.fromARGB(255, 72, 63, 55),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                tierIndex == 0 ? Icons.lock : Icons.emoji_events,
                size: 40,
                color: _getTierColorByIndex(tierIndex),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    isUnlocked || (achievement.isOnce && tierIndex == 5)
                        ? Text(
                            achievement.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : const Center(
                            child: Text(
                              '???',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    const SizedBox(height: 4),
                    isUnlocked || (achievement.isOnce && tierIndex == 5)
                        ? Text(
                            achievement.description,
                            style: TextStyle(color: Colors.grey[400]),
                          )
                        : const Center(child: Text('해금 전까지 비공개')),
                    const SizedBox(height: 8),
                    if ((tierIndex > 0 && !achievement.isOnce) ||
                        (achievement.isOnce && tierIndex == 5))
                      AchievementProgressBar(
                        tierAmounts: tierAmounts,
                        userValue: currentValue,
                        isOnce: achievement.isOnce,
                      ),
                    const SizedBox(height: 4),
                    if (isUnlocked || (achievement.isOnce && tierIndex == 5))
                      Text(
                        '전체 • ${(progress * 100).toInt()}% 진행 중',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

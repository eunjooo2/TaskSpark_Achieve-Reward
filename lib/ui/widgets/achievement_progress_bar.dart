import 'package:flutter/material.dart';
import 'dart:math';

class AchievementProgressBar extends StatelessWidget {
  final List<int> tierAmounts; // ex: [10, 20, 30, 40, 50]
  final int userValue; // ex: 37
  final bool isOnce;

  const AchievementProgressBar({
    Key? key,
    required this.tierAmounts,
    required this.userValue,
    this.isOnce = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 색상 및 티어 이름 정의
    final strongColors = [
      const Color(0xFFCD7F32), // 브론즈
      const Color(0xFFC0C0C0), // 실버
      const Color(0xFFFFD700), // 골드
      const Color(0xFF00EF55), // 플래티넘
      const Color(0xFF00FFFF), // 다이아
    ];
    final lightColors = [
      const Color(0xFFE3C5A9),
      const Color(0xFFE6E6E6),
      const Color(0xFFFFEFBF),
      const Color(0xFFC9EF55),
      const Color(0xFFC9FFFF),
    ];
    final tierNames = ['브론즈', '실버', '골드', '플래티넘', '다이아몬드'];

    // 1) 티어별 임계치 계산: [0, a1, a1+a2, …, total]
    final thresholds = <int>[0];
    for (var amt in tierAmounts) {
      thresholds.add(amt);
    }

    // 2) 일회성 업적인 경우 전체 바 한 덩어리로 표시
    if (isOnce) {
      final completed = userValue > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 8,
            child: Stack(children: [
              Container(
                decoration: BoxDecoration(
                  color: lightColors.last,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: completed ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: strongColors.last,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        ],
      );
    }

    // 3) ‘>’ 연산자로 티어 경계값 계산 (임계치에 딱 맞춰도 아래 티어 유지)
    int rawIndex = thresholds.lastIndexWhere((t) => userValue > t);
    if (rawIndex < 0) rawIndex = 0;
    int currentTierIndex = min(rawIndex, tierAmounts.length - 1);

    // 4) 현재 티어 내 진행률 & 퍼센트
    final start = thresholds[currentTierIndex];
    final end = thresholds[currentTierIndex + 1];
    final tierProgress = ((userValue <= start)
            ? 0.0
            : userValue >= end
                ? 1.0
                : (userValue - start) / (end - start))
        .clamp(0.0, 1.0);
    final tierPct = (tierProgress * 100).toInt();

    // 5) 렌더링
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Progress Bar ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 8,
          child: Row(
            children: List.generate(tierAmounts.length, (i) {
              final s = thresholds[i];
              final e = thresholds[i + 1];
              final p = ((userValue <= s)
                      ? 0.0
                      : userValue >= e
                          ? 1.0
                          : (userValue - s) / (e - s))
                  .clamp(0.0, 1.0);

              return Expanded(
                flex: (e - s).toInt().clamp(1, 9999),
                child: Stack(children: [
                  // 트랙
                  Container(
                    decoration: BoxDecoration(
                      color: lightColors[i],
                      borderRadius: BorderRadius.horizontal(
                        left: i == 0 ? const Radius.circular(4) : Radius.zero,
                        right: i == tierAmounts.length - 1
                            ? const Radius.circular(4)
                            : Radius.zero,
                      ),
                    ),
                  ),
                  // 진행량
                  FractionallySizedBox(
                    widthFactor: p,
                    child: Container(
                      decoration: BoxDecoration(
                        color: strongColors[i],
                        borderRadius: BorderRadius.horizontal(
                          left: i == 0 ? const Radius.circular(4) : Radius.zero,
                          right: i == tierAmounts.length - 1
                              ? const Radius.circular(4)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                ]),
              );
            }),
          ),
        ),

        const SizedBox(height: 4),

        // ── 레이블 ────────────────────────────────────────────────
        currentTierIndex <= 4 && tierPct != 100
            ? Text(
                '${tierNames[currentTierIndex]} 등급까지 · $tierPct% 진행 중',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              )
            : Container(),
      ],
    );
  }
}

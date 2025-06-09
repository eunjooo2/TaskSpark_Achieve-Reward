// achievement.dart
// 업적 데이터 모델 클래스. PocketBase record를 JSON으로 변환하거나, JSON을 객체로 생성하는 기능 포함.

import 'package:pocketbase/pocketbase.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String type;
  final bool isOnce;
  final bool isHidden;
  final String? hint;
  final Map<String, int> amount;
  final Map<String, dynamic>? reward;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.amount,
    required this.isOnce,
    this.isHidden = false,
    this.reward,
    this.hint,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json["id"] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      isOnce: json['isOnce'],
      isHidden: json['isHidden'] ?? false,
      amount: Map<String, int>.from(json['amount'] ?? {}),
      reward: json['reward'],
      hint: json['hint'] ?? '', // null 막기
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'isOnce': isOnce,
      'isHidden': isHidden,
      'amount': amount,
      if (reward != null) 'reward': reward,
    };
  }

  factory Achievement.fromRecord(RecordModel record) {
    return Achievement(
      id: record.data["id"],
      title: record.data["title"],
      description: record.data["description"],
      type: record.data["type"],
      amount: Map<String, int>.from(record.data["amount"]),
      reward: record.data["reward"] as Map<String, dynamic>,
      isOnce: record.data["isOnce"],
      isHidden: record.data["isHidden"],
      hint: record.data["hint"] ?? '',
    );
  }
}

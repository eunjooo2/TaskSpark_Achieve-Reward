// achievement.dart
// 업적 데이터 모델 클래스. PocketBase record를 JSON으로 변환하거나, JSON을 객체로 생성하는 기능 포함.
 
import 'package:pocketbase/pocketbase.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String type;
  final bool isOnce; // 일회성업적
  final bool isHidden; // 히든업적
  final String? hint; 
  final Map<String, int> amount; // 등급 임계값
  final Map<String, dynamic>? reward;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.amount,
    required this.isOnce,
    this.isHidden = false, // 
    this.reward, 
    this.hint,
  });

/// 일반 JSON 데이터를 받아 Achievement 객체로 변환하는 팩토리 생성자
/// 서버 응답 또는 로컬 파일에서 불러온 JSON 구조를 처리
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json["id"] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      isOnce: json['isOnce'],
      isHidden: json['isHidden']
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

/// PocketBase에서 불러온 RecordModel을 기반으로 Achievement 객체를 생성하는 팩토리 생성자
/// PocketBase의 record.data에서 각 필드를 추출하여 초기화     
  factory Achievement.fromRecord(RecordModel record) { 
    return Achievement(
      id: record.data["id"],
      title: record.data["title"],
      description: record.data["description"],
      type: record.data["type"],
      amount: Map<String, int>.from(record.data["amount"]),
      reward: record.data["reward"] != null ? Map<String, dynamic>.from(record.data["reward"]) : null,
      isOnce: record.data["isOnce"],
      isHidden: record.data["isHidden"],
      hint: record.data["hint"] ?? '',
    );
  }
}

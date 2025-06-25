// 유저(User) 관련 모델 정의 파일
import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:task_spark/service/achievement_service.dart';

class User {
  String? collectionId;
  String? collectionName;
  String? id;
  String? email;
  bool? emailVisibility;
  bool? verified;
  String? name;
  String? avatar;
  num? exp;
  int? point;
  Map<String, dynamic>? inventory;
  DateTime? created;
  DateTime? updated;
  String? accessToken;
  String? nickname;
  int? tag;
  Map<String, dynamic>? metadata;
  int? expMultiplier; // 부스터

  User({
    this.collectionId,
    this.collectionName,
    this.id,
    this.email,
    this.emailVisibility,
    this.verified,
    this.name,
    this.nickname,
    this.tag,
    this.point,
    this.avatar,
    this.exp,
    this.expMultiplier,
    this.inventory,
    this.created,
    this.updated,
    this.accessToken,
    this.metadata,
  });

  @override
  String toString() {
    return jsonEncode({
      "collectionId": collectionId,
      "collectionName": collectionName,
      "id": id,
      "accessToken": accessToken,
      "email": email,
      "emailVisibility": emailVisibility,
      "verified": verified,
      "name": name,
      "avatar": avatar,
      "exp": exp,
      "point": point,
      "expMultiplier": expMultiplier,
      "inventory": inventory,
      "created": created?.toIso8601String(),
      "updated": updated?.toIso8601String(),
    });
  }

  factory User.fromRecord(RecordModel record) {
    return User(
      collectionId: record.collectionId,
      collectionName: record.collectionName,
      id: record.id,
      email: record.data["email"] as String?,
      emailVisibility: record.data["emailVisibility"] as bool?,
      verified: record.data["verified"] as bool?,
      name: record.data["name"] as String?,
      nickname: record.data["nickname"] as String?,
      tag: record.data["tag"] as int?,
      avatar: record.data["avatar"] as String?,
      exp: record.data["exp"] as num?,
      point: record.data["point"] ?? record.data["point"] ?? 0,
      expMultiplier: record.data["expMultiplier"] as int?,
      inventory: record.data["inventory"] as Map<String, dynamic>?,
      created: DateTime.tryParse(record.created),
      updated: DateTime.tryParse(record.updated),
      metadata: record.data["metadata"] as Map<String, dynamic>?,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final user = json["data"];
    return User(
      accessToken: json["token"],
      id: user["id"],
      email: user["email"] as String?,
      verified: user["verified"] as bool?,
      name: user["name"] as String?,
      avatar: user["avatar"] as String?,
      nickname: user["nickname"] as String?,
      tag: user["tag"] as int?,
      exp: user["exp"] as num?,
      point: user["point"] ?? user["point"] ?? 0,
      expMultiplier: user["expMultiplier"] as int?,
      inventory: user["inventory"] as Map<String, dynamic>?,
      created: DateTime.tryParse(user["created"]),
      updated: DateTime.tryParse(user["updated"]),
      metadata: user["metadata"] as Map<String, dynamic>?,
    );
  }

  /// ✅ avatarUrl 생성기 (정상 이미지 렌더링용)
  String get avatarUrl {
    if (avatar == null ||
        avatar!.isEmpty ||
        id == null ||
        collectionId == null) {
      return "https://example.com/default-profile.png"; // 대체 이미지 경로
    }
    return "https://pb.aroxu.me/api/files/$collectionId/$id/$avatar";
  }

  /// # 경험치 기반으로 metadata 갱신
  void updateExpAndLevel() {
    final currentExp = (exp ?? 0).toInt();
    final previousLevel = metadata?['level'] ?? 1;
    final newLevel = _convertExpToLevel(currentExp);

    metadata ??= {};
    metadata!['exp'] = currentExp;
    metadata!['level'] = newLevel;

    if (newLevel > previousLevel) {
      // 레벨이 올랐다면 업적 증가 처리!
      AchievementService().increaseAchievement("level_up");
      print("[업적] level_up +1");
    }
  }

  /// 경험치 → 레벨 계산 공식
  int _convertExpToLevel(int exp) {
    int low = 0;
    int high = 1000;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      int requiredExp = 50 * mid * mid + 100 * mid;

      if (requiredExp == exp) {
        return mid;
      } else if (requiredExp < exp) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return high;
  }
}

class SearchData {
  int? count;
  List<SearchUser>? data;
  bool? success;

  SearchData({required this.count, required this.data, required this.success});

  factory SearchData.fromJson(Map<String, dynamic> json) {
    return SearchData(
      count: json["count"] as int,
      data: (json["data"] as List<dynamic>)
          .map((e) => SearchUser.fromJson(e))
          .toList(),
      success: json["success"] as bool,
    );
  }
}

class SearchUser {
  String? avatar;
  DateTime? created;
  num? exp;
  String? id;
  String? nickname;
  int? tag;

  SearchUser({
    required this.avatar,
    required this.created,
    required this.exp,
    required this.id,
    required this.nickname,
    required this.tag,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      avatar: json["avatar"] != null ? json["avatar"] as String : null,
      created: DateTime.tryParse(json["created"]),
      exp: json["exp"],
      id: json["id"] as String,
      nickname: json["nickname"] as String,
      tag: json["tag"],
    );
  }
}

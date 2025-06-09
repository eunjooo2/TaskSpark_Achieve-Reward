import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:task_spark/data/item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:task_spark/data/friend.dart';
import 'package:task_spark/data/user.dart';
import '../util/pocket_base.dart';
import '../util/secure_storage.dart';
import 'package:task_spark/service/achievement_service.dart'; //  업적 연동용
import 'package:intl/intl.dart';

// 2025. 06. 07 : 유저 응답 결과 전체 반환 하게 변경
class UserService {
  final PocketBase _pb = PocketB().pocketBase;

  /// OAuth2 로그인 요청 (provider: 'google', 'github' 등)
  Future<RecordAuth> sendLoginRequest(String provider) async {
    return await _pb.collection("users").authWithOAuth2(
          provider,
          (url) async => await launchUrl(url),
        );
  }

  // 변경 절대 금지 (API로 요청해야 Social NetWork Image 불러워져요, PocketBase로 접근하면 먹통됩니다.)
  Future<User> getUserByID(String userID) async {
    final accessToken = await SecureStorage().storage.read(key: "accessToken");
    final response = await PocketB().pocketBase.send("/user",
        method: "GET",
        query: {"cid": userID},
        headers: {"Authorization": "Bearer $accessToken"});
    return User.fromJson(response);
  }

  /// 현재 로그인된 사용자 프로필 조회
  Future<User> getProfile() async {
    final userID = await SecureStorage().storage.read(key: "userID") ?? "";

    return User.fromRecord(
        await PocketB().pocketBase.collection("users").getOne(userID));
  }

  /// 닉네임과 태그로 사용자 검색
  Future<SearchData> getUserByNicknameAndTag(String nickname, int? tag) async {
    final token = await SecureStorage().storage.read(key: "accessToken");

    final query = {
      "nickname": nickname,
      if (tag != null) "tag": tag,
    };

    final response = await _pb.send(
      "/user/search",
      method: "GET",
      query: query,
      headers: {"Authorization": "Bearer $token"},
    );

    return SearchData.fromJson(response);
  }

  /// 사용자 정보 업데이트
  Future<User> updateUserByID(String userId, Map<String, dynamic> data) async {
    final record = await _pb.collection("users").update(userId, body: data);

    // 닉네임 또는 태그 변경 감지 (업적 연동)
    if (data.containsKey("nickname") || data.containsKey("tag")) {
      await AchievementService()
          .updateMetaDataWithKey("use_nickname_tag_change", 1);
      print("✨ 닉네임/태그 변경 업적 +1");
    }

    return User.fromRecord(record);
  }

  /// 사용자 삭제
  Future<void> deleteUserByID(String userId) async {
    await _pb.collection("users").delete(userId);
  }

  /// # 경험치 지급 + metadata 갱신 + 레벨업 업적 연동
  Future<void> grantExperienceToUser(int amount) async {
    try {
      final userId = await SecureStorage().storage.read(key: "userID");
      final record = await _pb.collection("users").getOne(userId!);

      final currentExp = record.get<int>("exp");
      final currentPoint = record.get<int>("point");

      await _pb.collection("users").update(userId, body: {
        "exp": currentExp + amount,
        "point": currentPoint + amount,
      });

      print("경험치 $amount 지급 완료 (총 XP: ${currentExp + amount})");
      print("포인트 $amount 지급 완료 (총 point: ${currentPoint + amount})");
    } catch (e) {
      print("경험치 지급 실패: $e");
    }
  }

  /// 포인트 차감 / 업데이트
  Future<void> updateUserPoints(int newPoints) async {
    try {
      final userId = await SecureStorage().storage.read(key: "userID");
      if (userId == null || userId.isEmpty) {
        throw Exception("유저 ID를 찾을 수 없습니다.");
      }

      await _pb.collection("users").update(userId, body: {
        "point": newPoints,
      });

      print("✅ 포인트 업데이트 완료: $newPoints SP");
    } catch (e) {
      print("❌ 포인트 업데이트 실패: $e");
    }
  }

  /// 기존 방식: 인벤토리에서 아이템 이름 기반 삭제
  Future<bool> useItem(String userId, String itemName) async {
    try {
      final userRecord = await _pb.collection("users").getOne(userId);
      final inventoryData = userRecord.get("inventory");

      if (inventoryData == null || inventoryData["items"] == null) {
        throw Exception("인벤토리를 찾을 수 없습니다.");
      }

      List<dynamic> items = inventoryData["items"];

      bool found = false;
      for (var item in items) {
        if (item["name"] == itemName && item["isUsed"] != true) {
          item["isUsed"] = true;
          item["usedTime"] = DateTime.now().toIso8601String();
          found = true;
          break;
        }
      }

      if (!found) {
        throw Exception("해당 아이템을 찾을 수 없거나 이미 사용되었습니다.");
      }

      await _pb.collection("users").update(userId, body: {
        "inventory": {"items": items}
      });

      print("✅ $itemName 아이템 사용 처리 완료");
      return true;
    } catch (e) {
      print("❌ 아이템 사용 실패: $e");
      return false;
    }
  }

  /// 친구 요청에서 상대 유저 ID 반환
  Future<String> getOtherUserID(FriendRequest request) async {
    String? myUserID = await SecureStorage().storage.read(key: "userID");
    if (request.senderId == myUserID) {
      return request.receiverId;
    } else {
      return request.senderId;
    }
  }

  /// 닉네임+태그 검색 (오타 수정 포함)
  Future<SearchData> getUserByNickanemAndTag(String nickname, int? tag) async {
    final accessToken = await SecureStorage().storage.read(key: "accessToken");
    Map<String, dynamic> query = {"nickname": nickname};
    if (tag != null) {
      query["tag"] = tag;
    }

    final response = await PocketB().pocketBase.send("/user/search",
        method: "GET",
        query: query,
        headers: {"Authorization": "Bearer $accessToken"});

    return SearchData.fromJson(response);
  }

  /// 인벤토리 가져오기
  Future<Map<String, dynamic>?> getUserInventory() async {
    final user = await getProfile();
    return user.inventory;
  }

  /// 경험치를 기준으로 현재 레벨 계산
  int convertExpToLevel(num exp) {
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

  /// 다음 레벨까지 남은 경험치
  int experienceToNextLevel(int exp) {
    int level = convertExpToLevel(exp);
    int nextLevelExp = 50 * (level + 1) * (level + 1) + 100 * (level + 1);
    return nextLevelExp - exp;
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String tag,
    File? avatarFile,
  }) async {
    final updateBody = <String, dynamic>{
      "name": name,
      "tag": int.tryParse(tag),
    };

    if (avatarFile != null) {
      final file = await http.MultipartFile.fromPath(
        'avatar',
        avatarFile.path,
        contentType: MediaType('image', 'jpeg'),
      );

      await _pb.collection('users').update(
        userId,
        body: updateBody,
        files: [file], // 반드시 non-null 리스트로 전달
      );
    } else {
      await _pb.collection('users').update(
            userId,
            body: updateBody,
          );
    }
  }

  Future<User> updateInventory(
      String userId, List<Map<String, dynamic>> items) async {
    final response =
        await PocketB().pocketBase.collection("users").update(userId, body: {
      "inventory": {"items": items}
    });

    return User.fromRecord(response);
  }

  /// 로그인 연속 스트릭 처리
  Future<void> updateLoginStreak(User user) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(Duration(days: 1)));

    final streak = user.metadata?["loginStreak"] ?? {};
    final lastDate = streak["lastDate"];
    int count = streak["count"] ?? 0;

    if (lastDate == today) {
      // 오늘 이미 처리됨
      return;
    } else if (lastDate == yesterday) {
      count += 1;
    } else {
      count = 1;
    }

    user.metadata!["loginStreak"] = {
      "lastDate": today,
      "count": count,
    };

    await _pb.collection("users").update(user.id!, body: {
      "metadata": user.metadata,
    });

    await AchievementService().updateMetaDataWithKey("login_streak", count);
    print("📅 로그인 스트릭 +$count");
  }
}

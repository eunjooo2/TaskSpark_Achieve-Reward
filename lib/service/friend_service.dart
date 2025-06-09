import 'package:task_spark/data/friend.dart';
import 'package:task_spark/service/achievement_service.dart';
import 'package:task_spark/util/pocket_base.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:task_spark/util/secure_storage.dart';

class FriendService {
  Future<List<RecordModel>> _getFriendRecordList() async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    return await PocketB()
        .pocketBase
        .collection("friends")
        .getFullList(filter: "sender.id='$userID'||receiver.id='$userID'");
  }

  Future<List<FriendRequest>> getFriendList() async {
    final friendRecordList = await _getFriendRecordList();
    final friendRequests = friendRecordList
        .map((json) => FriendRequest.fromRecordModel(json))
        .toList();

    return friendRequests;
  }

  Future<FriendRequest> getFriendByRecordID(String recordID) async {
    return FriendRequest.fromRecordModel(
        await PocketB().pocketBase.collection('friends').getOne(recordID));
  }

  Future<RecordModel> sendFriendRequest(String targetUserId) async {
    final userID = await SecureStorage().storage.read(key: "userID");
    final body = <String, dynamic>{
      "sender": userID,
      "receiver": targetUserId,
      "isAccepted": false,
      "isBlocked": false,
    };

    final record =
        await PocketB().pocketBase.collection('friends').create(body: body);

    // # [업적 연동] 친구 추가 업적 증가
    await AchievementService().increaseAchievement("add_friend");
    //   return await PocketB().pocketBase.collection('friends').create(body: body);
    // }  이거 였는데.. 안에 넣음

    return record;
  }

  Future<void> acceptFriendRequest(String recordID) async {
    FriendRequest originFriendRequest = FriendRequest.fromRecordModel(
        await PocketB().pocketBase.collection('friends').getOne(recordID));

    await PocketB().pocketBase.collection('friends').update(recordID, body: {
      "sender": originFriendRequest.senderId,
      "receiver": originFriendRequest.receiverId,
      "isAccepted": true,
    });
  }

// acceptFriendRequest(...)  // ✅ 수락
// → rejectFriendRequest(...)  // ✅ 거절 (추가해야 함)
// → checkIsFriend(...)        // ✅ 친구 여부 확인

  /// # 친구 요청 거절 (요청 삭제)
  Future<void> rejectFriendRequest(String recordID) async {
    await PocketB().pocketBase.collection('friends').delete(recordID);
  }

  Future<bool> checkIsFriend(String targetUserId) async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    final friends = await PocketB().pocketBase.collection('friends').getFullList(
        filter:
            "((sender.id='$userID'&&receiver.id='$targetUserId')||(sender.id='$targetUserId'&&receiver.id='$userID'))&&isAccepted=true");

    return friends.length == 1;
  }

  Future<bool> alreadyRequestFriend(String targetUserId) async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    final friends = await PocketB().pocketBase.collection('friends').getFullList(
        filter:
            "sender.id='$userID'&&receiver.id='$targetUserId'&&isAccepted=false");

    return friends.length == 1;
  }

  Future<bool> isRequestFromTargetToMe(String targetUserId) async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    final friends = await PocketB().pocketBase.collection("friends").getFullList(
        filter:
            "sender.id='$targetUserId'&&receiver.id='$userID'&&isAccepted=false");

    return friends.length == 1;
  }

  Future<RecordModel> getRequestByTargetID(String targetUserId) async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";

    final friends = await PocketB().pocketBase.collection('friends').getFullList(
        filter:
            "((sender.id='$userID'&&receiver.id='$targetUserId')||sender.id='$targetUserId'&&receiver.id='$userID')&&isAccepted=false");

    return friends[0];
  }

  Future<RecordModel> getFriendByTargetID(String targetUserId) async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";

    final friends = await PocketB().pocketBase.collection('friends').getFullList(
        filter:
            "((sender.id='$userID'&&receiver.id='$targetUserId')||sender.id='$targetUserId'&&receiver.id='$userID')");

    return friends[0];
  }

  Future<void> blockFriend(String targetUserId) async {
    late RecordModel record;
    try {
      record = await getFriendByTargetID(targetUserId);
    } catch (e) {
      record = await sendFriendRequest(targetUserId);
    }
    record.data["isBlocked"] = true;
    await AchievementService().updateMetaDataWithKey("block_friend", 1);
    await PocketB()
        .pocketBase
        .collection('friends')
        .update(record.id, body: record.data);
  }
}

import 'package:task_spark/data/friend.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/service/task_service.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/util/pocket_base.dart';
import 'package:task_spark/util/secure_storage.dart';
import 'package:task_spark/service/friend_service.dart';
import 'package:task_spark/data/rival.dart';
import 'package:task_spark/service/achievement_service.dart';

class RivalService {
  Future<RivalRequest> sendRivalRequest(
      DateTime start, DateTime end, FriendRequest friend) async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    final body = {
      "start": start.toIso8601String(),
      "end": end.toIso8601String(),
      "friend": friend.id,
      "sender": userID,
      "isAccepted": false,
      "metadata": {"status": "pending"},
    };
    return RivalRequest.fromRecord(
        await PocketB().pocketBase.collection("rivals").create(body: body));
  }

  Future<bool> isSendRequest(FriendRequest friend) async {
    final userID = await SecureStorage().storage.read(key: "userID");
    final result = await PocketB().pocketBase.collection("rivals").getFullList(
        filter:
            'friend.id="${friend.id}"&&sender.id="$userID"&&isAccepted=false');
    return result.length == 1;
  }

  Future<bool> isReceiveRequest(FriendRequest friend) async {
    final userID = await SecureStorage().storage.read(key: "userID");
    final result = await PocketB().pocketBase.collection("rivals").getFullList(
        filter:
            'friend.id="${friend.id}"&&sender.id!="$userID"&&isAccepted=false');
    return result.length == 1;
  }

  Future<List<RivalRequest>> loadRivalRequests({required bool sent}) async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    final filter = sent
        ? "sender.id='$userID'&&isAccepted=false"
        : "(friend.receiver.id='$userID'||friend.sender.id='$userID')&&sender.id!='$userID'&&isAccepted=false";

    final result = await PocketB()
        .pocketBase
        .collection("rivals")
        .getFullList(filter: filter);
    return result.map((json) => RivalRequest.fromRecord(json)).toList();
  }

  Future<List<RivalRequest>> loadSendRivalRequest() async {
    return await loadRivalRequests(sent: true);
  }

  Future<List<RivalRequest>> loadReceiveRivalRequest() async {
    return await loadRivalRequests(sent: false);
  }

  Future<bool> isMatchedRival() async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    List<FriendRequest> friends = await FriendService().getFriendList();
    final friendIds = friends.map((f) => f.id).toList();
    final filter = friendIds.map((id) => 'friend.id="$id"').join('||');
    final result = await PocketB()
        .pocketBase
        .collection('rivals')
        .getFullList(filter: "($filter||sender.id='$userID')&&isAccepted=true");
    return result.length == 1;
  }

  Future<RivalRequest> loadMatchedRivalInfo() async {
    String userID = await SecureStorage().storage.read(key: "userID") ?? "";
    List<FriendRequest> friends = await FriendService().getFriendList();
    final friendIds = friends.map((f) => f.id).toList();
    final filter = friendIds.map((id) => 'friend.id="$id"').join('||');
    final result = await PocketB()
        .pocketBase
        .collection('rivals')
        .getFullList(filter: "($filter||sender.id='$userID')&&isAccepted=true");
    return RivalRequest.fromRecord(result[0]);
  }

  Future<User> loadEnemyUser() async {
    final rival = await loadMatchedRivalInfo();
    final friendRequestInfo =
        await FriendService().getFriendByRecordID(rival.friendID);
    final enemyUserID = await UserService().getOtherUserID(friendRequestInfo);
    final userInfo = await UserService().getUserByID(enemyUserID);
    return userInfo;
  }

  Future<void> acceptRivalRequest(String recordID) async {
    final record = await PocketB()
        .pocketBase
        .collection("rivals")
        .update(recordID, body: {"isAccepted": true});
    final String userID = (await SecureStorage().storage.read(key: "userID"))!;
    final String? senderID = record.get("sender")?["id"];
    final String? friendID = record.get("friend")?["id"];
    if (userID == senderID || userID == friendID) {
      await AchievementService().updateMetaDataWithKey("rival_challenge", 1);
      print("[업적] rival_challenge +1");
    }
    await _deleteRivalRequest();
  }

  Future<void> checkRivalVictory(RivalRequest request) async {
    final userID = await SecureStorage().storage.read(key: "userID") ?? "";
    if (request.metadata["result"] != null) {
      if (request.metadata["result"]["winner"] == userID) {
        await AchievementService().updateMetaDataWithKey("rival_win", 1);
        print("[업적] rival_win +1");
      }
    }
  }

  Future<void> _deleteRivalRequest() async {
    final records = await loadSendRivalRequest();
    for (var record in records) {
      await PocketB().pocketBase.collection("rivals").delete(record.id);
    }
  }

  Future<void> deleteRivalRequest(String recordID) async {
    await PocketB().pocketBase.collection("rivals").delete(recordID);
  }

  Future<List<Map<String, dynamic>>> getMetaData() async {
    final response = await loadMatchedRivalInfo();
    final process = response.metadata["process"];
    if (process is List) {
      return process.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      return [];
    }
  }

  Future<Map<String, dynamic>> getMetaDataWithNDays(int nDay) async {
    final metadata = await getMetaData();
    return metadata[nDay - 1];
  }

  Future<void> insertNDayMetaData() async {
    final userID = await SecureStorage().storage.read(key: "userID");
    final rivalInfo = await loadMatchedRivalInfo();
    final metadata = await getMetaData();
    final enemy = await loadEnemyUser();
    final taskService = TaskService(PocketB().pocketBase, UserService());

    final enemyGoal = await taskService.getTaskGoalCount(enemy.id ?? "");
    final enemyDone = await taskService.getTaskDoneCount(enemy.id ?? "");
    final myGoal = await taskService.getTaskGoalCount(userID ?? "");
    final myDone = await taskService.getTaskDoneCount(userID ?? "");

    metadata.add({
      "${enemy.id}": {"goal": enemyGoal, "done": enemyDone},
      "$userID": {"goal": myGoal, "done": myDone}
    });

    await PocketB().pocketBase.collection("rivals").update(rivalInfo.id, body: {
      "metadata": {"process": metadata}
    });
  }

  Future<RivalResult> getNDaysResult(int nDay) async {
    final response = await getMetaDataWithNDays(nDay);
    final myInfo = await UserService().getProfile();
    final enemyInfo = await loadEnemyUser();

    final myGoal = response[myInfo.id]["goal"] ?? 0;
    final myDone = response[myInfo.id]["done"] ?? 0;
    final enemyGoal = response[enemyInfo.id]["goal"] ?? 0;
    final enemyDone = response[enemyInfo.id]["done"] ?? 0;

    final myRatio = myGoal == 0 ? 0 : myDone / myGoal;
    final enemyRatio = enemyGoal == 0 ? 0 : enemyDone / enemyGoal;

    if (myRatio > enemyRatio) return RivalResult.win;
    if (myRatio == enemyRatio) return RivalResult.draw;
    return RivalResult.lose;
  }
}

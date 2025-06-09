import 'package:flutter/material.dart';
import 'package:task_spark/data/friend.dart';
import 'package:task_spark/service/friend_service.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/util/secure_storage.dart';
import 'package:task_spark/data/user.dart';

// 2025. 06. 07 : 차단 친구 설정 화면 추가
// - 차단 해제 적용 테스트 완료
class BlockedUserPage extends StatefulWidget {
  const BlockedUserPage({super.key});

  @override
  State<BlockedUserPage> createState() => _BlockedUserPageState();
}

class _BlockedUserPageState extends State<BlockedUserPage> {
  final FriendService _friendService = FriendService();
  final UserService _userService = UserService();
  late String myUserId;
  List<FriendRequest> blockedList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBlockedFriends();
  }

  Future<void> loadBlockedFriends() async {
    myUserId = await SecureStorage().storage.read(key: "userID") ?? "";

    final friends = await _friendService.getFriendList();
    final onlyBlocked =
        friends.where((f) => f.status == FriendRequestStatus.blocked).toList();

    setState(() {
      blockedList = onlyBlocked;
      isLoading = false;
    });
  }

  String getTargetUserId(FriendRequest f) {
    return f.senderId == myUserId ? f.receiverId : f.senderId;
  }

  Future<void> confirmAndToggleBlock(
      BuildContext context, FriendRequest friend, User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("차단 해제"),
        content: Text("${user.nickname}#${user.tag} 님의 차단을 해제하시겠습니까?"),
        actions: [
          TextButton(
            child: const Text("취소"),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text("확인"),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final targetUserId = getTargetUserId(friend);
      final record = await _friendService.getFriendByTargetID(targetUserId);

      await _friendService.rejectFriendRequest(record.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          content: Text("차단 해제 완료"),
          duration: Duration(seconds: 2),
        ),
      );

      await loadBlockedFriends();
    }
  }

  Widget buildBlockedUserTile(FriendRequest friend) {
    final targetUserId = getTargetUserId(friend);

    return FutureBuilder<User>(
      future: _userService.getUserByID(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircularProgressIndicator(),
            title: Text("유저 정보를 불러오는 중..."),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          return ListTile(
            title: Text("불러오기 실패"),
            subtitle: Text("유저 ID: $targetUserId"),
          );
        }

        final user = snapshot.data!;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                ? NetworkImage("https://pb.aroxu.me/${user.avatar}")
                : const AssetImage("assets/images/default_profile.png")
                    as ImageProvider,
          ),
          title: Text("${user.nickname ?? '알 수 없음'}#${user.tag ?? '0000'}"),
          subtitle: Text("ID: ${user.id}"),
          trailing: IconButton(
            icon: const Icon(Icons.lock_open, color: Colors.red),
            onPressed: () {
              confirmAndToggleBlock(context, friend, user);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "차단 친구 설정",
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: BackButton(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : blockedList.isEmpty
              ? const Center(child: Text("차단된 친구가 없습니다."))
              : ListView.builder(
                  itemCount: blockedList.length,
                  itemBuilder: (context, index) {
                    return buildBlockedUserTile(blockedList[index]);
                  },
                ),
    );
  }
}

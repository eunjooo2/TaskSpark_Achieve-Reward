import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:task_spark/ui/widgets/friend.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/util/secure_storage.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/service/friend_service.dart';
import 'package:task_spark/service/achievement_service.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> with RouteAware {
  late final _searchController = TextEditingController();
  List<SearchUser> users = [];
  Map<String, bool> friendStatus = {};
  Map<String, bool> requestStatus = {};

  @override
  void initState() {
    super.initState();
  }

  bool isLoading = false;

  Future<void> searchUser(String e) async {
    setState(() {
      isLoading = true;
      users = [];
      friendStatus = {};
      requestStatus = {};
    });

    try {
      List<String> searchData = e.split("#");
      String nickname = searchData[0];
      int? tag;

      if (searchData.length != 1 &&
          searchData[1] != '' &&
          int.tryParse(searchData[1]) != null) {
        tag = int.parse(searchData[1]);
      }

      SearchData result =
          await UserService().getUserByNicknameAndTag(nickname, tag);

      final userID = await SecureStorage().storage.read(key: "userID");

      final List<SearchUser> foundUsers =
          (result.data ?? []).where((user) => user.id != userID).toList();

      final friendStatusResults = await Future.wait(
        foundUsers.map((user) async {
          final id = user.id ?? "";
          final isFriend = await FriendService().checkIsFriend(id);
          return MapEntry(id, isFriend);
        }),
      );

      final requestStatusResults = await Future.wait(
        foundUsers.map((user) async {
          final id = user.id ?? "";
          final isRequested = await FriendService().alreadyRequestFriend(id);
          return MapEntry(id, isRequested);
        }),
      );

      friendStatus = Map.fromEntries(friendStatusResults);
      requestStatus = Map.fromEntries(requestStatusResults);

      foundUsers.sort((a, b) {
        final aIsFriend = friendStatus[a.id] ?? false;
        final bIsFriend = friendStatus[b.id] ?? false;

        if (aIsFriend != bIsFriend) {
          return bIsFriend ? 1 : -1;
        }
        return a.nickname!.compareTo(b.nickname!);
      });

      setState(() {
        users = foundUsers;
        friendStatus = Map.fromEntries(friendStatusResults);
        requestStatus = Map.fromEntries(requestStatusResults);
      });
    } catch (e) {
      // 에러 처리 필요시 추가
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Search",
          style: TextStyle(
            fontSize: 18.sp,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context, true);
          },
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 3.h),
          SizedBox(
            width: 90.w,
            child: SearchBar(
              hintText: "닉네임#태그 입력",
              onChanged: (String e) async {
                if (e != '') {
                  await searchUser(e);
                }
                setState(() {});
              },
              controller: _searchController,
              leading: Padding(
                padding: EdgeInsets.only(left: 5.w, right: 2.w),
                child: const Icon(
                  FontAwesomeIcons.search,
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Expanded(
            child: _searchController.text == ""
                ? Center(child: Text("검색어를 입력해주세요!"))
                : isLoading
                    ? Center(child: CircularProgressIndicator())
                    : users.isEmpty
                        ? Center(child: Text("검색된 유저가 없습니다."))
                        : ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final id = user.id ?? "";
                              final isFriend = friendStatus[id] ?? false;
                              final isAlreadyRequested =
                                  requestStatus[id] ?? false;

                              return FriendCard(
                                  searchUser: user,
                                  isSearch: true,
                                  actionButtons: isFriend
                                      ? Text("이미 친구입니다",
                                          style: TextStyle(
                                              fontSize: 14.sp,
                                              color: Colors.grey))
                                      : isAlreadyRequested
                                          ? TextButton(
                                              onPressed: () async {
                                                final recordID =
                                                    await FriendService()
                                                        .getRequestByTargetID(
                                                            id);
                                                await FriendService()
                                                    .rejectFriendRequest(
                                                        recordID.id);
                                                setState(() {
                                                  requestStatus[id] = false;
                                                });
                                              },
                                              child: Text("요청 취소",
                                                  style: TextStyle(
                                                      fontSize: 14.sp)),
                                            )
                                          : TextButton(
                                              onPressed: () async {
                                                final alreadyReceived =
                                                    await FriendService()
                                                        .isRequestFromTargetToMe(
                                                            user.id ?? "");
                                                if (alreadyReceived) {
                                                  final recordId =
                                                      await FriendService()
                                                          .getRequestByTargetID(
                                                              user.id ?? "");
                                                  await FriendService()
                                                      .acceptFriendRequest(
                                                          recordId.id);
                                                  setState(() {
                                                    friendStatus[id] = true;
                                                  });
                                                } else {
                                                  await FriendService()
                                                      .sendFriendRequest(
                                                          user.id ?? "");
                                                  await AchievementService()
                                                      .updateMetaDataWithKey(
                                                          "add_friend", 1);
                                                  //  ㄴ # 업적 추가
                                                  setState(() {
                                                    requestStatus[id] = true;
                                                  });
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      backgroundColor:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .primary,
                                                      content:
                                                          Text("친구 요청을 보냈습니다!"),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                "친구 요청",
                                                style:
                                                    TextStyle(fontSize: 14.sp),
                                              ),
                                            ),
                                  onTap: () {
                                    final image = user.avatar != null &&
                                            user.avatar!.isNotEmpty
                                        ? NetworkImage(
                                            "https://pb.aroxu.me/${user.avatar!}")
                                        : const AssetImage(
                                                "assets/images/default_profile.png")
                                            as ImageProvider;
                                    AwesomeDialog(
                                      context: context,
                                      animType: AnimType.scale,
                                      dialogType: DialogType.noHeader,
                                      body: Column(
                                        children: [
                                          Text(
                                            "${user.nickname}#${user.tag.toString().padRight(4, '0')}님의 정보",
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontSize: 17.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Row(
                                            children: [
                                              Padding(
                                                padding:
                                                    EdgeInsets.only(left: 5.w),
                                                child: CircleAvatar(
                                                  radius: 25.sp,
                                                  backgroundImage: image,
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text("닉네임: ${user.nickname}"),
                                                  Text(
                                                      "레벨: ${UserService().convertExpToLevel(user.exp ?? 0)}"),
                                                  Text(
                                                      "생성일: ${DateFormat("yyyy년 MM월 dd일").format(user.created!)}"),
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2.h),
                                        ],
                                      ),
                                      btnCancelText: "차단하기",
                                      btnCancelOnPress: () async {
                                        await FriendService()
                                            .blockFriend(user.id ?? "");
                                        await AchievementService()
                                            .updateMetaDataWithKey(
                                                "block_friend", 1);
                                        // # 차단 업적 추가
                                        await searchUser(
                                            _searchController.text);
                                      },
                                    ).show();
                                  });
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

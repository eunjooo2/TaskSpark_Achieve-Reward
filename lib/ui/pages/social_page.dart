import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:task_spark/ui/widgets/friend_expanision.dart';
import 'package:task_spark/ui/widgets/rival_expanision.dart';
import 'package:task_spark/data/friend.dart';
import 'package:task_spark/data/rival.dart'; 
import 'package:task_spark/data/user.dart';
import 'package:task_spark/util/secure_storage.dart';
import 'package:task_spark/service/friend_service.dart';
import 'package:task_spark/main.dart';
import 'package:task_spark/service/rival_service.dart';
import 'package:task_spark/service/user_service.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController tabController;
  late List<FriendRequest> receiveFriendRequest = [];
  late List<FriendRequest> sentFriendRequest = [];
  late List<FriendRequest> acceptedFriends = [];
  late List<RivalRequest> receiveRivalRequest = [];
  late List<RivalRequest> sentRivalRequest = [];
  List<RivalResult> isWin = [];
  bool isFriendLoading = true;
  bool isRivalLoading = true;
  bool isUserLoading = true;
  bool isMatched = false;
  RivalRequest? rivalInfo;
  User? enemy;
  User? my;
  int dayDiff = 0;
  int nowDayDiff = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    final currentTab = tabController.index;
    if (currentTab == 0) {
      getFriend();
    }
  }

  Color? getCardColor(int index) {
    switch (isWin[index]) {
      case RivalResult.win:
        return Colors.indigoAccent[700];
      case RivalResult.lose:
        return Colors.red[700];
      case RivalResult.draw:
        return Colors.grey[700];
    }
  }

  String? getTitle(int index) {
    switch (isWin[index]) {
      case RivalResult.win:
        return "승리";
      case RivalResult.lose:
        return "패배";
      case RivalResult.draw:
        return "무승부";
    }
  }

  Future<void> getFriend() async {
    final friendRequests = await FriendService().getFriendList();

    if (!mounted) return;

    final user = await SecureStorage().storage.read(key: "userID");

    setState(() {
      receiveFriendRequest = friendRequests
          .where((f) =>
              f.status == FriendRequestStatus.pending && f.receiverId == user)
          .toList();

      sentFriendRequest = friendRequests
          .where((f) =>
              f.status == FriendRequestStatus.pending && f.senderId == user)
          .toList();

      acceptedFriends = friendRequests
          .where((f) => f.status == FriendRequestStatus.accepted)
          .toList();

      isFriendLoading = false;
    });
  }

  Future<void> getRival() async {
    final sentRivalRequests =
        await RivalService().loadRivalRequests(sent: true);
    final receiveRivalRequests =
        await RivalService().loadRivalRequests(sent: false);

    if (!mounted) return;

    setState(() {
      sentRivalRequest = sentRivalRequests;
      receiveRivalRequest = receiveRivalRequests;
      isRivalLoading = false;
    });
  }

  Future<void> _fetchMatch() async {
    try {
      final matchResult = await RivalService().isMatchedRival();
      if (!mounted) return;

      if (!matchResult) {
        setState(() {
          isMatched = false;
          isUserLoading = false;
        });
        return;
      } else {
        setState(() {
          isRivalLoading = true;
        });
      }

      final enemyInfoFuture = RivalService().loadEnemyUser();
      final rivalInfoFuture = RivalService().loadMatchedRivalInfo();

      final enemyInfo = await enemyInfoFuture;
      final rival = await rivalInfoFuture;

      final now = DateTime.now().toUtc().add(const Duration(hours: 9));
      final today = DateTime(now.year, now.month, now.day);
      final startDate =
          DateTime(rival.start.year, rival.start.month, rival.start.day);

      final newDayDiff = rival.end.difference(rival.start).inDays;
      final newNowDayDiff = today.difference(startDate).inDays;

      final clampedNowDayDiff = newNowDayDiff.clamp(0, newDayDiff);

      final resultFutures = List.generate(
        clampedNowDayDiff,
        (i) => RivalService().getNDaysResult(i + 1),
      );

      final results = await Future.wait(resultFutures);
      final myUser = await UserService().getProfile();

      if (!mounted) return;

      await RivalService().insertNDayMetaData();

      setState(() {
        my = myUser;
        isMatched = true;
        enemy = enemyInfo;
        rivalInfo = rival;
        dayDiff = newDayDiff;
        nowDayDiff = clampedNowDayDiff;
        isWin = results;
        isUserLoading = false;
        isRivalLoading = false;
      });
    } catch (e, stack) {
      debugPrint("에러 발생: $e");
      debugPrint("스택트레이스: $stack");
      // 에러 발생 시 안전하게 fallback
      if (!mounted) return;
      setState(() {
        isUserLoading = false;
        isMatched = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMatch();
    getFriend();
    getRival();
    tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
      animationDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TabBar(
        controller: tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.4),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: "친구 목록"),
          Tab(text: "라이벌 목록"),
        ],
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          isFriendLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 2.h),
                      FriendExpanision(
                        title: "요청 받은 친구 목록",
                        expanisionType: "received",
                        data: receiveFriendRequest,
                        isReceived: true,
                        onDataChanged: getFriend,
                      ),
                      FriendExpanision(
                          title: "전송한 친구 요청 목록",
                          expanisionType: "transmited",
                          data: sentFriendRequest,
                          isReceived: false,
                          onDataChanged: getFriend),
                      FriendExpanision(
                        title: "친구 목록",
                        expanisionType: "normal",
                        data: acceptedFriends,
                        isReceived: null,
                        onDataChanged: getFriend,
                      ),
                    ],
                  ),
                ),
          isRivalLoading
              ? const Center(child: CircularProgressIndicator())
              : (isMatched
                  ? (isUserLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox.expand(
                          child: Column(
                            children: [
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        backgroundImage: enemy!.avatar !=
                                                    null &&
                                                enemy!.avatar!.isNotEmpty
                                            ? NetworkImage(
                                                    "https://pb.aroxu.me/${enemy!.avatar}")
                                                as ImageProvider
                                            : const AssetImage(
                                                "assets/images/default_profile.png"),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${enemy!.nickname}#${enemy!.tag.toString().padRight(4, '0')}",
                                              style: TextStyle(
                                                  fontSize: 18.sp,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              "경쟁 기간: ${DateFormat('MM월 dd일').format(rivalInfo!.start)} ~ ${DateFormat('MM월 dd일').format(rivalInfo!.end)} (${dayDiff}일)",
                                              style: TextStyle(
                                                  fontSize: 15.sp,
                                                  color: Colors.white60),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "레벨: ${UserService().convertExpToLevel(enemy!.exp ?? 0)}",
                                              style: TextStyle(fontSize: 15.sp),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(
                                color: Theme.of(context).colorScheme.secondary,
                                height: 4.h,
                                thickness: 1.5,
                              ),
                              Expanded(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: dayDiff,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 1.h,
                                        horizontal: 3.w,
                                      ),
                                      child: Card(
                                        color: (index < nowDayDiff &&
                                                isWin.length > index)
                                            ? getCardColor(index)
                                            : null,
                                        child: SizedBox(
                                          width: 100.w,
                                          height: 10.h,
                                          child: InkWell(
                                            onTap: index + 1 > nowDayDiff
                                                ? () {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          "아직 진행되지 않은 대결입니다.",
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .secondary,
                                                          ),
                                                        ),
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                      ),
                                                    );
                                                  }
                                                : () async {
                                                    final _dialogContext =
                                                        context;
                                                    if (!mounted) return;
                                                    AwesomeDialog(
                                                      context: _dialogContext,
                                                      animType: AnimType.scale,
                                                      dialogType:
                                                          DialogType.noHeader,
                                                      body: Column(
                                                        children: [
                                                          Text(
                                                            "${index + 1}일차 정보",
                                                            style: TextStyle(
                                                              fontSize: 18.sp,
                                                            ),
                                                          ),
                                                          SizedBox(height: 1.h),
                                                          Text(
                                                            getTitle(index) ??
                                                                "",
                                                            style: TextStyle(
                                                              color:
                                                                  getCardColor(
                                                                      index),
                                                              fontSize: 18.sp,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          SizedBox(height: 3.h),
                                                          Column(
                                                            children: [
                                                              Text(
                                                                "${enemy!.nickname}#${enemy!.tag.toString().padRight(4, '0')}님의 정보",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      16.sp,
                                                                ),
                                                              ),
                                                              Text(
                                                                  "목표: ${rivalInfo!.metadata["process"][index][enemy!.id]["goal"]}/완료: ${rivalInfo!.metadata["process"][index][enemy!.id]["done"]}")
                                                            ],
                                                          ),
                                                          Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    vertical:
                                                                        2.5.h),
                                                            child: Divider(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .primary,
                                                              indent: 5.w,
                                                              endIndent: 5.w,
                                                            ),
                                                          ),
                                                          Column(
                                                            children: [
                                                              Text(
                                                                "${my!.nickname}#${my!.tag.toString().padRight(4, '0')}님의 정보",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      16.sp,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  height: 1.h),
                                                              Text(
                                                                  "목표: ${rivalInfo!.metadata["process"][index][my!.id]["goal"]}/완료: ${rivalInfo!.metadata["process"][index][my!.id]["done"]}")
                                                            ],
                                                          ),
                                                          SizedBox(height: 5.h),
                                                        ],
                                                      ),
                                                      showCloseIcon: true,
                                                    ).show();
                                                  },
                                            child: Center(
                                              child: Text(
                                                "${index + 1}일차 할 일 목록 및 결과",
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 2.h),
                          RivalExpanision(
                            title: "요청 받은 라이벌 목록",
                            expanisionType: "received",
                            data: receiveRivalRequest,
                            isReceived: true,
                            onDataChanged: getRival,
                          ),
                          RivalExpanision(
                            title: "전송한 라이벌 요청 목록",
                            expanisionType: "transmited",
                            data: sentRivalRequest,
                            isReceived: false,
                            onDataChanged: getRival,
                          ),
                        ],
                      ),
                    )),
        ],
      ),
    );
  }
}

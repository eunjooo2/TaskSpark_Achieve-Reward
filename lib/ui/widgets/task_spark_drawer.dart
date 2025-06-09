import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:task_spark/ui/pages/achievement_page.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/ui/pages/edit_profile_page.dart';
import 'package:task_spark/ui/pages/item_used_page.dart';
import 'package:task_spark/util/secure_storage.dart';
import 'package:task_spark/service/user_service.dart';

import '../pages/app_setting_page.dart';
import '../pages/blocked_user_page.dart';
import '../pages/inventory_page.dart';
import '../pages/splash_page.dart';

// 2025. 06. 07 : Drawer 경험치 바 업데이트
// - 구성 요소 관련 페이지 전부 추가
class TaskSparkDrawer extends StatefulWidget {
  const TaskSparkDrawer({super.key});

  @override
  State<TaskSparkDrawer> createState() => _TaskSparkDrawerState();
}

class _TaskSparkDrawerState extends State<TaskSparkDrawer> {
  late User user;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    final id = await SecureStorage().storage.read(key: "userID") ?? "";
    final fetchedUser = await UserService().getUserByID(id);
    setState(() {
      user = fetchedUser;
      isLoading = false;
    });
  }

  Future<void> logout() async {
    await SecureStorage().storage.deleteAll();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SplashPage()),
      (route) => false,
    );
  }

  Widget _getDrawerIconRow(IconData icon, String text, Function onPressed) {
    return SizedBox(
      height: 6.h,
      child: FilledButton(
        onPressed: () => onPressed(),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(Colors.transparent),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: FaIcon(icon, color: Colors.white),
            ),
            Text(
              text,
              style: TextStyle(
                fontSize: 0.5.cm,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerWithText(String text, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            height: 1.5.h,
            indent: 0.3.cm,
            endIndent: 0.3.cm,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 0.5.cm,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            height: 1.5.h,
            indent: 0.3.cm,
            endIndent: 0.3.cm,
          ),
        ),
      ],
    );
  }

  Widget _buildExpAndPointsRow() {
    final currentExp = user.exp?.toInt() ?? 0;
    final currentLevel = UserService().convertExpToLevel(currentExp);
    final nextLevelExp =
        UserService().experienceToNextLevel(currentExp) + currentExp;
    final currentLevelBaseExp =
        50 * currentLevel * currentLevel + 100 * currentLevel;
    final expIntoLevel = currentExp - currentLevelBaseExp;
    final expRequired = nextLevelExp - currentLevelBaseExp;
    final expRate = expIntoLevel / expRequired;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Lv. $currentLevel",
                  style: TextStyle(
                      fontSize: 0.55.cm,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.coins,
                      size: 14, color: Colors.amber),
                  SizedBox(width: 1.w),
                  Text("${user.point ?? 0}P",
                      style: TextStyle(
                          fontSize: 0.5.cm,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ],
          ),
          SizedBox(height: 0.8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: expRate.clamp(0.0, 1.0),
              minHeight: 1.8.h,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          SizedBox(height: 0.6.h),
          Text(
            "$expIntoLevel / $expRequired XP",
            style: TextStyle(
                fontSize: 0.45.cm,
                fontWeight: FontWeight.w400,
                color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: isLoading == false
          ? ListView(
              padding: EdgeInsets.zero,
              children: [
                Theme(
                  data: ThemeData(
                    dividerColor: Colors.transparent,
                    dividerTheme: const DividerThemeData(
                      color: Colors.transparent,
                    ),
                  ),
                  child: UserAccountsDrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    accountName: Text(
                      "${user.nickname}#${user.tag}",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    accountEmail: Text(
                      user.email ?? "",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    currentAccountPicture: CircleAvatar(
                      backgroundImage:
                          NetworkImage("https://pb.aroxu.me/${user.avatar}"),
                    ),
                  ),
                ),
                _buildExpAndPointsRow(),
                Padding(
                  padding: EdgeInsets.only(top: 1.5.h),
                  child: Column(
                    children: [
                      _buildDividerWithText("계정", context),
                      _getDrawerIconRow(FontAwesomeIcons.pencil, "프로필 편집", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(user: user),
                          ),
                        );
                      }),
                      _getDrawerIconRow(FontAwesomeIcons.gifts, "인벤토리", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InventoryPage(),
                          ),
                        );
                      }),
                      _getDrawerIconRow(FontAwesomeIcons.receipt, "아이템 사용내역",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemUsedPage(),
                          ),
                        );
                      }),
                      _getDrawerIconRow(FontAwesomeIcons.medal, "업적", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AchievementPage(
                              nickname: user.nickname ?? '익명',
                              expRate: 0.0,
                              myUser: user,
                            ),
                          ),
                        );
                      }),
                      _getDrawerIconRow(
                          FontAwesomeIcons.rightFromBracket, "로그아웃", () {
                        logout();
                      }),
                      _buildDividerWithText("설정", context),
                      _getDrawerIconRow(FontAwesomeIcons.gear, "앱 설정", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppSettingsPage(),
                          ),
                        );
                      }),
                      _getDrawerIconRow(FontAwesomeIcons.userLock, "차단 친구 설정",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BlockedUserPage(),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

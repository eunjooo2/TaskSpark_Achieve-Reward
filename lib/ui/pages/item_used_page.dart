import 'package:flutter/material.dart';
import 'package:task_spark/data/item.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/service/item_service.dart';
import 'package:task_spark/util/pocket_base.dart';
import 'package:task_spark/data/user.dart';

class ItemUsedPage extends StatefulWidget {
  const ItemUsedPage({super.key});

  @override
  State<ItemUsedPage> createState() => _ItemUsedPageState();
}

class _ItemUsedPageState extends State<ItemUsedPage> {
  final itemService = ItemService(PocketB().pocketBase);
  final userService = UserService();

  User? user;
  List<Item> items = [];
  List<Map<String, dynamic>> rawData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsedItems();
  }

  Future<void> fetchUsedItems() async {
    final loadedUser = await userService.getProfile();
    user = loadedUser;

    final rawItems = user?.inventory?["items"];
    if (rawItems is! List) {
      setState(() => isLoading = false);
      return;
    }

    rawData = rawItems.whereType<Map<String, dynamic>>().toList();

    // logs에 사용된 항목이 있는 item만 필터링
    final usedItemIds = rawData
        .where((item) {
          final logs = item["logs"] as List? ?? [];
          return logs.any((log) => log["isUsed"] == true);
        })
        .map((e) => e["id"] as String)
        .toSet()
        .toList();

    final result = await itemService.getItemsByIds(usedItemIds);

    setState(() {
      items = result;
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> getUsedLogsByItemId(String id) {
    final item = rawData.firstWhere((e) => e["id"] == id);

    final logs =
        (item["logs"] as List?)?.whereType<Map<String, dynamic>>().toList() ??
            [];
    return logs.where((log) => log["isUsed"] == true).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "사용한 아이템 목록",
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: BackButton(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text("사용한 아이템이 없습니다."))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final usedLogs = getUsedLogsByItemId(item.id);

                    return ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white, // 배경 흰색
                        radius: 24,
                        child: ClipOval(
                          child: item.image.isNotEmpty
                              ? Image.network(
                                  item.imageUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                                )
                              : const Icon(Icons.image, size: 30),
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Text("사용한 수량: ${usedLogs.length}개"),
                      children: usedLogs.map((log) {
                        final usedTime = log["usedTime"] ?? "알 수 없음";
                        final purchasedTime = log["purchasedTime"] ?? "-";
                        final dueDate = log["dueDate"] ?? "-";

                        return ListTile(
                          title: Text(
                              "사용 시각: ${ItemService(PocketB().pocketBase).formatDateTime(usedTime)}"),
                          subtitle: Text(
                              "구매일: ${ItemService(PocketB().pocketBase).formatDateTime(purchasedTime)}\n만료일: ${ItemService(PocketB().pocketBase).formatDateTime(dueDate)}"),
                        );
                      }).toList(),
                    );
                  },
                ),
    );
  }
}

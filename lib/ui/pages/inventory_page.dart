import 'package:flutter/material.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/data/item.dart';
import 'package:task_spark/service/item_service.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/util/pocket_base.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

// 생략된 import 및 class 선언은 기존과 동일

class _InventoryPageState extends State<InventoryPage> {
  final itemService = ItemService(PocketB().pocketBase);
  final userService = UserService();

  List<Item> items = [];
  User? user;
  List<Map<String, dynamic>> rawData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  Future<void> fetchUser() async {
    final loadUser = await userService.getProfile();
    setState(() => user = loadUser);
  }

  Future<void> fetchInventory() async {
    await fetchUser();
    final rawItems = user?.inventory?["items"];
    if (rawItems is! List) {
      setState(() => isLoading = false);
      return;
    }

    rawData = rawItems.whereType<Map<String, dynamic>>().toList();
    // 수량이 1개 이상 남아있는 아이템만 필터링
    rawData = rawData
        .where((e) => (e["quantity"] ?? 0) > (e["usedQuantity"] ?? 0))
        .toList();

    final ids = rawData.map((e) => e["id"] as String).toList();

    try {
      final result = await itemService.getItemsByIds(ids);
      setState(() {
        items = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Map<String, dynamic> getRawById(String id) {
    return rawData.firstWhere((e) => e["id"] == id, orElse: () => {});
  }

  Future<void> handleUseItem(Item item) async {
    if (user == null) return;

    final raw = getRawById(item.id);
    int quantity = raw["quantity"] ?? 0;
    int used = raw["usedQuantity"] ?? 0;
    int remain = quantity - used;

    if (remain <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("아이템이 더 이상 없습니다.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("아이템 사용"),
        content: Text("${item.title} 아이템을 사용하시겠습니까?\n(남은 수량: $remain개)"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("취소")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, true);
            },
            child: const Text("사용"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // logs 중 사용되지 않은 로그를 하나 찾아서 업데이트
    final logs = raw["logs"] as List<dynamic>? ?? [];
    final now = DateTime.now().toIso8601String();

    for (final log in logs) {
      if (log is Map && (log["isUsed"] == false || log["isUsed"] == null)) {
        log["isUsed"] = true;
        log["usedTime"] = now;
        raw["usedQuantity"] = used + 1;
        break;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${item.title} 아이템을 1개 사용했습니다.")),
    );

    try {
      final updatedUser = await userService.updateInventory(user!.id!, rawData);
      debugPrint("인벤토리 업데이트 성공: ${updatedUser.id}");
    } catch (e) {
      debugPrint("인벤토리 업데이트 실패: $e");
    }

    // UI 갱신
    setState(() {});
  }

  bool shouldShowUseButton(Item item, Map<String, dynamic> raw) {
    final remain = (raw["quantity"] ?? 0) - (raw["usedQuantity"] ?? 0);
    return item.title != "x1.2경험치 부스트" && item.title != "라이벌 신청권" && remain > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('인벤토리',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: BackButton(
          onPressed: () => Navigator.pop(context, true),
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text("보유 중인 아이템이 없습니다."))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final raw = getRawById(item.id);
                    final quantity = raw["quantity"] ?? 0;
                    final used = raw["usedQuantity"] ?? 0;
                    final remain = quantity - used;
                    final logs = raw["logs"] as List<dynamic>? ?? [];
                    final lastLog = logs.isNotEmpty ? logs.last : null;

                    final purchasedTime = lastLog?["purchasedTime"] ?? "알 수 없음";
                    final dueDate = lastLog?["dueDate"] ?? "없음";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      color: const Color(0xFF2A241F),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: ClipOval(
                                child: item.image.isNotEmpty
                                    ? Container(
                                        width: 70,
                                        height: 70,
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        child: Image.network(
                                          item.imageUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                      )
                                    : const Icon(Icons.image),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text("남은 수량: $remain개",
                                      style: TextStyle(
                                        color: remain > 0
                                            ? Colors.greenAccent
                                            : Colors.red[200],
                                      )),
                                  const SizedBox(height: 4),
                                  Text(
                                      "구매일: ${ItemService(PocketB().pocketBase).formatDateTime(purchasedTime)}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  Text(
                                      "만료일: ${ItemService(PocketB().pocketBase).formatDateTime(dueDate)}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  if (shouldShowUseButton(item, raw))
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: ElevatedButton(
                                          onPressed: () => handleUseItem(item),
                                          child: const Text("사용"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.greenAccent.shade700,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

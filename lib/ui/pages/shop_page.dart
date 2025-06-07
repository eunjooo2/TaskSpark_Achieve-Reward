import 'package:flutter/material.dart';
import 'package:task_spark/data/item.dart';
import 'package:task_spark/data/user.dart';
import 'package:task_spark/service/user_service.dart';
import 'package:task_spark/util/pocket_base.dart';
import 'package:task_spark/service/item_service.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  User? user;
  List<Item> items = [];
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserAndItems();
  }

  Future<void> fetchUserAndItems() async {
    final fetchedUser = await UserService().getProfile();
    final fetchedItems = await ItemService(PocketB().pocketBase).getAllItems();
    setState(() {
      user = fetchedUser;
      items = fetchedItems;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = items.where((item) {
      return item.title.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, toolbarHeight: 0),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildSearchBar(),
                  _buildPointIndicator(),
                  _buildItemGrid(filteredItems),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(
          hintText: '아이템 검색...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildPointIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      alignment: Alignment.centerRight,
      child: Text(
        "보유 포인트: ${_formatPoints(user?.point ?? 0)} SP",
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildItemGrid(List<Item> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _showPurchaseDialog(item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(6),
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
                ),
                const SizedBox(height: 8),
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  "${_formatPoints(item.price)} SP",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPurchaseDialog(Item item) {
    final itemPrice = item.price;
    final currentPoints = user?.point ?? 0;
    final affordable = currentPoints >= itemPrice;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("${item.title} 구매"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                item.imageUrl,
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "가격: ${_formatPoints(itemPrice)} SP",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!affordable)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    "보유 포인트가 부족합니다!",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: affordable
                  ? () async {
                      final updated = await _processPurchase(item.price, item);
                      if (updated) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${item.title} 구매 완료!")),
                        );
                      }
                    }
                  : null,
              child: const Text("구매하기"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _processPurchase(int price, Item item) async {
    final userId = user?.id;
    if (userId == null) return false;

    final currentPoints = user?.point ?? 0;
    final newPoints = currentPoints - price;

    final inventory = Map<String, dynamic>.from(user?.inventory ?? {});
    final itemsList = List<Map<String, dynamic>>.from(inventory["items"] ?? []);

    final now = DateTime.now().toUtc();
    bool found = false;

    for (var inv in itemsList) {
      if (inv["id"] == item.id && inv["isUsed"] == false) {
        inv["quantity"] = (inv["quantity"] ?? 1) + 1;
        found = true;
        break;
      }
    }

    if (!found) {
      itemsList.add({
        "isUsed": false,
        "id": item.id,
        "quantity": 1,
        "metadata": {
          "purchasedTime": now.toIso8601String(),
          "dueDate":
              DateTime(now.year, now.month + 1, now.day).toIso8601String(),
          "expired": false,
        }
      });
    }

    inventory["items"] = itemsList;

    final updated = await UserService().updateUserByID(userId, {
      "points": newPoints,
      "inventory": inventory,
    });

    setState(() {
      user = updated;
    });

    return true;
  }

  String _formatPoints(int points) {
    return points.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}

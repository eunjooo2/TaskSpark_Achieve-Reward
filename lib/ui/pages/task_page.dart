// 📁 ui/pages/task_page.dart
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:task_spark/util/secure_storage.dart';

import '../../data/category.dart';
import '../../data/task.dart';
import '../../service/task_service.dart';
import '../../service/category_service.dart';
import '../../service/user_service.dart';
import '../../util/pocket_base.dart';
import '../widgets/category_tabbar.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form.dart';
 
class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

enum SortOption { startDate, priority, title }

class _TaskPageState extends State<TaskPage> {
  final PocketBase pb = PocketB().pocketBase;
  late final TaskService _taskService;
  late final CategoryService _categoryService;
  late final UserService _userService;

  List<Task> _tasks = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isLoading = true;
  SortOption _sortOption = SortOption.startDate;
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _userService = UserService();
    _taskService = TaskService(pb, _userService);
    _categoryService = CategoryService(pb);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  Future<void> _fetchData() async {
    final userID = await SecureStorage().storage.read(key: "userID") ?? "";
    print(await _taskService.getTaskGoalCount(userID));

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final categories = await _categoryService.getAllCategories();
      final tasks = await _taskService.getAllTasks();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _tasks = tasks;
      });
    } catch (_) {
      _showSnackBar("데이터 불러오기 실패 😥");
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Task> get _filteredTasks {
    List<Task> list = _tasks;
    if (_selectedCategoryId != null) {
      list = list.where((t) => t.categoryId == _selectedCategoryId).toList();
    }

    list.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone == true ? 1 : -1;
      }
      int cmp;
      switch (_sortOption) {
        case SortOption.priority:
          cmp = int.tryParse(a.priority ?? '3')!
              .compareTo(int.tryParse(b.priority ?? '3')!);
          break;
        case SortOption.title:
          cmp = (a.title ?? '').compareTo(b.title ?? '');
          break;
        case SortOption.startDate:
          cmp = (a.startDate ?? DateTime(1900))
              .compareTo(b.startDate ?? DateTime(1900));
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    return list;
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        content: Text(msg)));
  }

  Future<void> _handleToggleDone(Task task) async {
    try {
      if (task.isDone == true) return;
      if (task.startDate != null &&
          task.startDate!.isAfter(DateTime.now().add(Duration(hours: 9)))) {
        return;
      }

      await _taskService.handleTaskCompletion(task);
      _showSnackBar("할 일 완료! 경험치가 지급되었습니다 🎉");

      await _fetchData();
    } catch (e) {
      _showSnackBar("완료 처리 실패: $e");
    }
  }

  Future<void> _handleDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("삭제 확인"),
        content: const Text("정말 삭제하시겠습니까?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("취소")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("삭제")),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskService.deleteTask(task.id!);
        _showSnackBar("삭제되었습니다.");
        await _fetchData();
      } catch (_) {
        _showSnackBar("삭제 실패");
      }
    }
  }

  Future<void> _openTaskForm({Task? task}) async {
    await showDialog(
      context: context,
      builder: (_) => TaskForm(
        task: task,
        categories: _categories,
        onSubmit: (submittedTask) async {
          try {
            if (task != null) {
              await _taskService.updateTask(task.id!, submittedTask.toJson());
              _showSnackBar("할 일 수정 완료!");
            } else {
              await _taskService.createTask(submittedTask);
              _showSnackBar("새 할 일이 추가되었습니다!");
            }
            await _fetchData();
          } catch (e) {
            _showSnackBar("저장 실패: $e");
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CategoryTabBar(
        categories: _categories,
        selectedCategoryId: _selectedCategoryId,
        onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
        onRefreshCategories: _fetchData,
        categoryService: _categoryService,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(2.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      DropdownButton<SortOption>(
                        value: _sortOption,
                        items: const [
                          DropdownMenuItem(
                              value: SortOption.startDate, child: Text("시간순")),
                          DropdownMenuItem(
                              value: SortOption.priority, child: Text("우선순위순")),
                          DropdownMenuItem(
                              value: SortOption.title, child: Text("이름순")),
                        ],
                        onChanged: (val) => setState(() => _sortOption = val!),
                      ),
                      IconButton(
                        icon: Icon(_ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                        onPressed: () =>
                            setState(() => _ascending = !_ascending),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchData,
                    child: _filteredTasks.isEmpty
                        ? Center(
                            child: Text("등록된 할 일이 없습니다.",
                                style: TextStyle(fontSize: 17.sp)))
                        : ListView.separated(
                            padding: EdgeInsets.all(4.w),
                            itemCount: _filteredTasks.length,
                            separatorBuilder: (_, __) => Divider(height: 2.h),
                            itemBuilder: (context, idx) {
                              final task = _filteredTasks[idx];
                              return TaskCard(
                                task: task,
                                category: _categories.where((e) {
                                  return e.id == task.categoryId;
                                }).firstOrNull,
                                onChanged: (_) => _handleToggleDone(task),
                                onEdit: () => _openTaskForm(task: task),
                                onDelete: () => _handleDelete(task),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

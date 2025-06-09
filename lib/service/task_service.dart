import 'package:pocketbase/pocketbase.dart';
import '../data/task.dart';
import 'package:task_spark/service/achievement_service.dart';
import '../util/secure_storage.dart';
import 'user_service.dart';
import 'package:intl/intl.dart';

class TaskService {
  final PocketBase pb;
  final UserService userService;

  TaskService(this.pb, this.userService);

  Future<List<Task>> getAllTasks() async {
    final userId = await SecureStorage().storage.read(key: "userID");
    final result = await pb.collection('tasks').getFullList(
          filter: "owner.id='$userId'",
          sort: "-created",
        );
    return result.map(Task.fromRecord).toList();
  }

  Future<Task?> getTaskById(String id) async {
    try {
      final record = await pb.collection('tasks').getOne(id);
      return Task.fromRecord(record);
    } catch (_) {
      return null;
    }
  }

  Future<Task> createTask(Task task) async {
    final userId = await SecureStorage().storage.read(key: "userID");

    final body = {
      ...task.toJson(),
      "owner": userId,
    };

    final record = await pb.collection('tasks').create(body: body);

    await AchievementService().increaseAchievement("add_task_total");

    final weekday = task.startDate?.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      await AchievementService().updateMetaDataWithKey("weekend_task", 1);
    }

    if (task.categoryId != null && task.categoryId!.isNotEmpty) {
      await AchievementService().updateMetaDataWithKey("category_sort_use", 1);
    }

    return Task.fromRecord(record);
  }

  Future<Task> updateTask(String id, Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data);

    if (body['startDate'] is DateTime) {
      body['startDate'] = (body['startDate'] as DateTime).toIso8601String();
    }
    if (body['endDate'] is DateTime) {
      body['endDate'] = (body['endDate'] as DateTime).toIso8601String();
    }

    final record = await pb.collection('tasks').update(id, body: body);
    return Task.fromRecord(record);
  }

  Future<void> deleteTask(String id) async {
    await pb.collection('tasks').delete(id);
  }

  Future<Task> toggleDone(Task task) async {
    final updated = await updateTask(task.id!, {
      ...task.toJson(),
      "isDone": !(task.isDone ?? false),
    });

    if (!(task.isDone ?? false)) {
      await AchievementService().updateMetaDataWithKey("complete_task", 1);

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterday = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: 1)));
      final user = await userService.getProfile();
      final streak = user.metadata?["taskStreak"] ?? {};
      final lastDate = streak["lastDate"];
      int count = streak["count"] ?? 0;

      if (lastDate == today) {
        // already updated
      } else if (lastDate == yesterday) {
        count += 1;
      } else {
        count = 1;
      }

      user.metadata!["taskStreak"] = {"lastDate": today, "count": count};

      await AchievementService()
          .updateMetaDataWithKey("complete_task_streak", count);
    }

    return updated;
  }

  Future<void> handleTaskCompletion(Task task) async {
    final priority = int.tryParse(task.priority ?? "3") ?? 3;
    final exp = priority * 10;

    await userService.grantExperienceToUser(exp);
    await AchievementService().updateMetaDataWithKey("complete_routine", 1);
    if (task.isRepeatingTask == true && task.repeatPeriod != null) {
      final repeatDays = int.tryParse(task.repeatPeriod!) ?? 0;

      if (repeatDays > 0) {
        final newTask = task.copyWith(
          id: null,
          startDate: task.startDate?.add(Duration(days: repeatDays)),
          endDate: task.endDate?.add(Duration(days: repeatDays)),
          isDone: false,
          created: null,
          updated: null,
        );
        await createTask(newTask);
      }
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(Duration(days: 1)));
    final user = await userService.getProfile();
    final streak = user.metadata?["routineStreak"] ?? {};
    final lastDate = streak["lastDate"];
    int count = streak["count"] ?? 0;

    if (lastDate == today) {
      // already done today
    } else if (lastDate == yesterday) {
      count += 1;
    } else {
      count = 1;
    }

    user.metadata!["routineStreak"] = {"lastDate": today, "count": count};

    await AchievementService()
        .updateMetaDataWithKey("complete_routine_streak", count);

    await toggleDone(task);
  }

  Future<int> getTaskGoalCount(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await pb.collection("tasks").getFullList(
        filter: "owner.id='$userId'&&startDate~'$today'", sort: "-startDate");
    return result.length;
  }

  Future<int> getTaskDoneCount(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await pb.collection("tasks").getFullList(
        filter: "owner.id='$userId'&&startDate~'$today'&&isDone=true",
        sort: "-startDate");
    return result.length;
  }
}

import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:task_spark/data/category.dart';

import '../../data/task.dart';

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${(255 * a).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(255 * r).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(255 * g).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(255 * b).toInt().toRadixString(16).padLeft(2, '0')}';
}

class TaskCard extends StatefulWidget {
  final Task task;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Category? category;

  const TaskCard({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
    required this.category,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  String formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().add(Duration(hours: 9));
    final isFutureTask =
        widget.task.startDate != null && widget.task.startDate!.isAfter(now);
    final start = formatDateTime(widget.task.startDate);
    final end = formatDateTime(widget.task.endDate);

    final textColor = isFutureTask ? Colors.grey : null;

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          side: BorderSide(
              width: 2.0,
              color: HexColor.fromHex(widget.category?.color ?? "#CCBBAA"))),
      margin: EdgeInsets.symmetric(vertical: 1.h, horizontal: 3.w),
      child: ListTile(
        leading: Checkbox(
          value: widget.task.isDone ?? false,
          onChanged: isFutureTask ? null : (val) => widget.onChanged(val),
        ),
        title: Text(
          widget.task.title ?? '',
          style: TextStyle(
            fontSize: 17.sp,
            decoration: (widget.task.isDone ?? false)
                ? TextDecoration.lineThrough
                : null,
            color: textColor,
          ),
        ),
        subtitle: Text(
          '시작: $start\n종료: $end',
          style: TextStyle(fontSize: 13.sp, color: textColor),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: widget.onEdit),
            IconButton(
                icon: const Icon(Icons.delete), onPressed: widget.onDelete),
          ],
        ),
      ),
    );
  }
}

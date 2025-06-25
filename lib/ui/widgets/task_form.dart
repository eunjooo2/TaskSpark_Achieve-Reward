import 'package:flutter/material.dart';

import '../../data/category.dart'; 
import '../../data/task.dart';

class TaskForm extends StatefulWidget {
  final Task? task;
  final List<Category> categories;
  final ValueChanged<Task> onSubmit;

  const TaskForm({
    super.key,
    this.task,
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _repeatCtrl = TextEditingController();

  Category? _chosenCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  double _priority = 3;
  bool _isRepeating = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      // --- 기존 task 수정 시 로직 ---
      _titleCtrl.text = t.title ?? '';
      _descCtrl.text = t.description ?? '';
      _startDate = t.startDate;
      _endDate = t.endDate;
      _priority = double.tryParse(t.priority ?? '3') ?? 3;
      _isRepeating = (t.repeatPeriod != null &&
          t.repeatPeriod!.isNotEmpty &&
          t.isRepeatingTask == true);
      _repeatCtrl.text = t.repeatPeriod ?? '';
      _chosenCategory = widget.categories.firstWhere(
        (c) => c.id == t.categoryId,
        orElse: () => widget.categories.isNotEmpty
            ? widget.categories.first
            : Category(name: '기본'),
      );
    } else {
      // --- 새 할 일 생성 시 기본값 지정 ---
      _chosenCategory =
          widget.categories.isNotEmpty ? widget.categories.first : null;

      // ★ 여기서 기본 start/end 값을 미리 세팅
      _startDate = DateTime.now().add(const Duration(hours: 9));
      _endDate = DateTime.now().add(const Duration(days: 1, hours: 9));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showError("제목을 입력해주세요.");
      return;
    }
    if (_isRepeating && _repeatCtrl.text.trim().isEmpty) {
      _showError("반복 주기를 입력해주세요.");
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      _showError("시작일은 종료일보다 앞서야 합니다.");
      return;
    }

    final task = Task(
      title: title,
      description: _descCtrl.text.trim(),
      categoryId: _chosenCategory?.id,
      startDate: _startDate,
      endDate: _endDate,
      priority: _priority.toInt().toString(),
      repeatPeriod: _isRepeating ? _repeatCtrl.text.trim() : null,
      isRepeatingTask: _isRepeating,
    );

    widget.onSubmit(task);
    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        content: Text(msg)));
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    // 이미 initState에서 null이 없도록 보장했으므로 ! 사용
    final base = isStart ? _startDate! : _endDate!;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;

    setState(() {
      final selected =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startDate = selected;
        // 시작일이 변경됐을 때, 종료일이 그보다 이전이라면 종료일도 맞춰줄 수도 있겠죠
        if (_endDate!.isBefore(_startDate!)) {
          _endDate = _startDate!.add(Duration(days: 1));
        }
      } else {
        _endDate = selected;
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? "할 일 추가" : "할 일 수정"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: "제목")),
            TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: "설명")),
            DropdownButtonFormField<Category>(
              value: _chosenCategory,
              items: widget.categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c.name ?? '')))
                  .toList(),
              onChanged: (c) => setState(() => _chosenCategory = c),
              decoration: const InputDecoration(labelText: "카테고리"),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _pickDateTime(isStart: true),
                    child: Text(_startDate != null
                        ? "시작: ${_formatDateTime(_startDate!)}"
                        : "시작일 선택"),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _pickDateTime(isStart: false),
                    child: Text(_endDate != null
                        ? "종료: ${_formatDateTime(_endDate!)}"
                        : "종료일 선택"),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("우선순위 (${_priority.toInt()})"),
                Slider(
                  value: _priority,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _priority.toInt().toString(),
                  onChanged: (v) => setState(() => _priority = v),
                ),
              ],
            ),
            SwitchListTile(
              value: _isRepeating,
              onChanged: (v) => setState(() => _isRepeating = v),
              title: const Text("반복 설정"),
            ),
            if (_isRepeating)
              TextField(
                controller: _repeatCtrl,
                decoration:
                    const InputDecoration(labelText: "반복 주기 (예: 매주, 3일마다 등)"),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text("취소")),
        TextButton(onPressed: _submit, child: const Text("저장")),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.active,
    required this.revision,
    required this.onDataChanged,
  });
  final int userId;
  final String name;
  final bool active;
  final int revision;
  final VoidCallback onDataChanged;
  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _service = TaskService();
  final _filters = const [
    'Semua',
    'Hari Ini',
    'Mendatang',
    'Terlambat',
    'Selesai',
  ];
  List<TaskModel> _tasks = [];
  String _filter = 'Semua';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active || oldWidget.revision != widget.revision)) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _service.tasks(widget.userId);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Daftar tugas belum dapat dimuat.';
        });
      }
    }
  }

  List<TaskModel> get _visible {
    final now = DateTime.now();
    return _tasks.where((task) {
      switch (_filter) {
        case 'Hari Ini':
          return task.deadline.year == now.year &&
              task.deadline.month == now.month &&
              task.deadline.day == now.day;
        case 'Mendatang':
          final tomorrow = DateTime(
            now.year,
            now.month,
            now.day,
          ).add(const Duration(days: 1));
          return !task.isCompleted &&
              !task.isOverdue &&
              !task.deadline.isBefore(tomorrow);
        case 'Terlambat':
          return task.isOverdue;
        case 'Selesai':
          return task.isCompleted;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _addOrEdit([TaskModel? task]) async {
    final result = await Navigator.push<TaskSaveResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTaskScreen(userId: widget.userId, service: _service, task: task),
      ),
    );
    if (result == null || !mounted) return;
    widget.onDataChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.reminderScheduled || result.task.reminderMinutes == 0
                ? 'Tugas berhasil disimpan.'
                : 'Tugas tersimpan. Pengingat belum dapat dijadwalkan. Periksa izin notifikasi dan waktu pengingat.',
          ),
        ),
      );
    }
  }

  Future<void> _toggle(TaskModel task, bool completed) async {
    try {
      await _service.setCompleted(task, completed);
      widget.onDataChanged();
      if (mounted && completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas ditandai selesai.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status tugas belum dapat diperbarui.')),
        );
      }
    }
  }

  Future<void> _delete(TaskModel task) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: Text('“${task.title}” akan dihapus dari daftar tugas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await _service.delete(task);
      widget.onDataChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas belum dapat dihapus.')),
        );
      }
    }
  }

  String _today() {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final date = DateTime.now();
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final completed = _tasks.where((task) => task.isCompleted).length;
    final overdueSoon = _tasks.any(
      (task) =>
          !task.isCompleted &&
          task.deadline.isAfter(DateTime.now()) &&
          task.deadline.difference(DateTime.now()) <= const Duration(hours: 24),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _today(),
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Hai, ${widget.name}',
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Pengingat tenggat',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      overdueSoon
                          ? 'Ada tugas dengan tenggat dalam 24 jam.'
                          : 'Belum ada tenggat dalam 24 jam.',
                    ),
                  ),
                ),
                icon: Badge(
                  isLabelVisible: overdueSoon,
                  smallSize: 8,
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Tugas',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Atur tugasmu, selesaikan satu per satu.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _addOrEdit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Tugas',
                  value: '${_tasks.length}',
                  icon: Icons.list_alt_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryCard(
                  label: 'Belum Selesai',
                  value: '${_tasks.length - completed}',
                  icon: Icons.pending_actions_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryCard(
                  label: 'Selesai',
                  value: '$completed',
                  icon: Icons.task_alt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 39,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 13),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.green),
              ),
            )
          else if (_error != null)
            _InlineMessage(
              message: _error!,
              action: 'Muat ulang',
              onPressed: _load,
            )
          else if (_tasks.isEmpty)
            _EmptyTasks(onAdd: _addOrEdit)
          else if (_visible.isEmpty)
            _InlineMessage(
              message: 'Belum ada tugas pada kategori ini.',
              action: 'Lihat Semua',
              onPressed: () => setState(() => _filter = 'Semua'),
            )
          else
            ..._visible.map(
              (task) => _TaskCard(
                task: task,
                onTap: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TaskDetailScreen(task: task, service: _service),
                    ),
                  );
                  if (changed == true && mounted) {
                    widget.onDataChanged();
                  }
                },
                onToggle: (value) => _toggle(task, value),
                onEdit: () => _addOrEdit(task),
                onDelete: () => _delete(task),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FCF8),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppTheme.softGreen.withValues(alpha: .55)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.darkGreen, size: 19),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkGreen,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppTheme.ink),
        ),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final TaskModel task;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  Color get _priorityColor => switch (task.priority) {
    'Tinggi' => const Color(0xFFB94A48),
    'Sedang' => const Color(0xFFB58118),
    _ => AppTheme.green,
  };
  String _deadline() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final time = TimeOfDay.fromDateTime(task.deadline);
    return '${task.deadline.day} ${months[task.deadline.month - 1]} • ${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 11),
    color: const Color(0xFFF8FCF8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: AppTheme.softGreen.withValues(alpha: .5)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 10, 10, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (value) => onToggle(value ?? false),
              activeColor: AppTheme.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.darkGreen,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(task.category, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 9,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: task.isOverdue
                                ? const Color(0xFFB94A48)
                                : AppTheme.darkGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _deadline(),
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isOverdue
                                  ? const Color(0xFFB94A48)
                                  : AppTheme.darkGreen,
                            ),
                          ),
                        ],
                      ),
                      _PriorityLabel(
                        text: task.isCompleted
                            ? 'Selesai'
                            : task.isOverdue
                            ? 'Terlambat'
                            : task.priority,
                        color: task.isOverdue && !task.isCompleted
                            ? const Color(0xFFB94A48)
                            : _priorityColor,
                      ),
                    ],
                  ),
                  if (!task.isCompleted) ...[
                    const SizedBox(height: 5),
                    Text(
                      _remaining(),
                      style: const TextStyle(fontSize: 11, color: AppTheme.ink),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Aksi tugas',
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String _remaining() {
    if (task.isOverdue) return 'Tenggat terlewat';
    final difference = task.deadline.difference(DateTime.now());
    if (difference.inDays >= 1) return 'Sisa ${difference.inDays} hari';
    if (difference.inHours >= 1) return 'Sisa ${difference.inHours} jam';
    return 'Sisa ${difference.inMinutes.clamp(0, 59)} menit';
  }
}

class _PriorityLabel extends StatelessWidget {
  const _PriorityLabel({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
    child: Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: AppTheme.softGreen.withValues(alpha: .35),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: AppTheme.darkGreen,
            size: 35,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Belum ada tugas nih!',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppTheme.darkGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tambahkan tugas pertamamu dan mulai atur aktivitasmu.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah Tugas'),
        ),
      ],
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.action,
    required this.onPressed,
  });
  final String message;
  final String action;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(26),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}

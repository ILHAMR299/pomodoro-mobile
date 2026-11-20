import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import 'add_task_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.service,
  });
  final TaskModel task;
  final TaskService service;
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TaskModel _task = widget.task;
  bool _busy = false;

  String _date(DateTime value) {
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
    final time = TimeOfDay.fromDateTime(value);
    return '${value.day} ${months[value.month - 1]} ${value.year}, pukul ${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _edit() async {
    final result = await Navigator.push<TaskSaveResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          userId: _task.userId,
          service: widget.service,
          task: _task,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _task = result.task);
      Navigator.pop(context, true);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await widget.service.setCompleted(_task, !_task.isCompleted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _task.isCompleted
                  ? 'Tugas dibuka kembali.'
                  : 'Tugas ditandai selesai.',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status tugas belum dapat diperbarui.')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: Text('“${_task.title}” akan dihapus.'),
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
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.delete(_task);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas belum dapat dihapus.')),
        );
      }
    }
  }

  String _remaining() {
    if (_task.isOverdue) return 'Tenggat terlewat';
    final difference = _task.deadline.difference(DateTime.now());
    if (difference.inDays > 0) return '${difference.inDays} hari';
    if (difference.inHours > 0) return '${difference.inHours} jam';
    return '${difference.inMinutes.clamp(0, 59)} menit';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detail Tugas'),
      actions: [
        IconButton(
          tooltip: 'Edit tugas',
          onPressed: _edit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Hapus tugas',
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FCF8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.softGreen.withValues(alpha: .55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _task.category,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _task.title,
                  style: const TextStyle(
                    color: AppTheme.darkGreen,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Tenggat',
                  value: _date(_task.deadline),
                ),
                if (!_task.isCompleted) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'Waktu tersisa',
                    value: _remaining(),
                  ),
                ],
                const SizedBox(height: 15),
                _DetailRow(
                  icon: Icons.flag_outlined,
                  label: 'Prioritas',
                  value: _task.priority,
                ),
                const SizedBox(height: 15),
                _DetailRow(
                  icon: _task.isCompleted
                      ? Icons.task_alt_rounded
                      : Icons.pending_actions_rounded,
                  label: 'Status',
                  value: _task.isCompleted
                      ? 'Selesai'
                      : _task.isOverdue
                      ? 'Terlambat'
                      : 'Belum selesai',
                ),
                if (_task.completedAt != null) ...[
                  const SizedBox(height: 15),
                  _DetailRow(
                    icon: Icons.check_circle_outline,
                    label: 'Diselesaikan',
                    value: _date(_task.completedAt!),
                  ),
                ],
                if ((_task.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_task.description!),
                ],
                const SizedBox(height: 20),
                Text(
                  'Dibuat pada ${_date(_task.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _complete,
            icon: Icon(
              _task.isCompleted ? Icons.undo_rounded : Icons.check_rounded,
            ),
            label: Text(_task.isCompleted ? 'Buka Kembali' : 'Tandai Selesai'),
          ),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: AppTheme.green),
      const SizedBox(width: 9),
      Expanded(
        child: Text(label, style: const TextStyle(color: AppTheme.ink)),
      ),
      Text(
        value,
        style: const TextStyle(
          color: AppTheme.darkGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

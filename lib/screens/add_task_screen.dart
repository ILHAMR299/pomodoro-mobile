import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';

const reminderOptions = <int, String>{
  0: 'Tidak ada pengingat',
  1440: '1 hari sebelumnya',
  720: '12 jam sebelumnya',
  360: '6 jam sebelumnya',
  180: '3 jam sebelumnya',
  60: '1 jam sebelumnya',
  30: '30 menit sebelumnya',
};

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({
    super.key,
    required this.userId,
    required this.service,
    this.task,
  });
  final int userId;
  final TaskService service;
  final TaskModel? task;
  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  static const _categories = [
    'Pemrograman Mobile',
    'Basis Data',
    'Rekayasa Perangkat Lunak',
    'Tugas Kuliah',
    'Lainnya',
  ];
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _customCategory;
  late DateTime _deadline;
  late String _category;
  late String _priority;
  int? _reminder;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    _customCategory = TextEditingController(
      text: task != null && !_categories.contains(task.category)
          ? task.category
          : '',
    );
    _category = task == null
        ? _categories.first
        : _categories.contains(task.category)
        ? task.category
        : 'Lainnya';
    _priority = task?.priority ?? 'Sedang';
    _deadline = task?.deadline ?? DateTime.now().add(const Duration(days: 1));
    _reminder = task?.reminderMinutes;
    _loadDefaultReminder();
  }

  Future<void> _loadDefaultReminder() async {
    final preferences = await widget.service.preferences();
    if (mounted && widget.task == null) {
      setState(
        () => _reminder = preferences['default_reminder_minutes'] as int? ?? 60,
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline.isBefore(now) ? now : _deadline,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      helpText: 'Pilih tanggal tenggat',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
      helpText: 'Pilih waktu tenggat',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (time != null && mounted) {
      setState(
        () => _deadline = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (widget.task == null && !_deadline.isAfter(DateTime.now())) {
      setState(
        () => _error = 'Tenggat tugas baru harus berada di waktu mendatang.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final category = _category == 'Lainnya'
        ? _customCategory.text.trim()
        : _category;
    try {
      final result = await widget.service.save(
        existing: widget.task,
        userId: widget.userId,
        title: _title.text,
        category: category,
        description: _description.text,
        deadline: _deadline,
        priority: _priority,
        reminderMinutes: _reminder ?? 0,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tugas belum dapat disimpan. Periksa penyimpanan lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _date(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.task == null ? 'Tambah Tugas' : 'Edit Tugas'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              children: [
                const Text(
                  'Catat rencanamu',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Satu langkah kecil membuat tugas terasa lebih ringan.',
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tugas',
                    hintText: 'Masukkan nama tugas...',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nama tugas tidak boleh kosong.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_category),
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Mata Kuliah / Kategori',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? _categories.first),
                ),
                if (_category == 'Lainnya') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customCategory,
                    decoration: const InputDecoration(
                      labelText: 'Nama kategori',
                      prefixIcon: Icon(Icons.create_outlined),
                    ),
                    validator: (value) =>
                        _category == 'Lainnya' &&
                            (value == null || value.trim().isEmpty)
                        ? 'Pilih atau tulis kategori tugas.'
                        : null,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (opsional)',
                    hintText: 'Menyelesaikan laporan praktikum...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tenggat',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    '${_date(_deadline)} • ${TimeOfDay.fromDateTime(_deadline).format(context)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: AppTheme.darkGreen,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Prioritas',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Rendah', label: Text('Rendah')),
                    ButtonSegment(value: 'Sedang', label: Text('Sedang')),
                    ButtonSegment(value: 'Tinggi', label: Text('Tinggi')),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (value) =>
                      setState(() => _priority = value.first),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  key: ValueKey(_reminder),
                  initialValue: _reminder ?? 0,
                  decoration: const InputDecoration(
                    labelText: 'Pengingat',
                    prefixIcon: Icon(Icons.notifications_none_rounded),
                  ),
                  items: reminderOptions.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _reminder = value ?? 0),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF9C3028)),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Menyimpan…' : 'Simpan Tugas'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

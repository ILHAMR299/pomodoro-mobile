import 'package:flutter/material.dart';

import '../controllers/statistics_controller.dart';
import '../models/focus_session_model.dart';
import '../models/task_model.dart';
import '../services/focus_session_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weekly_productivity_chart.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.userId,
    required this.active,
    required this.revision,
  });

  final int userId;
  final bool active;
  final int revision;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _service = TaskService();
  final _focusService = FocusSessionService();
  List<TaskModel> _tasks = [];
  List<FocusSessionModel> _focusSessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active || widget.revision != oldWidget.revision)) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _service.tasks(widget.userId),
        _focusService.sessionsForUser(widget.userId),
      ]);
      final tasks = results[0] as List<TaskModel>;
      final focusSessions = results[1] as List<FocusSessionModel>;
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _focusSessions = focusSessions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Statistik belum dapat dimuat.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.green),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Muat Ulang')),
          ],
        ),
      );
    }

    final stats = StatisticsController(_tasks, focusSessions: _focusSessions);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const Text(
            'Ringkasan Produktivitas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Lihat perkembangan langkah fokusmu.'),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Ringkasan Minggu Ini',
            child: Column(children: [
              Row(children: [
                SizedBox(
                  width: 82,
                  height: 82,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: stats.completionRate),
                        duration: const Duration(milliseconds: 700),
                        builder: (context, value, _) => CircularProgressIndicator(
                          value: value,
                          strokeWidth: 8,
                          backgroundColor: AppTheme.softGreen.withValues(alpha: .4),
                          valueColor: const AlwaysStoppedAnimation(AppTheme.green),
                        ),
                      ),
                      Text(
                        '${(stats.completionRate * 100).round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: Text(
                    stats.total == 0
                        ? 'Tambahkan tugas untuk melihat tingkat penyelesaian.'
                        : '${stats.completed} dari ${stats.total} tugas telah diselesaikan.',
                    style: const TextStyle(color: AppTheme.ink),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth > 430 ? 3 : 2;
                final metrics = [
                  ('Total tugas', stats.total, AppTheme.darkGreen),
                  ('Selesai', stats.completed, AppTheme.darkGreen),
                  ('Belum selesai', stats.pending, AppTheme.darkGreen),
                  ('Sesi fokus', stats.focusSessionCount, AppTheme.darkGreen),
                  ('Terlambat', stats.overdue, const Color(0xFFB94A48)),
                ];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: metrics.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 8, mainAxisSpacing: 10, childAspectRatio: 1.7),
                  itemBuilder: (context, index) {
                    final item = metrics[index];
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${item.$2}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: item.$3)),
                      Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.ink)),
                    ]);
                  },
                );
              }),
            ]),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Tugas Selesai 7 Hari',
            child: WeeklyProductivityChart(values: stats.completedByDay, unit: 'tugas', emptyMessage: 'Belum ada tugas selesai dalam 7 hari terakhir.'),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Sesi Fokus 7 Hari',
            child: WeeklyProductivityChart(values: stats.focusSessionsByDay, unit: 'sesi', emptyMessage: 'Selesaikan sesi Pomodoro untuk melihat progres fokus.'),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Prioritas Tugas',
            child: Column(
              children: [
                _PriorityRow(
                  label: 'Rendah',
                  value: stats.countPriority('Rendah'),
                  total: stats.total,
                  color: AppTheme.green,
                ),
                const SizedBox(height: 13),
                _PriorityRow(
                  label: 'Sedang',
                  value: stats.countPriority('Sedang'),
                  total: stats.total,
                  color: const Color(0xFFB58118),
                ),
                const SizedBox(height: 13),
                _PriorityRow(
                  label: 'Tinggi',
                  value: stats.countPriority('Tinggi'),
                  total: stats.total,
                  color: const Color(0xFFB94A48),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Riwayat Selesai',
            child: stats.history.isEmpty
                ? const Text('Tugas yang selesai akan muncul di sini.')
                : Column(
                    children: stats.history
                        .take(8)
                        .map(
                          (task) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.green,
                            ),
                            title: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              task.completedAt == null
                                  ? 'Tanggal selesai tidak tersedia'
                                  : _completedDate(task.completedAt!),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  String _completedDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FCF8),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: AppTheme.softGreen.withValues(alpha: .5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkGreen,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 15),
        child,
      ],
    ),
  );
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });
  final String label;
  final int value;
  final int total;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 58, child: Text(label)),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 9,
            backgroundColor: AppTheme.softGreen.withValues(alpha: .35),
            color: color,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WeeklyProductivityChart extends StatefulWidget {
  const WeeklyProductivityChart({super.key, required this.values, required this.unit, required this.emptyMessage});
  final List<int> values;
  final String unit;
  final String emptyMessage;

  @override
  State<WeeklyProductivityChart> createState() => _WeeklyProductivityChartState();
}

class _WeeklyProductivityChartState extends State<WeeklyProductivityChart> {
  int? _selected;
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  void didUpdateWidget(covariant WeeklyProductivityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final maxValue = values.fold<int>(0, (max, value) => value > max ? value : max);
    final selection = _selected ?? (values.lastIndexWhere((value) => value > 0) < 0 ? 6 : values.lastIndexWhere((value) => value > 0));
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    if (maxValue == 0) {
      return SizedBox(height: 150, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.insights_outlined, color: AppTheme.green, size: 30),
        const SizedBox(height: 9),
        Text(widget.emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.ink)),
      ])));
    }
    final maxY = (maxValue + 1).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 190, child: BarChart(BarChartData(
        maxY: maxY,
        barGroups: List.generate(7, (index) => BarChartGroupData(x: index, showingTooltipIndicators: index == selection ? [0] : [], barRods: [
          BarChartRodData(toY: values[index].toDouble(), color: index == selection ? AppTheme.darkGreen : AppTheme.green, width: 18, borderRadius: BorderRadius.circular(5)),
        ])),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 27, interval: maxY <= 4 ? 1 : (maxY / 3).ceilToDouble(), getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppTheme.ink)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (value, meta) {
            final index = value.toInt(); if (index < 0 || index > 6) return const SizedBox.shrink();
            return SideTitleWidget(meta: meta, child: Text(_days[first.add(Duration(days: index)).weekday - 1], style: TextStyle(fontSize: 10, fontWeight: selection == index ? FontWeight.w700 : FontWeight.normal, color: selection == index ? AppTheme.darkGreen : AppTheme.ink)));
          })),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY <= 4 ? 1 : (maxY / 3).ceilToDouble()), borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(touchCallback: (event, response) { if (!event.isInterestedForInteractions) return; final index = response?.spot?.touchedBarGroupIndex; if (index != null && index >= 0 && index < 7) setState(() => _selected = index); },
          touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => AppTheme.darkGreen, getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${_days[first.add(Duration(days: groupIndex)).weekday - 1]}\n${rod.toY.toInt()} ${widget.unit}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))),
      ), duration: const Duration(milliseconds: 250))),
      const SizedBox(height: 7),
      Text('${_days[first.add(Duration(days: selection)).weekday - 1]}: ${values[selection]} ${widget.unit}', style: const TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.w600)),
    ]);
  }
}

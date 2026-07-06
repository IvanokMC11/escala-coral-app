import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/report.dart';
import '../providers/app_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _year;
  late int _month;
  Top10Response? _top10;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppState>().api;
      _top10 = await api.getTop10(_year, _month);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar reportes')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) {
        _month = 1;
        _year++;
      } else if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat('MMMM yyyy', 'es')
        .format(DateTime(_year, _month));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          monthName[0].toUpperCase() +
                              monthName.substring(1),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_top10 != null) ...[
                      Text('TOP 10 - Asistencias',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (_top10!.ranking.isNotEmpty)
                        _AttendanceChart(data: _top10!.ranking),
                      const SizedBox(height: 24),
                      _Top10Table(
                        ranking: _top10!.ranking,
                        totalRehearsals: _top10!.totalRehearsals,
                      ),
                    ],
                    if (_top10 == null || _top10!.ranking.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.bar_chart,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text('Sin datos para este mes',
                                  style: theme.textTheme.bodyLarge),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  final List<MonthlyReport> data;
  const _AttendanceChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top5 = data.take(5).toList();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barGroups: top5.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: r.attendancePercentage,
                  color: _getBarColor(i),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                    style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx >= 0 && idx < top5.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(top5[idx].memberName.split(' ').first,
                          style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) => FlLine(
              color: theme.colorScheme.outlineVariant,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Color _getBarColor(int i) {
    const colors = [
      Colors.purple,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
    ];
    return colors[i % colors.length];
  }
}

class _Top10Table extends StatelessWidget {
  final List<MonthlyReport> ranking;
  final int totalRehearsals;
  const _Top10Table(
      {required this.ranking, required this.totalRehearsals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ranking.length} miembros - $totalRehearsals ensayos',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
                2: IntrinsicColumnWidth(),
                3: IntrinsicColumnWidth(),
                4: IntrinsicColumnWidth(),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant)),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Tard.', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Multa', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...ranking.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  final isTop3 = i < 3;
                  return TableRow(
                    decoration: isTop3
                        ? BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3))
                        : null,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            if (isTop3)
                              Icon(
                                [Icons.emoji_events, Icons.emoji_events,
                                    Icons.emoji_events][i],
                                color: [Colors.amber, Colors.grey, Colors.brown][i],
                                size: 18,
                              ),
                            if (!isTop3)
                              Text('${i + 1}',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Text(r.memberName, style: const TextStyle(fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Text(
                          '${r.attendancePercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: r.attendancePercentage >= 90
                                ? Colors.green
                                : r.attendancePercentage >= 70
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Text('${r.totalLateMinutes}min',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Text(
                            'S/ ${r.totalFine.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _hours = 6;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final from = now.subtract(Duration(hours: _hours));
    final pts = app.history.where((p) => p.t.isAfter(from)).toList();
    final today = app.today;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (app.isDemo)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Mode demo tidak dicatat ke riwayat. Riwayat terisi saat terhubung ke baterai sungguhan.',
                style: TextStyle(color: AppColors.info, fontSize: 13)),
          ),
        Row(children: [
          Expanded(
            child: StatTile(
              icon: Icons.north_east_rounded,
              label: 'dipakai hari ini',
              value: _wh(today?.outWh ?? 0),
              unit: (today?.outWh ?? 0) >= 1000 ? 'kWh' : 'Wh',
              color: AppColors.good,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              icon: Icons.south_west_rounded,
              label: 'dicas hari ini',
              value: _wh(today?.inWh ?? 0),
              unit: (today?.inWh ?? 0) >= 1000 ? 'kWh' : 'Wh',
              color: AppColors.caution,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('1 jam')),
              ButtonSegment(value: 6, label: Text('6 jam')),
              ButtonSegment(value: 24, label: Text('24 jam')),
              ButtonSegment(value: 72, label: Text('3 hari')),
            ],
            selected: {_hours},
            onSelectionChanged: (s) => setState(() => _hours = s.first),
          ),
        ),
        const SizedBox(height: 12),
        if (pts.length < 2)
          const SectionCard(
            child: EmptyState(
              icon: Icons.show_chart_rounded,
              title: 'Belum cukup data',
              text: 'Aplikasi mencatat 1 titik per menit selama terhubung ke baterai. '
                  'Catatan berhenti saat aplikasi ditutup atau di latar belakang.',
            ),
          )
        else ...[
          _ChartCard(
            title: 'ISI BATERAI (%)',
            from: from,
            hours: _hours,
            spots: [for (final p in pts) FlSpot(_x(p.t, from), p.soc.toDouble())],
            color: AppColors.good,
            minY: 0,
            maxY: 100,
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'DAYA (W)  •  + dicas / − dipakai',
            from: from,
            hours: _hours,
            spots: [for (final p in pts) FlSpot(_x(p.t, from), p.voltage * p.current)],
            color: AppColors.accent,
            zeroLine: true,
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'SUHU TERTINGGI (°C)',
            from: from,
            hours: _hours,
            spots: [for (final p in pts) FlSpot(_x(p.t, from), p.temp)],
            color: AppColors.caution,
          ),
        ],
        const SizedBox(height: 12),
        if (app.energy.length >= 2) _EnergyBars(days: app.energy.sublist(max(0, app.energy.length - 7))),
      ],
    );
  }

  static double _x(DateTime t, DateTime from) => t.difference(from).inSeconds / 60.0;

  static String _wh(double wh) => wh >= 1000 ? (wh / 1000).toStringAsFixed(2) : wh.toStringAsFixed(0);
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.from,
    required this.hours,
    required this.spots,
    required this.color,
    this.minY,
    this.maxY,
    this.zeroLine = false,
  });

  final String title;
  final DateTime from;
  final int hours;
  final List<FlSpot> spots;
  final Color color;
  final double? minY;
  final double? maxY;
  final bool zeroLine;

  @override
  Widget build(BuildContext context) {
    final totalMin = hours * 60.0;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 4), child: CardTitle(title)),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: totalMin,
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: zeroLine && v == 0 ? AppColors.muted : AppColors.line,
                    strokeWidth: zeroLine && v == 0 ? 1.2 : 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface2,
                    getTooltipItems: (items) => items
                        .map((s) => LineTooltipItem(
                              '${_time(from.add(Duration(seconds: (s.x * 60).round())))}\n${s.y.toStringAsFixed(s.y.abs() < 100 ? 1 : 0)}',
                              const TextStyle(color: AppColors.text, fontSize: 12),
                            ))
                        .toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) => Text(
                        v.abs() >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: totalMin / 4,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          hours > 24
                              ? _day(from.add(Duration(minutes: v.round())))
                              : _time(from.add(Duration(minutes: v.round()))),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static String _day(DateTime t) => '${_days[t.weekday - 1]} ${t.hour.toString().padLeft(2, '0')}';
}

class _EnergyBars extends StatelessWidget {
  const _EnergyBars({required this.days});
  final List<DailyEnergy> days;

  @override
  Widget build(BuildContext context) {
    final maxV = days.map((d) => max(d.outWh, d.inWh)).fold<double>(10, max);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(left: 4), child: CardTitle('ENERGI HARIAN (Wh)')),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Row(children: [
              _Legend(AppColors.good, 'dipakai'),
              SizedBox(width: 14),
              _Legend(AppColors.caution, 'dicas'),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxV * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(days[i].day.substring(8), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(x: i, barsSpace: 3, barRods: [
                      BarChartRodData(toY: days[i].outWh, color: AppColors.good, width: 9, borderRadius: BorderRadius.circular(3)),
                      BarChartRodData(toY: days[i].inWh, color: AppColors.caution, width: 9, borderRadius: BorderRadius.circular(3)),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
}

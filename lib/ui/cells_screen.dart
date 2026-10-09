import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/insights.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

class CellsScreen extends StatelessWidget {
  const CellsScreen({super.key});

  // Rentang aman tegangan sel LFP untuk skala tampilan.
  static const vMin = 2.8;
  static const vMax = 3.65;

  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppState>().reading;
    if (r == null) {
      return const Center(
        child: EmptyState(icon: Icons.grid_view_rounded, title: 'Belum ada data sel', text: 'Hubungkan baterai dulu.'),
      );
    }
    final bl = Insights.balanceLevel(r.deltaCell);
    final maxI = r.maxCellIndex;
    final minI = r.minCellIndex;
    // Selisih < 5 mV dianggap sama; jangan menandai sel agar tidak membingungkan.
    final sameAll = r.deltaCell < 0.005;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('KESEIMBANGAN SEL'),
              const SizedBox(height: 10),
              Row(children: [
                LevelDot(bl, size: 14),
                const SizedBox(width: 10),
                Text(Insights.balanceText(r.deltaCell),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: bl.color)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Baterai Anda terdiri dari ${r.cellCount} sel kecil yang disusun seri. '
                'Idealnya semua sel bertegangan sama. Selisih saat ini '
                '${(r.deltaCell * 1000).toStringAsFixed(0)} mV.',
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _MiniStat('Tertinggi', '${r.maxCell.toStringAsFixed(3)} V', sameAll ? '' : 'sel #${maxI + 1}', AppColors.good)),
                Expanded(child: _MiniStat('Rata-rata', '${r.avgCell.toStringAsFixed(3)} V', '', AppColors.accent)),
                Expanded(child: _MiniStat('Terendah', '${r.minCell.toStringAsFixed(3)} V', sameAll ? '' : 'sel #${minI + 1}', AppColors.caution)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: r.cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.7,
            ),
            itemBuilder: (context, i) => _CellTile(
              index: i,
              voltage: r.cellVoltages[i],
              isMax: !sameAll && i == maxI,
              isMin: !sameAll && i == minI,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(18, 4, 10, 4),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const CardTitle('HAMBATAN KABEL SEL'),
              subtitle: const Text('Nilai yang jauh lebih tinggi dari lainnya = kabel balancer longgar',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              children: [
                for (var i = 0; i < r.cellResistances.length; i++)
                  KeyValue('Kabel sel #${i + 1}', '${r.cellResistances[i].toStringAsFixed(3)} Ω'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.sub, this.color);
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, fontFeatures: tabular)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      );
}

class _CellTile extends StatelessWidget {
  const _CellTile({required this.index, required this.voltage, required this.isMax, required this.isMin});
  final int index;
  final double voltage;
  final bool isMax;
  final bool isMin;

  @override
  Widget build(BuildContext context) {
    final f = ((voltage - CellsScreen.vMin) / (CellsScreen.vMax - CellsScreen.vMin)).clamp(0.02, 1.0);
    final danger = voltage < 2.9 || voltage > 3.65;
    final color = danger
        ? AppColors.bad
        : isMax
            ? AppColors.good
            : isMin
                ? AppColors.caution
                : AppColors.accent;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isMax || isMin || danger) ? color.withValues(alpha: 0.7) : AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Column(
        children: [
          Text('#${index + 1}', style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.line, width: 1.5),
              ),
              padding: const EdgeInsets.all(2),
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: f,
                child: Container(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(voltage.toStringAsFixed(3),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFeatures: tabular)),
          ),
        ],
      ),
    );
  }
}

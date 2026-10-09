import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/insights.dart';
import '../models/bms_models.dart';
import '../services/bms_link.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/motor_scene.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = app.reading;
    final status = MotorStatus.of(app.motorState, r);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (app.isDemo) ...[_DemoBar(app: app), const SizedBox(height: 12)],
        _HeroCard(app: app, status: status),
        const SizedBox(height: 12),
        if (r == null)
          const SectionCard(
            child: EmptyState(
              icon: Icons.hourglass_top_rounded,
              title: 'Menunggu data dari BMS',
              text: 'Biasanya hanya beberapa detik setelah terhubung.',
            ),
          )
        else ...[
          _BatteryCard(app: app, r: r),
          const SizedBox(height: 12),
          _QuickStats(app: app, r: r),
          const SizedBox(height: 12),
          _HealthCard(r: r),
          const SizedBox(height: 12),
          _DetailCard(app: app, r: r),
        ],
      ],
    );
  }
}

class _DemoBar extends StatelessWidget {
  const _DemoBar({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      color: AppColors.info.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mode demo: data contoh, bukan dari baterai Anda',
              style: TextStyle(fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<DemoScenario>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: DemoScenario.parked, label: Text('Parkir')),
                ButtonSegment(value: DemoScenario.riding, label: Text('Jalan')),
                ButtonSegment(value: DemoScenario.charging, label: Text('Dicas')),
              ],
              selected: {app.demoScenario ?? DemoScenario.parked},
              onSelectionChanged: (s) => app.setDemoScenario(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.app, required this.status});
  final AppState app;
  final MotorStatus status;

  @override
  Widget build(BuildContext context) {
    final soc = app.reading?.soc ?? 0;
    final motorColor = AppColors.motorColors[app.settings.motorColor.clamp(0, AppColors.motorColors.length - 1)];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: status.color.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [status.color.withValues(alpha: 0.16), AppColors.surface],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: status.color.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Icon(status.icon, color: status.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status.title,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: status.color)),
                    const SizedBox(height: 2),
                    Text(status.subtitle, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MotorScene(state: app.motorState, soc: soc, bodyColor: motorColor),
        ],
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.app, required this.r});
  final AppState app;
  final BmsReading r;

  @override
  Widget build(BuildContext context) {
    final charging = app.motorState == MotorState.charging;
    final color = Insights.socColor(r.soc);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('ISI BATERAI'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.soc}',
                  style: TextStyle(fontSize: 64, height: 1, fontWeight: FontWeight.w900, color: color, fontFeatures: tabular)),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text('%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('± ${app.estimatedRangeKm.toStringAsFixed(0)} km',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                  const Text('perkiraan jarak', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          BigBattery(soc: r.soc, charging: charging),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(Insights.socAdvice(r.soc, app.motorState), style: const TextStyle(fontSize: 14))),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.app, required this.r});
  final AppState app;
  final BmsReading r;

  @override
  Widget build(BuildContext context) {
    final h = app.hoursEstimate;
    final charging = app.motorState == MotorState.charging;
    final power = r.power;
    final powerLabel = power > 1
        ? 'daya masuk'
        : power < -1
            ? 'daya keluar'
            : 'daya';
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: charging ? Icons.battery_charging_full_rounded : Icons.timer_outlined,
            label: charging ? 'sampai penuh' : 'sisa waktu',
            value: h == null ? '–' : Insights.formatDuration(h),
            color: charging ? AppColors.caution : AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: power >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
            label: powerLabel,
            value: power.abs() >= 1000 ? (power.abs() / 1000).toStringAsFixed(1) : power.abs().toStringAsFixed(0),
            unit: power.abs() >= 1000 ? 'kW' : 'W',
            color: power > 1
                ? AppColors.caution
                : power < -1
                    ? AppColors.good
                    : AppColors.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: Icons.thermostat_rounded,
            label: 'suhu baterai',
            value: r.maxTemp.toStringAsFixed(0),
            unit: '°C',
            color: r.maxTemp >= 45 ? AppColors.caution : AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.r});
  final BmsReading r;

  @override
  Widget build(BuildContext context) {
    final items = Insights.health(r);
    final overall = Insights.overall(items);
    final infos = r.alarms.where((a) => a.level == AlarmLevel.info).toList();
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('KONDISI BATERAI'),
          const SizedBox(height: 10),
          Row(children: [
            Icon(
              overall == Level.good ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: overall.color,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(Insights.overallText(overall),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: overall.color)),
            ),
          ]),
          const SizedBox(height: 6),
          for (final i in items) _HealthRow(item: i),
          if (infos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in infos)
                  Tooltip(
                    message: a.advice,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Chip(
                      avatar: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                      label: Text(a.title, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.info.withValues(alpha: 0.08),
                      side: BorderSide(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.item});
  final HealthItem item;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(right: 8),
        childrenPadding: const EdgeInsets.fromLTRB(40, 0, 16, 10),
        expandedAlignment: Alignment.centerLeft,
        leading: Icon(item.icon, color: AppColors.muted, size: 22),
        title: Text(item.title, style: const TextStyle(fontSize: 15)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(item.value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: item.level.color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          LevelDot(item.level),
        ]),
        children: [Text(item.explain, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4))],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.app, required this.r});
  final AppState app;
  final BmsReading r;

  @override
  Widget build(BuildContext context) {
    final info = app.deviceInfo;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(18, 4, 10, 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const CardTitle('DETAIL TEKNIS'),
          subtitle: const Text('Untuk teknisi / yang ingin tahu angka lengkap',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          childrenPadding: const EdgeInsets.only(right: 8, bottom: 12),
          children: [
            KeyValue('Tegangan total', '${r.totalVoltage.toStringAsFixed(2)} V'),
            KeyValue('Arus', '${r.current.toStringAsFixed(2)} A'),
            KeyValue('Daya', '${r.power.toStringAsFixed(0)} W'),
            KeyValue('Sisa kapasitas', '${r.remainingAh.toStringAsFixed(1)} / ${r.nominalAh.toStringAsFixed(1)} Ah'),
            KeyValue('Energi tersisa (± nominal)', '${(r.remainingWh / 1000).toStringAsFixed(2)} kWh'),
            KeyValue('Jumlah sel', '${r.cellCount} sel ${r.batteryTypeLabel}'),
            KeyValue('Rata-rata sel', '${r.avgCell.toStringAsFixed(3)} V'),
            KeyValue('Selisih sel', '${r.deltaCell.toStringAsFixed(3)} V'),
            KeyValue('Siklus cas', '${r.cycleCount}x'),
            KeyValue('Total kapasitas siklus', '${r.cycleCapacityAh.toStringAsFixed(1)} Ah'),
            KeyValue('Suhu T1 / T2 / BMS',
                '${r.temp1.toStringAsFixed(1)} / ${r.temp2.toStringAsFixed(1)} / ${r.mosTemp.toStringAsFixed(1)} °C'),
            KeyValue('Balancing', r.balancing ? 'Aktif (${r.balanceCurrent.toStringAsFixed(3)} A)' : 'Tidak aktif'),
            KeyValue('Waktu BMS menyala', Insights.formatRuntime(r.runtimeSeconds)),
            if (r.detailLogCount != null) KeyValue('Jumlah log', '${r.detailLogCount}'),
            if (info != null) ...[
              KeyValue('Model', info.model),
              KeyValue('Hardware / Software', '${info.hardwareVersion} / ${info.softwareVersion}'),
            ],
            KeyValue('Protokol', app.activeProtocol?.label ?? '-'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/insights.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  int? _busy;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = app.reading;
    final sw = app.switches;

    if (!app.settings.controlsUnlocked) return _Locked(app: app);
    if (r == null) {
      return const Center(
        child: EmptyState(icon: Icons.toggle_off_rounded, title: 'Belum terhubung', text: 'Hubungkan baterai untuk memakai kontrol.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SectionCard(
          color: AppColors.caution.withValues(alpha: 0.07),
          padding: const EdgeInsets.all(14),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.caution),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tombol di bawah mengubah setelan BMS secara langsung. '
                'Perubahan tetap berlaku walau aplikasi ditutup.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _SwitchCard(
          icon: Icons.ev_station_rounded,
          title: 'Izinkan pengisian (Charge)',
          explain: 'Matikan bila ingin mencegah baterai dicas, misalnya charger dicurigai rusak.',
          value: sw?.charge ?? r.chargeEnabled,
          actual: r.chargeEnabled,
          busy: _busy == regCharge,
          onChanged: (v) => _toggle(app, regCharge, v, 'pengisian'),
        ),
        const SizedBox(height: 12),
        _SwitchCard(
          icon: Icons.two_wheeler_rounded,
          title: 'Alirkan daya ke motor (Discharge)',
          explain: 'Jika dimatikan, motor TIDAK BISA jalan. Berguna sebagai pengaman saat parkir lama.',
          value: sw?.discharge ?? r.dischargeEnabled,
          actual: r.dischargeEnabled,
          busy: _busy == regDischarge,
          danger: true,
          onChanged: (v) => _toggle(app, regDischarge, v, 'daya ke motor'),
        ),
        const SizedBox(height: 12),
        _SwitchCard(
          icon: Icons.balance_rounded,
          title: 'Penyeimbang sel (Balancer)',
          explain: 'Menyamakan tegangan antar sel saat mengecas. Sebaiknya selalu ON.',
          value: sw?.balancer ?? true,
          actual: null,
          busy: _busy == regBalance,
          onChanged: (v) => _toggle(app, regBalance, v, 'balancer'),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: () => app.updateSettings((s) => s.controlsUnlocked = false),
            icon: const Icon(Icons.lock_rounded, size: 18),
            label: const Text('Kunci kembali kontrol'),
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(AppState app, int reg, bool on, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    if (reg == regDischarge && !on && (app.motorState == MotorState.riding || app.isDrawingPower)) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.dangerous_rounded, color: AppColors.bad, size: 40),
          title: const Text('Tidak bisa sekarang'),
          content: const Text(
              'Motor terdeteksi sedang jalan. Mematikan daya saat berkendara sangat berbahaya. Berhenti dan matikan motor dulu.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Mengerti'))],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${on ? 'Nyalakan' : 'Matikan'} $name?'),
        content: Text(reg == regDischarge && !on
            ? 'Motor tidak akan bisa jalan sampai Anda menyalakannya lagi dari aplikasi ini.'
            : 'Setelan BMS akan diubah sekarang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            style: (!on && reg == regDischarge) ? FilledButton.styleFrom(backgroundColor: AppColors.bad) : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(on ? 'Nyalakan' : 'Matikan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = reg);
    try {
      await app.setSwitch(reg, on);
      messenger.showSnackBar(SnackBar(content: Text('Perintah terkirim: $name ${on ? 'ON' : 'OFF'}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SectionCard(
          child: Column(children: [
            const Icon(Icons.lock_rounded, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('Kontrol dikunci', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Di sini Anda bisa menyalakan/mematikan pengisian, aliran daya ke motor, dan balancer. '
              'Dikunci supaya tidak tersentuh tanpa sengaja.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Buka kunci kontrol?'),
                    content: const Text(
                        'Fitur ini mengirim perintah ke BMS. Jangan matikan daya motor saat sedang berkendara.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Saya mengerti')),
                    ],
                  ),
                );
                if (ok == true) app.updateSettings((s) => s.controlsUnlocked = true);
              },
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Buka kunci'),
            ),
          ]),
        ),
      ],
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.title,
    required this.explain,
    required this.value,
    required this.actual,
    required this.busy,
    required this.onChanged,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String explain;
  final bool value;
  final bool? actual;
  final bool busy;
  final bool danger;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.good : (danger ? AppColors.bad : AppColors.muted);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value ? 'ON' : 'OFF', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ]),
            ),
            if (busy)
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
            else
              Switch.adaptive(value: value, onChanged: onChanged),
          ]),
          const SizedBox(height: 10),
          Text(explain, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
          if (actual != null && actual != value) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan: saat ini jalur ${actual! ? 'masih tersambung' : 'diputus'} oleh BMS'
              '${!actual! && value ? ' (kemungkinan karena perlindungan otomatis)' : ''}.',
              style: const TextStyle(color: AppColors.caution, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

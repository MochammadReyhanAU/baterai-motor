import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';

import '../logic/insights.dart';
import '../services/ble_link.dart';
import '../services/ble_permissions.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/motor_scene.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  StreamSubscription<FoundDevice>? _scanSub;
  StreamSubscription<BleStatus>? _statusSub;
  BleStatus _status = BleStatus.unknown;
  final Map<String, FoundDevice> _found = {};
  bool _scanning = false;
  String? _error;
  bool _permanentlyDenied = false;
  Timer? _stopTimer;

  @override
  void dispose() {
    _scanSub?.cancel();
    _statusSub?.cancel();
    _stopTimer?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    final app = context.read<AppState>();
    if (kIsWeb) {
      setState(() => _error = 'Bluetooth hanya tersedia di aplikasi HP. Di sini silakan coba mode demo.');
      return;
    }
    final perm = await BlePermissions.ensure();
    if (!mounted) return;
    if (!perm.ok) {
      setState(() {
        _error = perm.message;
        _permanentlyDenied = perm.permanentlyDenied;
      });
      return;
    }
    final needLoc = await BlePermissions.needsLocationService();
    if (!mounted) return;
    final scanner = app.scanner();
    _statusSub ??= scanner.status.listen((s) => setState(() => _status = s));
    _scanSub?.cancel();
    setState(() {
      _found.clear();
      _scanning = true;
      _error = null;
      _permanentlyDenied = false;
    });
    _scanSub = scanner.scan(requireLocation: needLoc).listen(
      (d) => setState(() => _found[d.id] = d),
      onError: (Object e) => setState(() {
        _scanning = false;
        _error = needLoc
            ? 'Gagal mencari. Pastikan Lokasi (GPS) di HP menyala. ($e)'
            : 'Gagal mencari: $e';
      }),
    );
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 15), _stopScan);
  }

  void _stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect(FoundDevice d) async {
    _stopScan();
    await context.read<AppState>().connectTo(d.id, d.name);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = _found.values.toList()
      ..sort((a, b) {
        if (a.looksLikeJk != b.looksLikeJk) return a.looksLikeJk ? -1 : 1;
        return b.rssi.compareTo(a.rssi);
      });
    final jk = list.where((d) => d.looksLikeJk).toList();
    final others = list.where((d) => !d.looksLikeJk).toList();
    final motorColor = AppColors.motorColors[app.settings.motorColor.clamp(0, AppColors.motorColors.length - 1)];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text('Baterai Motor', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Pantau baterai motor listrik Anda dengan mudah',
                style: TextStyle(color: AppColors.muted, fontSize: 15)),
            const SizedBox(height: 8),
            MotorScene(state: MotorState.offline, soc: 0, bodyColor: motorColor, height: 170),
            const SizedBox(height: 8),
            if (_status == BleStatus.poweredOff)
              _Notice(Icons.bluetooth_disabled_rounded, 'Bluetooth mati. Nyalakan Bluetooth di HP Anda.'),
            if (_status == BleStatus.unauthorized)
              _Notice(Icons.lock_rounded, 'Izin Bluetooth belum diberikan. Ketuk "Cari baterai saya" lalu izinkan, atau buka setelan aplikasi.'),
            if (_error != null) _Notice(Icons.error_outline_rounded, _error!),
            if (_permanentlyDenied)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: BlePermissions.openSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Buka setelan izin aplikasi'),
                ),
              ),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                onPressed: _scanning ? _stopScan : _startScan,
                icon: _scanning
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF042F36)))
                    : const Icon(Icons.bluetooth_searching_rounded),
                label: Text(_scanning ? 'Mencari… (ketuk untuk berhenti)' : 'Cari baterai saya'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                onPressed: () => app.startDemo(),
                icon: const Icon(Icons.science_rounded),
                label: const Text('Coba mode demo'),
              ),
            ),
            const SizedBox(height: 20),
            if (jk.isNotEmpty) ...[
              const CardTitle('BMS DITEMUKAN'),
              const SizedBox(height: 8),
              for (final d in jk) _DeviceTile(d: d, onTap: () => _connect(d), highlight: true),
              const SizedBox(height: 16),
            ],
            if (others.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: CardTitle('PERANGKAT LAIN (${others.length})'),
                  subtitle: const Text('Pilih dari sini jika nama BMS Anda sudah diganti',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  children: [for (final d in others) _DeviceTile(d: d, onTap: () => _connect(d))],
                ),
              ),
            if (!_scanning && list.isEmpty) ...[
              const SizedBox(height: 4),
              const SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CardTitle('SEBELUM MENCARI'),
                  SizedBox(height: 10),
                  _Tip('1', 'Dekatkan HP ke motor (maks. ± 5 meter).'),
                  _Tip('2', 'Tutup aplikasi JK BMS. BMS hanya bisa terhubung ke satu HP/aplikasi sekaligus.'),
                  _Tip('3', 'Pastikan BMS aktif. Jika tertidur, nyalakan motor sebentar atau tekan tombol BMS.'),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.d, required this.onTap, this.highlight = false});
  final FoundDevice d;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bars = d.rssi > -60 ? 3 : d.rssi > -75 ? 2 : 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlight ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: highlight ? AppColors.accent.withValues(alpha: 0.4) : AppColors.line),
          ),
          leading: Icon(highlight ? Icons.battery_charging_full_rounded : Icons.bluetooth_rounded,
              color: highlight ? AppColors.accent : AppColors.muted),
          title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Sinyal ${['', 'lemah', 'sedang', 'kuat'][bars]}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.n, this.text);
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.accent.withValues(alpha: 0.15),
            child: Text(n, style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.caution.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.caution),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

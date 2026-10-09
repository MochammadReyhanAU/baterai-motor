import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('MOTOR'),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: s.motorName,
                decoration: const InputDecoration(labelText: 'Nama motor'),
                onFieldSubmitted: (v) => app.updateSettings((x) => x.motorName = v.trim().isEmpty ? 'Motor Saya' : v.trim()),
              ),
              const SizedBox(height: 16),
              const Text('Warna motor di gambar', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                for (var i = 0; i < AppColors.motorColors.length; i++)
                  GestureDetector(
                    onTap: () => app.updateSettings((x) => x.motorColor = i),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.motorColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(color: s.motorColor == i ? Colors.white : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('PERKIRAAN JARAK'),
              const SizedBox(height: 8),
              Text('Saat baterai penuh 100%, motor bisa menempuh sekitar ${s.fullRangeKm.toStringAsFixed(0)} km',
                  style: const TextStyle(fontSize: 15)),
              Slider(
                value: s.fullRangeKm.clamp(10, 250),
                min: 10,
                max: 250,
                divisions: 48,
                label: '${s.fullRangeKm.toStringAsFixed(0)} km',
                onChanged: (v) => app.updateSettings((x) => x.fullRangeKm = v),
              ),
              const Text(
                'Isi sesuai pengalaman Anda (dari 100% sampai hampir habis). Perkiraan = angka ini × persen baterai. '
                'Jarak nyata tergantung berat, kecepatan, dan tanjakan.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('DETEKSI MOTOR MENYALA / JALAN'),
              const SizedBox(height: 8),
              const Text(
                'BMS tidak tahu posisi kunci kontak. Aplikasi menebak dari arus yang keluar. '
                'Cara kalibrasi: nyalakan kunci kontak tanpa jalan, lihat "Arus" di Detail Teknis, lalu atur angka pertama sedikit di bawahnya.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text('"Menyala" jika arus keluar ≥ ${s.onThresholdA.toStringAsFixed(1)} A'),
              Slider(
                value: s.onThresholdA.clamp(0.1, 3),
                min: 0.1,
                max: 3,
                divisions: 29,
                label: '${s.onThresholdA.toStringAsFixed(1)} A',
                onChanged: (v) => app.updateSettings((x) {
                  x.onThresholdA = v;
                  if (x.rideThresholdA <= v) x.rideThresholdA = v + 0.5;
                }),
              ),
              Text('"Jalan" jika arus keluar ≥ ${s.rideThresholdA.toStringAsFixed(1)} A'),
              Slider(
                value: s.rideThresholdA.clamp(0.5, 15),
                min: 0.5,
                max: 15,
                divisions: 29,
                label: '${s.rideThresholdA.toStringAsFixed(1)} A',
                onChanged: (v) => app.updateSettings((x) => x.rideThresholdA = v < x.onThresholdA + 0.5 ? x.onThresholdA + 0.5 : v),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('BMS'),
              const SizedBox(height: 4),
              KeyValue('Perangkat', s.lastDeviceName ?? (app.isDemo ? 'Mode demo' : '-')),
              if (app.deviceInfo != null) ...[
                KeyValue('Model', app.deviceInfo!.model),
                KeyValue('Hardware', app.deviceInfo!.hardwareVersion),
                KeyValue('Software', app.deviceInfo!.softwareVersion),
              ],
              const SizedBox(height: 8),
              const Text('Versi protokol', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ProtocolChoice>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ProtocolChoice.auto, label: Text('Otomatis')),
                    ButtonSegment(value: ProtocolChoice.jk02_24s, label: Text('24S lama')),
                    ButtonSegment(value: ProtocolChoice.jk02_32s, label: Text('32S baru')),
                  ],
                  selected: {s.protocol},
                  onSelectionChanged: (v) => app.updateSettings((x) => x.protocol = v.first),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Ubah hanya jika angka di aplikasi terlihat aneh (mis. suhu 0°C atau tegangan salah).',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      app.disconnect();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Putuskan'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.bad),
                    onPressed: () {
                      app.disconnect(forget: true);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Lupakan'),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('DATA'),
              const SizedBox(height: 4),
              KeyValue('Titik riwayat tersimpan', '${app.history.length}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Hapus semua riwayat?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
                      ],
                    ),
                  );
                  if (ok == true) app.clearHistory();
                },
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Hapus riwayat'),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text(
            'Baterai Motor v1.0 • Protokol JK BMS dipetakan dari proyek open-source esphome-jk-bms. '
            'Aplikasi ini tidak berafiliasi dengan JiKong.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

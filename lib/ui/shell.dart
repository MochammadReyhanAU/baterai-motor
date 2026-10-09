import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bms_link.dart';
import '../state/app_state.dart';
import 'cells_screen.dart';
import 'control_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = kIsWeb ? (int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0).clamp(0, 3) : 0;

  static const _titles = ['Beranda', 'Sel Baterai', 'Riwayat', 'Kontrol'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? app.settings.motorName : _titles[_tab]),
        actions: [
          _LinkChip(app: app),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _Banner(app: app),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [HomeScreen(), CellsScreen(), HistoryScreen(), ControlScreen()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.two_wheeler_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Sel'),
          NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.toggle_on_rounded), label: 'Kontrol'),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (app.linkState) {
      LinkState.connected => ('Terhubung', AppColors.good),
      LinkState.demo => ('Demo', AppColors.info),
      LinkState.connecting => ('Menyambung…', AppColors.caution),
      LinkState.reconnecting => ('Menyambung ulang…', AppColors.caution),
      LinkState.error => ('Gagal', AppColors.bad),
      LinkState.idle => ('Terputus', AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(app.linkState == LinkState.demo ? Icons.science_rounded : Icons.bluetooth_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final msg = app.linkMessage;
    final show = msg != null || app.linkState == LinkState.connecting || app.linkState == LinkState.reconnecting;
    if (!show) return const SizedBox.shrink();
    final isError = app.linkState == LinkState.error;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? AppColors.bad : AppColors.caution).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (!isError)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.caution))
          else
            const Icon(Icons.error_outline_rounded, color: AppColors.bad, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg ?? 'Menyambung ke ${app.settings.lastDeviceName ?? 'BMS'}… Pastikan aplikasi JK BMS ditutup.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(onPressed: () => app.disconnect(), child: const Text('Batal')),
        ],
      ),
    );
  }
}

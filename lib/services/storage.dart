import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bms_models.dart';

enum ProtocolChoice { auto, jk02_24s, jk02_32s }

class AppSettings {
  AppSettings({
    this.motorName = 'Motor Saya',
    this.fullRangeKm = 80,
    this.onThresholdA = 0.3,
    this.rideThresholdA = 3.0,
    this.protocol = ProtocolChoice.auto,
    this.motorColor = 0,
    this.lastDeviceId,
    this.lastDeviceName,
    this.controlsUnlocked = false,
  });

  String motorName;
  double fullRangeKm;
  double onThresholdA;
  double rideThresholdA;
  ProtocolChoice protocol;
  int motorColor;
  String? lastDeviceId;
  String? lastDeviceName;
  bool controlsUnlocked;

  Map<String, dynamic> toJson() => {
        'motorName': motorName,
        'fullRangeKm': fullRangeKm,
        'onThresholdA': onThresholdA,
        'rideThresholdA': rideThresholdA,
        'protocol': protocol.index,
        'motorColor': motorColor,
        'lastDeviceId': lastDeviceId,
        'lastDeviceName': lastDeviceName,
        'controlsUnlocked': controlsUnlocked,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        motorName: j['motorName'] as String? ?? 'Motor Saya',
        fullRangeKm: (j['fullRangeKm'] as num?)?.toDouble() ?? 80,
        onThresholdA: (j['onThresholdA'] as num?)?.toDouble() ?? 0.3,
        rideThresholdA: (j['rideThresholdA'] as num?)?.toDouble() ?? 3.0,
        protocol: ProtocolChoice.values[(j['protocol'] as int? ?? 0).clamp(0, 2)],
        motorColor: j['motorColor'] as int? ?? 0,
        lastDeviceId: j['lastDeviceId'] as String?,
        lastDeviceName: j['lastDeviceName'] as String?,
        controlsUnlocked: j['controlsUnlocked'] as bool? ?? false,
      );
}

class HistoryPoint {
  const HistoryPoint(this.t, this.soc, this.voltage, this.current, this.temp);
  final DateTime t;
  final int soc;
  final double voltage;
  final double current;
  final double temp;

  String encode() =>
      '${t.millisecondsSinceEpoch ~/ 1000},$soc,${voltage.toStringAsFixed(2)},${current.toStringAsFixed(2)},${temp.toStringAsFixed(1)}';

  static HistoryPoint? decode(String s) {
    final p = s.split(',');
    if (p.length != 5) return null;
    final ts = int.tryParse(p[0]);
    if (ts == null) return null;
    return HistoryPoint(
      DateTime.fromMillisecondsSinceEpoch(ts * 1000),
      int.tryParse(p[1]) ?? 0,
      double.tryParse(p[2]) ?? 0,
      double.tryParse(p[3]) ?? 0,
      double.tryParse(p[4]) ?? 0,
    );
  }
}

/// Energi harian (Wh) yang keluar (dipakai) dan masuk (dicas).
class DailyEnergy {
  DailyEnergy(this.day, this.outWh, this.inWh);
  final String day; // yyyy-mm-dd
  double outWh;
  double inWh;
}

class Storage {
  static const _kSettings = 'settings_v1';
  static const _kHistory = 'history_v1';
  static const _kEnergy = 'energy_v1';
  static const sampleEvery = Duration(seconds: 60);
  static const keepHistory = Duration(days: 3);
  static const keepEnergyDays = 30;

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null; // tetap jalan tanpa penyimpanan
    }
  }

  AppSettings loadSettings() {
    final raw = _prefs?.getString(_kSettings);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs?.setString(_kSettings, jsonEncode(s.toJson()));
  }

  List<HistoryPoint> loadHistory() {
    final list = _prefs?.getStringList(_kHistory) ?? const [];
    return list.map(HistoryPoint.decode).whereType<HistoryPoint>().toList();
  }

  Future<void> saveHistory(List<HistoryPoint> pts) async {
    await _prefs?.setStringList(_kHistory, pts.map((e) => e.encode()).toList());
  }

  List<DailyEnergy> loadEnergy() {
    final raw = _prefs?.getString(_kEnergy);
    if (raw == null) return [];
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.entries
          .map((e) => DailyEnergy(e.key, (e.value[0] as num).toDouble(), (e.value[1] as num).toDouble()))
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEnergy(List<DailyEnergy> days) async {
    final m = {for (final d in days) d.day: [d.outWh, d.inWh]};
    await _prefs?.setString(_kEnergy, jsonEncode(m));
  }

  Future<void> clearHistory() async {
    await _prefs?.remove(_kHistory);
    await _prefs?.remove(_kEnergy);
  }
}

JkProtocol? protocolFromChoice(ProtocolChoice c) => switch (c) {
      ProtocolChoice.auto => null,
      ProtocolChoice.jk02_24s => JkProtocol.jk02_24s,
      ProtocolChoice.jk02_32s => JkProtocol.jk02_32s,
    };

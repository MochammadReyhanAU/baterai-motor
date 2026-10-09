import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../logic/insights.dart';
import '../models/bms_models.dart';
import '../protocol/jk_protocol.dart';
import '../services/ble_link.dart';
import '../services/bms_link.dart';
import '../services/storage.dart';

class AppState extends ChangeNotifier {
  AppState(this.storage);

  final Storage storage;
  late AppSettings settings;

  FlutterReactiveBle? _ble;
  FlutterReactiveBle get ble => _ble ??= FlutterReactiveBle();

  BmsLink? _link;
  LinkState linkState = LinkState.idle;
  String? linkMessage;
  DeviceInfo? deviceInfo;
  BmsSwitches? switches;
  BmsReading? reading;
  DateTime? lastUpdate;
  MotorState motorState = MotorState.offline;
  final _detector = MotorStateDetector();
  double? _smoothedCurrent;

  List<HistoryPoint> history = [];
  List<DailyEnergy> energy = [];
  DateTime? _lastSample;
  DateTime? _lastEnergyTick;
  Timer? _staleTimer;

  bool get isDemo => _link is DemoLink;
  bool get isConnected => linkState == LinkState.connected || linkState == LinkState.demo;
  bool get hasData => reading != null && isConnected;
  DemoScenario? get demoScenario => _link is DemoLink ? (_link as DemoLink).scenario : null;
  bool get canControl => _link?.canControl ?? false;

  Future<void> init() async {
    await storage.init();
    settings = storage.loadSettings();
    history = storage.loadHistory();
    energy = storage.loadEnergy();
    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStale());
  }

  /// Dipanggil saat aplikasi dibuka: sambungkan ulang ke BMS terakhir.
  void autoConnect() {
    final id = settings.lastDeviceId;
    if (id != null && !kIsWeb) connectTo(id, settings.lastDeviceName ?? 'BMS');
  }

  // ---------- Koneksi ----------

  BleScanner scanner() => BleScanner(ble);

  Future<void> connectTo(String id, String name) async {
    await _closeLink();
    settings
      ..lastDeviceId = id
      ..lastDeviceName = name;
    await storage.saveSettings(settings);
    final link = BleLink(ble, id, protocolOverride: protocolFromChoice(settings.protocol));
    _attach(link);
    link.start();
  }

  Future<void> startDemo([DemoScenario s = DemoScenario.parked]) async {
    await _closeLink();
    _attach(DemoLink(scenario: s));
  }

  void setDemoScenario(DemoScenario s) {
    final l = _link;
    if (l is DemoLink) {
      l.scenario = s;
      _detector.reset();
      notifyListeners();
    }
  }

  Future<void> disconnect({bool forget = false}) async {
    await _closeLink();
    if (forget) {
      settings
        ..lastDeviceId = null
        ..lastDeviceName = null;
      await storage.saveSettings(settings);
    }
    notifyListeners();
  }

  void _attach(BmsLink link) {
    _link = link;
    deviceInfo = null;
    switches = null;
    reading = null;
    _smoothedCurrent = null;
    _detector.reset();
    link.onState = (s, msg) {
      linkState = s;
      linkMessage = msg;
      if (s != LinkState.connected && s != LinkState.demo) motorState = MotorState.offline;
      notifyListeners();
    };
    link.onDeviceInfo = (info) {
      deviceInfo = info;
      notifyListeners();
    };
    link.onReading = _onReading;
    link.onSwitches = (sw) {
      switches = sw;
      notifyListeners();
    };
    notifyListeners();
  }

  Future<void> _closeLink() async {
    final l = _link;
    _link = null;
    if (l != null) {
      l.onState = null;
      l.onReading = null;
      await l.close();
    }
    linkState = LinkState.idle;
    linkMessage = null;
    reading = null;
    motorState = MotorState.offline;
  }

  void _checkStale() {
    if (linkState == LinkState.connected && lastUpdate != null && DateTime.now().difference(lastUpdate!).inSeconds > 20) {
      linkMessage = 'Data tidak diperbarui. Tutup aplikasi JK BMS bila sedang terbuka.';
      notifyListeners();
    }
  }

  void _onReading(BmsReading r) {
    reading = r;
    lastUpdate = r.time;
    if (linkMessage != null && linkState == LinkState.connected) linkMessage = null;
    _smoothedCurrent = _smoothedCurrent == null ? r.current : _smoothedCurrent! * 0.8 + r.current * 0.2;
    motorState = _detector.update(r, onThresholdA: settings.onThresholdA, rideThresholdA: settings.rideThresholdA);
    if (!isDemo) _record(r);
    notifyListeners();
  }

  // ---------- Perkiraan ----------

  double get estimatedRangeKm {
    final r = reading;
    if (r == null) return 0;
    return settings.fullRangeKm * r.soc / 100.0;
  }

  /// Jam tersisa saat jalan, atau jam sampai penuh saat dicas.
  double? get hoursEstimate {
    final r = reading;
    final i = _smoothedCurrent;
    if (r == null || i == null) return null;
    if (motorState == MotorState.charging && i > 0.3) {
      return (r.nominalAh - r.remainingAh).clamp(0, double.infinity) / i;
    }
    if ((motorState == MotorState.riding || motorState == MotorState.standby) && i < -0.3) {
      return r.remainingAh / -i;
    }
    return null;
  }

  // ---------- Riwayat ----------

  void _record(BmsReading r) {
    final now = r.time;
    // Energi harian (integrasi daya).
    if (_lastEnergyTick != null) {
      final dtH = now.difference(_lastEnergyTick!).inMilliseconds / 3600000.0;
      if (dtH > 0 && dtH < 0.05) {
        final day = _dayKey(now);
        var e = energy.isNotEmpty && energy.last.day == day ? energy.last : null;
        if (e == null) {
          e = DailyEnergy(day, 0, 0);
          energy.add(e);
          if (energy.length > Storage.keepEnergyDays) energy.removeAt(0);
        }
        final p = r.power;
        if (p < 0) {
          e.outWh += -p * dtH;
        } else {
          e.inWh += p * dtH;
        }
      }
    }
    _lastEnergyTick = now;

    if (_lastSample == null || now.difference(_lastSample!) >= Storage.sampleEvery) {
      _lastSample = now;
      history.add(HistoryPoint(now, r.soc, r.totalVoltage, r.current, r.maxTemp));
      final cutoff = now.subtract(Storage.keepHistory);
      history.removeWhere((p) => p.t.isBefore(cutoff));
      storage.saveHistory(history);
      storage.saveEnergy(energy);
    }
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DailyEnergy? get today {
    final k = _dayKey(DateTime.now());
    for (final e in energy) {
      if (e.day == k) return e;
    }
    return null;
  }

  Future<void> clearHistory() async {
    history = [];
    energy = [];
    await storage.clearHistory();
    notifyListeners();
  }

  // ---------- Kontrol ----------

  Future<void> setSwitch(int register, bool on) async {
    final l = _link;
    if (l == null) throw StateError('Belum terhubung');
    await l.setSwitch(register, on);
    final sw = switches;
    if (sw != null) {
      switches = sw.copyWith(
        charge: register == regCharge ? on : null,
        discharge: register == regDischarge ? on : null,
        balancer: register == regBalance ? on : null,
      );
    }
    notifyListeners();
  }

  bool get isDrawingPower => (reading?.current ?? 0) < -1.0;

  // ---------- Pengaturan ----------

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    change(settings);
    final l = _link;
    if (l is BleLink) l.protocolOverride = protocolFromChoice(settings.protocol);
    await storage.saveSettings(settings);
    notifyListeners();
  }

  JkProtocol? get activeProtocol {
    final l = _link;
    if (l is BleLink) return l.protocol;
    return reading?.protocol;
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _link?.close();
    super.dispose();
  }
}

// Untuk dipakai oleh layar Kontrol.
const regCharge = JkCommand.regCharge;
const regDischarge = JkCommand.regDischarge;
const regBalance = JkCommand.regBalance;

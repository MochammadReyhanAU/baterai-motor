import 'dart:async';
import 'dart:math';

import '../models/bms_models.dart';

enum LinkState { idle, connecting, connected, reconnecting, demo, error }

/// Sumber data BMS: Bluetooth sungguhan atau simulasi (mode demo).
abstract class BmsLink {
  void Function(BmsReading reading)? onReading;
  void Function(DeviceInfo info)? onDeviceInfo;
  void Function(BmsSwitches switches)? onSwitches;
  void Function(LinkState state, String? message)? onState;

  bool get canControl;
  Future<void> setSwitch(int register, bool on);
  Future<void> close();
}

enum DemoScenario { parked, riding, charging }

/// Simulasi berdasarkan data dari screenshot aplikasi JK milik pengguna
/// (24S LFP, 79.1 V, 27 Ah, 42%).
class DemoLink extends BmsLink {
  DemoLink({this.scenario = DemoScenario.parked}) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    Future.microtask(() {
      onState?.call(LinkState.demo, null);
      onDeviceInfo?.call(const DeviceInfo(
        model: 'JK-B2A24S (demo)',
        hardwareVersion: '11.XW',
        softwareVersion: '11.26',
        uptimeSeconds: 0,
        powerOnCount: 12,
        deviceName: 'Demo BMS',
        manufacturingDate: '',
        serialNumber: 'DEMO',
      ));
      _emitSwitches();
      _tick();
    });
  }

  bool _balancer = true;

  void _emitSwitches() => onSwitches?.call(
      BmsSwitches(charge: _charge, discharge: _discharge, balancer: _balancer, cellCount: 24));

  DemoScenario scenario;
  late final Timer _timer;
  final _rnd = Random(7);
  double _remainAh = 11.3;
  bool _charge = true;
  bool _discharge = true;
  int _t = 0;

  @override
  bool get canControl => true;

  void _tick() {
    _t++;
    double current;
    switch (scenario) {
      case DemoScenario.parked:
        current = 0;
      case DemoScenario.riding:
        current = _discharge ? -(18 + 10 * sin(_t / 4) + _rnd.nextDouble() * 4) : 0;
      case DemoScenario.charging:
        current = _charge ? 6.0 + _rnd.nextDouble() * 0.2 : 0;
    }
    // Dipercepat 5x supaya perubahan terlihat.
    _remainAh = (_remainAh + current / 3600 * 5).clamp(0.3, 27.0);
    final soc = (_remainAh / 27.0 * 100).round();
    final sag = current * 0.0012; // tegangan turun saat dipakai, naik saat dicas
    final base = 3.296 + sag;
    final cells = List<double>.generate(24, (i) {
      final jitter = scenario == DemoScenario.parked ? 0.0 : (_rnd.nextInt(5) - 2) / 1000.0;
      return double.parse((base + jitter + (i == 22 ? 0.001 : 0)).toStringAsFixed(3));
    });
    final total = cells.reduce((a, b) => a + b) - 0.002;
    final warm = scenario == DemoScenario.riding ? min(_t * 0.05, 8.0) : 0.0;
    onReading?.call(BmsReading(
      time: DateTime.now(),
      protocol: JkProtocol.jk02_32s,
      cellVoltages: cells,
      cellResistances: List<double>.generate(24, (i) => 0.141 + (i % 5) * 0.002),
      totalVoltage: total,
      current: current,
      temp1: 28.3 + warm,
      temp2: 28.2 + warm * 0.9,
      mosTemp: 29.7 + warm * 1.3,
      errorsBitmask: 1 << 19,
      balanceCurrent: 0,
      balancing: false,
      soc: soc,
      remainingAh: _remainAh,
      nominalAh: 27.0,
      cycleCount: 28,
      cycleCapacityAh: 780.3,
      soh: 100,
      runtimeSeconds: 33331945 + _t,
      chargeEnabled: _charge,
      dischargeEnabled: _discharge,
      heating: false,
      batteryTypeCode: 0,
      detailLogCount: 725,
      emergencySeconds: 0,
    ));
  }

  @override
  Future<void> setSwitch(int register, bool on) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (register == 0x1D) _charge = on;
    if (register == 0x1E) _discharge = on;
    if (register == 0x1F) _balancer = on;
    _emitSwitches();
    _tick();
  }

  @override
  Future<void> close() async => _timer.cancel();
}

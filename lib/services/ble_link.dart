import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../models/bms_models.dart';
import '../protocol/jk_protocol.dart';
import 'bms_link.dart';

class FoundDevice {
  FoundDevice(this.id, this.name, this.rssi, this.looksLikeJk);
  final String id;
  final String name;
  final int rssi;
  final bool looksLikeJk;
}

/// Pembungkus pemindaian Bluetooth.
class BleScanner {
  BleScanner(this.ble);
  final FlutterReactiveBle ble;
  static final _jkService = Uuid.parse(JkUuids.serviceShort).expanded;

  Stream<BleStatus> get status => ble.statusStream;

  Stream<FoundDevice> scan() => ble
      .scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency)
      .where((d) => d.name.isNotEmpty || d.serviceUuids.any((u) => u.expanded == _jkService))
      .map((d) {
        final n = d.name.toUpperCase();
        final jk = d.serviceUuids.any((u) => u.expanded == _jkService) || n.startsWith('JK') || n.contains('BMS');
        return FoundDevice(d.id, d.name.isEmpty ? 'Tanpa nama' : d.name, d.rssi, jk);
      });
}

/// Koneksi ke JK BMS lewat Bluetooth Low Energy.
class BleLink extends BmsLink {
  BleLink(this.ble, this.deviceId, {this.protocolOverride});

  final FlutterReactiveBle ble;
  final String deviceId;
  JkProtocol? protocolOverride;

  final _assembler = FrameAssembler();
  StreamSubscription<ConnectionStateUpdate>? _conn;
  StreamSubscription<List<int>>? _notify;
  Characteristic? _writeChar;
  bool _writeWithResponse = false;
  Timer? _watchdog;
  Timer? _reconnectTimer;
  DateTime _lastCellFrame = DateTime.fromMillisecondsSinceEpoch(0);
  JkProtocol? _fromDeviceInfo;
  JkProtocol? _guessed;
  bool _closed = false;
  bool _everConnected = false;

  static final _svc = Uuid.parse(JkUuids.serviceShort).expanded;
  static final _chr = Uuid.parse('ffe1').expanded;

  @override
  bool get canControl => _writeChar != null;

  // Urutan: pilihan manual > tebakan dari struktur frame (paling andal) >
  // versi software di device info > default 32S.
  JkProtocol get protocol => protocolOverride ?? _guessed ?? _fromDeviceInfo ?? JkProtocol.jk02_32s;

  void start() => _connect();

  void _connect() {
    if (_closed) return;
    onState?.call(_everConnected ? LinkState.reconnecting : LinkState.connecting, null);
    _conn?.cancel();
    _conn = ble
        .connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 15))
        .listen((u) {
      switch (u.connectionState) {
        case DeviceConnectionState.connected:
          _setup();
        case DeviceConnectionState.disconnected:
          _teardown();
          if (!_closed) {
            onState?.call(LinkState.reconnecting,
                u.failure?.message.isNotEmpty == true ? u.failure!.message : 'Koneksi terputus');
            _scheduleReconnect();
          }
        default:
          break;
      }
    }, onError: (Object e) {
      _teardown();
      onState?.call(LinkState.reconnecting, 'Gagal terhubung: $e');
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), _connect);
  }

  Future<void> _setup() async {
    try {
      await ble.discoverAllServices(deviceId);
      final services = await ble.getDiscoveredServices(deviceId);
      final svc = services.where((s) => s.id.expanded == _svc).toList();
      if (svc.isEmpty) {
        onState?.call(LinkState.error, 'Perangkat ini bukan JK BMS (service FFE0 tidak ada)');
        return;
      }
      final chars = svc.expand((s) => s.characteristics).where((c) => c.id.expanded == _chr).toList();
      // Modul BLE baru punya dua karakteristik FFE1: satu untuk tulis, satu notify.
      final notifyChar = chars.firstWhere((c) => c.isNotifiable || c.isIndicatable, orElse: () => chars.first);
      final writeChar = chars.firstWhere(
          (c) => c.isWritableWithoutResponse || c.isWritableWithResponse,
          orElse: () => chars.first);
      _writeChar = writeChar;
      _writeWithResponse = !writeChar.isWritableWithoutResponse;

      _assembler.reset();
      await _notify?.cancel();
      _notify = notifyChar.subscribe().listen(_onData, onError: (Object e) {
        debugPrint('notify error $e');
      });

      _everConnected = true;
      onState?.call(LinkState.connected, null);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _write(JkCommand.requestDeviceInfo());
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _write(JkCommand.requestCellInfo());

      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 3), (_) {
        if (DateTime.now().difference(_lastCellFrame).inSeconds > 6) {
          _write(JkCommand.requestCellInfo());
        }
      });
    } catch (e) {
      onState?.call(LinkState.error, 'Gagal membaca BMS: $e');
    }
  }

  Future<void> _write(Uint8List data) async {
    final c = _writeChar;
    if (c == null) return;
    try {
      await c.write(data, withResponse: _writeWithResponse);
    } catch (e) {
      debugPrint('write error $e');
    }
  }

  void _onData(List<int> chunk) {
    for (final frame in _assembler.add(chunk)) {
      try {
        switch (JkParser.frameType(frame)) {
          case 0x03:
            final info = JkParser.parseDeviceInfo(frame);
            _fromDeviceInfo = info.suggestedProtocol;
            onDeviceInfo?.call(info);
          case 0x02:
            _lastCellFrame = DateTime.now();
            _guessed ??= JkParser.guessProtocol(frame);
            onReading?.call(JkParser.parseCellInfo(frame, protocol));
          case 0x01:
            onSwitches?.call(JkParser.parseSettings(frame));
          default:
            break;
        }
      } catch (e) {
        debugPrint('parse error $e');
      }
    }
  }

  @override
  Future<void> setSwitch(int register, bool on) async {
    if (_writeChar == null) throw StateError('Belum terhubung ke BMS');
    await _write(JkCommand.setSwitch(register, on));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _write(JkCommand.requestCellInfo());
  }

  void _teardown() {
    _watchdog?.cancel();
    _notify?.cancel();
    _notify = null;
    _writeChar = null;
    _assembler.reset();
  }

  @override
  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _teardown();
    await _conn?.cancel();
    onState?.call(LinkState.idle, null);
  }
}

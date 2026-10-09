// Protokol Bluetooth JK BMS (keluarga JK02).
//
// Dipetakan berdasarkan proyek open-source esphome-jk-bms (syssi), file
// components/jk_bms_ble/jk_bms_ble.cpp. Semua angka little-endian.
//
// - Service 0xFFE0, characteristic 0xFFE1 (notify + write).
// - Perintah ke BMS: 20 byte, diawali AA 55 90 EB, byte terakhir = jumlah
//   byte 0..18 (mod 256).
// - Balasan dari BMS: >= 300 byte, diawali 55 AA EB 90, byte ke-299 = CRC
//   (jumlah byte 0..298 mod 256). Byte ke-4 = jenis frame:
//   0x01 settings, 0x02 cell info, 0x03 device info.

import 'dart:typed_data';

import '../models/bms_models.dart';

class JkUuids {
  static const service = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const characteristic = '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const serviceShort = 'ffe0';
}

class JkCommand {
  static const int cellInfo = 0x96;
  static const int deviceInfo = 0x97;

  // Register switch (sama untuk JK02_24S dan JK02_32S).
  static const int regCharge = 0x1D;
  static const int regDischarge = 0x1E;
  static const int regBalance = 0x1F;

  static Uint8List build(int address, {int value = 0, int length = 0}) {
    final f = Uint8List(20);
    f[0] = 0xAA;
    f[1] = 0x55;
    f[2] = 0x90;
    f[3] = 0xEB;
    f[4] = address & 0xFF;
    f[5] = length & 0xFF;
    f[6] = value & 0xFF;
    f[7] = (value >> 8) & 0xFF;
    f[8] = (value >> 16) & 0xFF;
    f[9] = (value >> 24) & 0xFF;
    f[19] = sum8(f, 19);
    return f;
  }

  static Uint8List requestCellInfo() => build(cellInfo);
  static Uint8List requestDeviceInfo() => build(deviceInfo);

  /// Perintah ON/OFF untuk switch charge / discharge / balance.
  static Uint8List setSwitch(int register, bool on) =>
      build(register, value: on ? 1 : 0, length: 4);
}

int sum8(List<int> data, int length) {
  var s = 0;
  for (var i = 0; i < length; i++) {
    s = (s + data[i]) & 0xFF;
  }
  return s;
}

/// Menyusun potongan notifikasi BLE menjadi frame utuh yang lolos CRC.
class FrameAssembler {
  static const int frameSize = 300;
  static const int maxBuffer = 1024;
  static const List<int> header = [0x55, 0xAA, 0xEB, 0x90];

  final List<int> _buf = [];

  void reset() => _buf.clear();

  List<Uint8List> add(List<int> chunk) {
    final out = <Uint8List>[];
    _buf.addAll(chunk);
    if (_buf.length > maxBuffer) {
      _buf.removeRange(0, _buf.length - frameSize);
    }
    while (true) {
      final start = _findHeader();
      if (start < 0) {
        // Simpan 3 byte terakhir kalau-kalau header terpotong.
        if (_buf.length > 3) _buf.removeRange(0, _buf.length - 3);
        break;
      }
      if (start > 0) _buf.removeRange(0, start);
      if (_buf.length < frameSize) break;
      final crc = sum8(_buf, frameSize - 1);
      if (crc == _buf[frameSize - 1]) {
        out.add(Uint8List.fromList(_buf.sublist(0, frameSize)));
        _buf.removeRange(0, frameSize);
      } else {
        // Header palsu / data rusak: buang 1 byte lalu cari header berikutnya.
        _buf.removeAt(0);
      }
    }
    return out;
  }

  int _findHeader() {
    for (var i = 0; i + 3 < _buf.length; i++) {
      if (_buf[i] == header[0] &&
          _buf[i + 1] == header[1] &&
          _buf[i + 2] == header[2] &&
          _buf[i + 3] == header[3]) {
        return i;
      }
    }
    return -1;
  }
}

class _Reader {
  _Reader(this.d);
  final Uint8List d;

  int u8(int i) => d[i];
  int u16(int i) => d[i] | (d[i + 1] << 8);
  int s16(int i) {
    final v = u16(i);
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  int u32(int i) => d[i] + d[i + 1] * 0x100 + d[i + 2] * 0x10000 + d[i + 3] * 0x1000000;
  int s32(int i) {
    final v = u32(i);
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  String str(int i, int len) {
    final bytes = <int>[];
    for (var k = i; k < i + len && k < d.length; k++) {
      if (d[k] == 0) break;
      bytes.add(d[k]);
    }
    return String.fromCharCodes(bytes).trim();
  }
}

class JkParser {
  static int frameType(Uint8List frame) => frame[4];

  static DeviceInfo parseDeviceInfo(Uint8List frame) {
    final r = _Reader(frame);
    final mfg = r.str(78, 6);
    return DeviceInfo(
      model: r.str(6, 16),
      hardwareVersion: r.str(22, 8),
      softwareVersion: r.str(30, 8),
      uptimeSeconds: r.u32(38),
      powerOnCount: r.u32(42),
      deviceName: r.str(46, 16),
      manufacturingDate: mfg.isEmpty ? '' : '20$mfg',
      serialNumber: r.str(86, 11),
    );
  }

  static BmsSwitches parseSettings(Uint8List frame) {
    final r = _Reader(frame);
    return BmsSwitches(
      cellCount: r.u8(114),
      charge: r.u8(118) != 0,
      discharge: r.u8(122) != 0,
      balancer: r.u8(126) != 0,
    );
  }

  /// Tebak versi protokol dari isi frame cell info (dipakai bila device info
  /// belum diterima). Pada JK02_24S, byte 54..57 adalah bitmask sel aktif yang
  /// berurutan dari bit 0. Pada JK02_32S, byte 54..69 adalah tegangan sel
  /// 25..32 (nol untuk pack <= 24 sel) dan bitmask pindah ke byte 70.
  static JkProtocol guessProtocol(Uint8List frame) {
    final r = _Reader(frame);
    final mask24 = r.u32(54);
    var nonZero24 = 0;
    for (var i = 0; i < 24; i++) {
      if (r.u16(6 + i * 2) > 0) nonZero24++;
    }
    if (mask24 != 0 && nonZero24 > 0 && nonZero24 <= 24) {
      final expected = (1 << nonZero24) - 1;
      if (mask24 == expected) return JkProtocol.jk02_24s;
    }
    return JkProtocol.jk02_32s;
  }

  static BmsReading parseCellInfo(Uint8List frame, JkProtocol protocol) {
    final r = _Reader(frame);
    final is32 = protocol == JkProtocol.jk02_32s;
    var offset = is32 ? 16 : 0;
    final slots = 24 + offset ~/ 2;

    final volts = <double>[];
    final res = <double>[];
    for (var i = 0; i < slots; i++) {
      final v = r.u16(6 + i * 2) / 1000.0;
      if (v <= 0) continue;
      volts.add(v);
      res.add(r.u16(64 + offset + i * 2) / 1000.0);
    }

    offset *= 2;
    double? mosTemp;
    if (is32) {
      mosTemp = r.s16(112 + offset) / 10.0;
    }

    final totalVoltage = r.u32(118 + offset) / 1000.0;
    final current = r.s32(126 + offset) / 1000.0;
    final t1 = r.s16(130 + offset) / 10.0;
    final t2 = r.s16(132 + offset) / 10.0;
    int errors;
    if (is32) {
      errors = r.u32(134 + offset);
    } else {
      mosTemp = r.s16(134 + offset) / 10.0;
      errors = r.u16(136 + offset);
    }

    int? batteryType;
    int? detailLogs;
    int? emergency;
    if (is32) {
      batteryType = r.u8(243 + offset);
      detailLogs = r.u32(234 + offset);
      emergency = r.u16(186 + offset);
    }

    return BmsReading(
      time: DateTime.now(),
      protocol: protocol,
      cellVoltages: volts,
      cellResistances: res,
      totalVoltage: totalVoltage,
      current: current,
      temp1: t1,
      temp2: t2,
      mosTemp: mosTemp ?? 0,
      errorsBitmask: errors,
      balanceCurrent: r.s16(138 + offset) / 1000.0,
      balancing: r.u8(140 + offset) != 0,
      soc: r.u8(141 + offset),
      remainingAh: r.u32(142 + offset) / 1000.0,
      nominalAh: r.u32(146 + offset) / 1000.0,
      cycleCount: r.u32(150 + offset),
      cycleCapacityAh: r.u32(154 + offset) / 1000.0,
      soh: r.u8(158 + offset),
      runtimeSeconds: r.u32(162 + offset),
      chargeEnabled: r.u8(166 + offset) != 0,
      dischargeEnabled: r.u8(167 + offset) != 0,
      heating: r.u8(183 + offset) != 0,
      batteryTypeCode: batteryType,
      detailLogCount: detailLogs,
      emergencySeconds: emergency,
    );
  }
}

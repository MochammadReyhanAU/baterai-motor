import 'dart:typed_data';

import 'package:baterai_motor/models/bms_models.dart';
import 'package:baterai_motor/protocol/jk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Uint8List u(List<int> l) => Uint8List.fromList(l);

/// Kirim frame dalam potongan kecil seperti notifikasi BLE.
List<Uint8List> feed(FrameAssembler a, List<int> frame, int chunk) {
  final out = <Uint8List>[];
  for (var i = 0; i < frame.length; i += chunk) {
    out.addAll(a.add(frame.sublist(i, i + chunk > frame.length ? frame.length : i + chunk)));
  }
  return out;
}

void main() {
  group('Perintah', () {
    test('request cell info sama dengan frame esphome', () {
      final f = JkCommand.requestCellInfo();
      expect(f.sublist(0, 6), [0xAA, 0x55, 0x90, 0xEB, 0x96, 0x00]);
      expect(f[19], sum8(f, 19));
      expect(f[19], 0x10); // 0xAA+0x55+0x90+0xEB+0x96 = 0x310
    });
    test('CRC protocol-select (dari test esphome)', () {
      expect(JkCommand.build(0xA5, value: 0, length: 2)[19], 0x21);
      expect(JkCommand.build(0xA6, value: 2, length: 2)[19], 0x24);
    });
    test('switch discharge OFF', () {
      final f = JkCommand.setSwitch(JkCommand.regDischarge, false);
      expect(f[4], 0x1E);
      expect(f[5], 0x04);
      expect(f.sublist(6, 10), [0, 0, 0, 0]);
    });
  });

  group('Assembler', () {
    test('menyusun frame dari potongan 20 / 185 byte + sampah', () {
      final a = FrameAssembler();
      expect(a.add([1, 2, 3, 0x55]), isEmpty);
      expect(feed(a, CELL_INFO_JK02_32S_V11, 20).length, 1);
      expect(feed(a, CELL_INFO_JK02_32S_V15, 185).length, 1);
    });
    test('frame rusak ditolak', () {
      final bad = List<int>.from(CELL_INFO_JK02_32S_V11);
      bad[100] ^= 0xFF;
      expect(FrameAssembler().add(bad), isEmpty);
    });
  });

  group('Deteksi protokol', () {
    test('dari frame cell info', () {
      expect(JkParser.guessProtocol(u(CELL_INFO_JK02_24S_V10)), JkProtocol.jk02_24s);
      expect(JkParser.guessProtocol(u(CELL_INFO_JK02_24S_V10_NEG_TEMPS)), JkProtocol.jk02_24s);
      expect(JkParser.guessProtocol(u(CELL_INFO_JK02_32S_V11)), JkProtocol.jk02_32s);
      expect(JkParser.guessProtocol(u(CELL_INFO_JK02_32S_V15)), JkProtocol.jk02_32s);
      expect(JkParser.guessProtocol(u(CELL_INFO_JK02_32S_V19)), JkProtocol.jk02_32s);
    });
    test('dari device info', () {
      final d24 = JkParser.parseDeviceInfo(u(DEVICE_INFO_JK02_24S_V10));
      expect(d24.model, 'JK-B2A24S20P');
      expect(d24.softwareVersion, '10.07');
      expect(d24.suggestedProtocol, JkProtocol.jk02_24s);
      final d32 = JkParser.parseDeviceInfo(u(DEVICE_INFO_JK02_32S_V19));
      expect(d32.hardwareVersion, '19A');
      expect(d32.suggestedProtocol, JkProtocol.jk02_32s);
    });
  });

  group('Parsing cell info', () {
    test('JK02_24S v10 (24 sel, mirip pack 72V)', () {
      final r = JkParser.parseCellInfo(u(CELL_INFO_JK02_24S_V10), JkProtocol.jk02_24s);
      expect(r.cellCount, 24);
      expect(r.totalVoltage, closeTo(78.735, 0.001));
      expect(r.current, closeTo(0, 0.001));
      expect(r.minCell, closeTo(3.279, 0.0005));
      expect(r.minCellIndex, 2); // sel #3
      expect(r.maxCell, closeTo(3.285, 0.0005));
      expect(r.maxCellIndex, 22); // sel #23
      expect(r.temp1, closeTo(20.7, 0.01));
      expect(r.mosTemp, closeTo(23.4, 0.01));
      expect(r.soc, 85);
      expect(r.soh, 100);
      expect(r.remainingAh, closeTo(42.804, 0.001));
      expect(r.nominalAh, closeTo(50.0, 0.001));
      expect(r.runtimeSeconds, 269340);
      expect(r.chargeEnabled, isTrue);
      expect(r.dischargeEnabled, isFalse);
    });
    test('JK02_24S suhu negatif', () {
      final r = JkParser.parseCellInfo(u(CELL_INFO_JK02_24S_V10_NEG_TEMPS), JkProtocol.jk02_24s);
      expect(r.cellCount, 13);
      expect(r.temp1, closeTo(-3.1, 0.01));
      expect(r.temp2, closeTo(-2.9, 0.01));
      expect(r.mosTemp, closeTo(0.5, 0.01));
      expect(r.cycleCount, 56);
      expect(r.chargeEnabled, isFalse);
    });
    test('JK02_32S v11', () {
      final r = JkParser.parseCellInfo(u(CELL_INFO_JK02_32S_V11), JkProtocol.jk02_32s);
      expect(r.cellCount, 16);
      expect(r.totalVoltage, closeTo(51.689, 0.001));
      expect(r.minCellIndex, 10);
      expect(r.deltaCell, closeTo(0.030, 0.0005));
      expect(r.mosTemp, closeTo(17.3, 0.01));
      expect(r.soc, 52);
      expect(r.remainingAh, closeTo(1.043, 0.001));
      expect(r.runtimeSeconds, 107416);
      expect(r.chargeEnabled && r.dischargeEnabled, isTrue);
      expect(r.batteryTypeLabel, 'LFP');
    });
    test('JK02_32S v15 sedang dicas 31.881 A', () {
      final r = JkParser.parseCellInfo(u(CELL_INFO_JK02_32S_V15), JkProtocol.jk02_32s);
      expect(r.current, closeTo(31.881, 0.001));
      expect(r.totalVoltage, closeTo(53.224, 0.001));
      expect(r.soc, 25);
      expect(r.nominalAh, closeTo(200, 0.001));
      expect(r.cycleCount, 9);
      expect(r.runtimeSeconds, 24530060);
    });
    test('JK02_32S v19 arus negatif (dipakai)', () {
      final r = JkParser.parseCellInfo(u(CELL_INFO_JK02_32S_V19), JkProtocol.jk02_32s);
      expect(r.current, closeTo(-0.727, 0.001));
      expect(r.soc, 100);
      expect(r.remainingAh, closeTo(312.898, 0.001));
      expect(r.temp2, closeTo(12.7, 0.01));
    });
  });

  test('Settings frame v19', () {
    final sw = JkParser.parseSettings(u(SETTINGS_JK02_32S_V19));
    expect(sw.cellCount, 16);
  });

  test('Alarm bitmask diterjemahkan', () {
    final a = BmsAlarm.fromBitmask((1 << 19) | (1 << 13));
    expect(a.first.level, AlarmLevel.danger);
    expect(a.map((e) => e.bit), containsAll([13, 19]));
  });
}

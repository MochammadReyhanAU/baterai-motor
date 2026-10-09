import 'package:flutter/material.dart';

import '../models/bms_models.dart';

enum Level { good, caution, bad, info }

extension LevelColor on Level {
  Color get color => switch (this) {
        Level.good => const Color(0xFF34D399),
        Level.caution => const Color(0xFFFBBF24),
        Level.bad => const Color(0xFFF87171),
        Level.info => const Color(0xFF60A5FA),
      };
}

enum MotorState { offline, parked, standby, riding, charging, powerCut }

class MotorStatus {
  const MotorStatus(this.state, this.title, this.subtitle, this.color, this.icon);
  final MotorState state;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  static MotorStatus of(MotorState s, BmsReading? r) {
    final amps = r == null ? 0.0 : r.current.abs();
    final watts = r == null ? 0.0 : r.power.abs();
    return switch (s) {
      MotorState.offline => const MotorStatus(MotorState.offline, 'Belum terhubung',
          'Dekatkan HP ke motor lalu sambungkan baterai', Color(0xFF94A3B8), Icons.bluetooth_disabled_rounded),
      MotorState.parked => const MotorStatus(MotorState.parked, 'Motor mati / parkir',
          'Tidak ada arus keluar-masuk baterai', Color(0xFF94A3B8), Icons.local_parking_rounded),
      MotorState.standby => MotorStatus(MotorState.standby, 'Motor menyala, diam',
          'Ada arus kecil ${amps.toStringAsFixed(1)} A (lampu/controller)', const Color(0xFF60A5FA), Icons.power_settings_new_rounded),
      MotorState.riding => MotorStatus(MotorState.riding, 'Sedang jalan',
          'Memakai ${watts.toStringAsFixed(0)} W dari baterai', const Color(0xFF34D399), Icons.two_wheeler_rounded),
      MotorState.charging => MotorStatus(MotorState.charging, 'Sedang dicas',
          'Masuk ${watts.toStringAsFixed(0)} W  •  ${amps.toStringAsFixed(1)} A', const Color(0xFFFBBF24), Icons.bolt_rounded),
      MotorState.powerCut => const MotorStatus(MotorState.powerCut, 'Daya motor diputus',
          'BMS mematikan aliran ke motor (discharge OFF)', Color(0xFFF87171), Icons.power_off_rounded),
    };
  }
}

/// Menebak kondisi motor dari arus baterai, dengan jeda supaya status tidak
/// "berkedip" saat lampu merah atau saat rem regeneratif.
class MotorStateDetector {
  DateTime? _lastRide;
  DateTime? _chargeSince;

  MotorState update(BmsReading r, {required double onThresholdA, required double rideThresholdA}) {
    final now = r.time;
    final i = r.current;
    const chargeThresholdA = 0.5;

    if (i >= chargeThresholdA) {
      _chargeSince ??= now;
      final recentlyRiding = _lastRide != null && now.difference(_lastRide!).inSeconds < 10;
      if (recentlyRiding) return MotorState.riding; // rem regeneratif
      if (now.difference(_chargeSince!).inSeconds >= 3) return MotorState.charging;
    } else {
      _chargeSince = null;
    }

    final out = -i;
    if (out >= rideThresholdA) {
      _lastRide = now;
      return MotorState.riding;
    }
    if (_lastRide != null && now.difference(_lastRide!).inSeconds < 6 && out >= onThresholdA) {
      return MotorState.riding;
    }
    if (!r.dischargeEnabled) return MotorState.powerCut;
    if (out >= onThresholdA) return MotorState.standby;
    if (i >= chargeThresholdA) return MotorState.charging;
    return MotorState.parked;
  }

  void reset() {
    _lastRide = null;
    _chargeSince = null;
  }
}

class HealthItem {
  const HealthItem(this.icon, this.title, this.value, this.level, this.explain);
  final IconData icon;
  final String title;
  final String value;
  final Level level;
  final String explain;
}

class Insights {
  static Level socLevel(int soc) => soc >= 50
      ? Level.good
      : soc >= 20
          ? Level.caution
          : Level.bad;

  static Color socColor(int soc) {
    if (soc >= 50) return const Color(0xFF34D399);
    if (soc >= 20) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  static String socAdvice(int soc, MotorState s) {
    if (s == MotorState.charging) {
      if (soc >= 100) return 'Sudah penuh, charger boleh dicabut';
      return 'Biarkan sampai penuh untuk hasil terbaik';
    }
    if (soc >= 80) return 'Baterai penuh, siap jalan jauh';
    if (soc >= 50) return 'Masih cukup untuk perjalanan harian';
    if (soc >= 20) return 'Sebaiknya cas setelah perjalanan ini';
    return 'Baterai hampir habis, segera cas!';
  }

  static Level balanceLevel(double delta) => delta < 0.03
      ? Level.good
      : delta < 0.08
          ? Level.caution
          : Level.bad;

  static String balanceText(double delta) => switch (balanceLevel(delta)) {
        Level.good => 'Sangat seimbang',
        Level.caution => 'Agak tidak seimbang',
        _ => 'Tidak seimbang',
      };

  static List<HealthItem> health(BmsReading r) {
    final items = <HealthItem>[];

    final bl = balanceLevel(r.deltaCell);
    items.add(HealthItem(
      Icons.balance_rounded,
      'Keseimbangan sel',
      balanceText(r.deltaCell),
      bl,
      'Selisih sel tertinggi dan terendah ${(r.deltaCell * 1000).toStringAsFixed(0)} mV. '
          '${bl == Level.good ? 'Semua sel bekerja kompak.' : 'Cas sampai penuh agar balancer bekerja; jika tetap besar, periksakan.'}',
    ));

    final tMax = r.maxTemp;
    final tMin = r.minTemp;
    Level tl;
    String tv;
    String te;
    if (tMax >= 55) {
      tl = Level.bad;
      tv = 'Terlalu panas';
      te = 'Suhu tertinggi ${tMax.toStringAsFixed(0)}°C. Berhenti dan biarkan dingin.';
    } else if (tMax >= 45) {
      tl = Level.caution;
      tv = 'Hangat';
      te = 'Suhu tertinggi ${tMax.toStringAsFixed(0)}°C. Masih aman, tapi jangan dipaksa.';
    } else if (tMin < 0) {
      tl = Level.caution;
      tv = 'Dingin';
      te = 'Suhu ${tMin.toStringAsFixed(0)}°C. Baterai LFP tidak boleh dicas di bawah 0°C.';
    } else {
      tl = Level.good;
      tv = 'Normal ${tMax.toStringAsFixed(0)}°C';
      te = 'Sensor 1: ${r.temp1.toStringAsFixed(1)}°C, sensor 2: ${r.temp2.toStringAsFixed(1)}°C, BMS: ${r.mosTemp.toStringAsFixed(1)}°C.';
    }
    items.add(HealthItem(Icons.thermostat_rounded, 'Suhu', tv, tl, te));

    final both = r.chargeEnabled && r.dischargeEnabled;
    items.add(HealthItem(
      Icons.shield_rounded,
      'Jalur listrik',
      both
          ? 'Cas & pakai aktif'
          : !r.dischargeEnabled && !r.chargeEnabled
              ? 'Cas & pakai mati'
              : !r.dischargeEnabled
                  ? 'Pakai dimatikan'
                  : 'Cas dimatikan',
      both ? Level.good : Level.bad,
      both
          ? 'BMS mengizinkan baterai dicas dan dipakai.'
          : 'BMS memutus jalur ${!r.dischargeEnabled ? 'ke motor' : ''}${!r.dischargeEnabled && !r.chargeEnabled ? ' dan ' : ''}${!r.chargeEnabled ? 'pengisian' : ''}. Bisa karena perlindungan atau dimatikan manual (menu Kontrol).',
    ));

    final alarms = r.alarms.where((a) => a.level != AlarmLevel.info).toList();
    items.add(HealthItem(
      Icons.notifications_active_rounded,
      'Peringatan BMS',
      alarms.isEmpty ? 'Tidak ada' : '${alarms.length} peringatan',
      alarms.isEmpty
          ? Level.good
          : alarms.any((a) => a.level == AlarmLevel.danger)
              ? Level.bad
              : Level.caution,
      alarms.isEmpty ? 'BMS tidak melaporkan masalah.' : alarms.map((a) => '• ${a.title}').join('\n'),
    ));

    items.add(HealthItem(
      Icons.favorite_rounded,
      'Kesehatan baterai',
      '${r.soh}%  •  ${r.cycleCount}x cas penuh',
      r.soh >= 80 ? Level.good : Level.caution,
      'Perkiraan BMS. Baterai LFP umumnya tahan ribuan siklus; ${r.cycleCount} siklus masih sangat muda.',
    ));

    return items;
  }

  static Level overall(List<HealthItem> items) {
    if (items.any((i) => i.level == Level.bad)) return Level.bad;
    if (items.any((i) => i.level == Level.caution)) return Level.caution;
    return Level.good;
  }

  static String overallText(Level l) => switch (l) {
        Level.good => 'Baterai dalam kondisi baik',
        Level.caution => 'Ada yang perlu diperhatikan',
        Level.bad => 'Ada masalah, cek di bawah',
        Level.info => '',
      };

  static String formatDuration(double hours) {
    if (hours.isNaN || hours.isInfinite || hours <= 0) return '-';
    final mins = (hours * 60).round();
    if (mins < 60) return '$mins mnt';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h >= 48) return '${(h / 24).toStringAsFixed(0)} hari';
    return m == 0 ? '$h jam' : '$h j $m m';
  }

  static String formatRuntime(int seconds) {
    final d = seconds ~/ 86400;
    final y = d ~/ 365;
    final rd = d % 365;
    final h = (seconds % 86400) ~/ 3600;
    if (y > 0) return '$y thn $rd hari';
    if (d > 0) return '$d hari $h jam';
    return '$h jam ${(seconds % 3600) ~/ 60} mnt';
  }
}

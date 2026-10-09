enum JkProtocol { jk02_24s, jk02_32s }

extension JkProtocolLabel on JkProtocol {
  String get label => switch (this) {
        JkProtocol.jk02_24s => 'JK02 24S (firmware < v11)',
        JkProtocol.jk02_32s => 'JK02 32S (firmware v11+)',
      };
}

class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.hardwareVersion,
    required this.softwareVersion,
    required this.uptimeSeconds,
    required this.powerOnCount,
    required this.deviceName,
    required this.manufacturingDate,
    required this.serialNumber,
  });

  final String model;
  final String hardwareVersion;
  final String softwareVersion;
  final int uptimeSeconds;
  final int powerOnCount;
  final String deviceName;
  final String manufacturingDate;
  final String serialNumber;

  /// Firmware v11 ke atas memakai JK02_32S (lihat daftar perangkat di
  /// README esphome-jk-bms; contoh: hw 10.XW + sw 11.21 juga 32S, jadi yang
  /// dipakai adalah versi software).
  JkProtocol? get suggestedProtocol {
    final major = int.tryParse(softwareVersion.split('.').first.replaceAll(RegExp(r'[^0-9]'), ''));
    if (major == null) return null;
    return major >= 11 ? JkProtocol.jk02_32s : JkProtocol.jk02_24s;
  }
}

/// Setelan switch dari frame settings (0x01). Ini niat pengguna, bukan
/// kondisi MOSFET sebenarnya (yang bisa mati karena perlindungan).
class BmsSwitches {
  const BmsSwitches({required this.charge, required this.discharge, required this.balancer, required this.cellCount});
  final bool charge;
  final bool discharge;
  final bool balancer;
  final int cellCount;

  BmsSwitches copyWith({bool? charge, bool? discharge, bool? balancer}) => BmsSwitches(
        charge: charge ?? this.charge,
        discharge: discharge ?? this.discharge,
        balancer: balancer ?? this.balancer,
        cellCount: cellCount,
      );
}

class BmsReading {
  const BmsReading({
    required this.time,
    required this.protocol,
    required this.cellVoltages,
    required this.cellResistances,
    required this.totalVoltage,
    required this.current,
    required this.temp1,
    required this.temp2,
    required this.mosTemp,
    required this.errorsBitmask,
    required this.balanceCurrent,
    required this.balancing,
    required this.soc,
    required this.remainingAh,
    required this.nominalAh,
    required this.cycleCount,
    required this.cycleCapacityAh,
    required this.soh,
    required this.runtimeSeconds,
    required this.chargeEnabled,
    required this.dischargeEnabled,
    required this.heating,
    this.batteryTypeCode,
    this.detailLogCount,
    this.emergencySeconds,
  });

  final DateTime time;
  final JkProtocol protocol;
  final List<double> cellVoltages;
  final List<double> cellResistances;
  final double totalVoltage;

  /// Positif = mengisi (dicas), negatif = keluar (dipakai).
  final double current;
  final double temp1;
  final double temp2;
  final double mosTemp;
  final int errorsBitmask;
  final double balanceCurrent;
  final bool balancing;
  final int soc;
  final double remainingAh;
  final double nominalAh;
  final int cycleCount;
  final double cycleCapacityAh;
  final int soh;
  final int runtimeSeconds;
  final bool chargeEnabled;
  final bool dischargeEnabled;
  final bool heating;
  final int? batteryTypeCode;
  final int? detailLogCount;
  final int? emergencySeconds;

  int get cellCount => cellVoltages.length;
  double get power => totalVoltage * current;
  double get minCell => cellVoltages.isEmpty ? 0 : cellVoltages.reduce((a, b) => a < b ? a : b);
  double get maxCell => cellVoltages.isEmpty ? 0 : cellVoltages.reduce((a, b) => a > b ? a : b);
  double get deltaCell => maxCell - minCell;
  double get avgCell => cellVoltages.isEmpty ? 0 : cellVoltages.reduce((a, b) => a + b) / cellVoltages.length;
  int get minCellIndex => cellVoltages.indexOf(minCell);
  int get maxCellIndex => cellVoltages.indexOf(maxCell);
  double get maxTemp => [temp1, temp2, mosTemp].reduce((a, b) => a > b ? a : b);
  double get minTemp => [temp1, temp2].reduce((a, b) => a < b ? a : b);

  /// Tegangan nominal pack (LFP 3.2 V/sel) untuk menghitung energi.
  double get nominalPackVoltage => cellCount * 3.2;
  double get remainingWh => remainingAh * nominalPackVoltage;

  String get batteryTypeLabel => switch (batteryTypeCode) {
        0 => 'LFP',
        1 => 'Li-ion',
        2 => 'LTO',
        _ => 'LFP',
      };

  List<BmsAlarm> get alarms => BmsAlarm.fromBitmask(errorsBitmask);

  BmsReading copyWith({
    DateTime? time,
    List<double>? cellVoltages,
    double? totalVoltage,
    double? current,
    double? temp1,
    double? temp2,
    double? mosTemp,
    int? soc,
    double? remainingAh,
    bool? chargeEnabled,
    bool? dischargeEnabled,
    bool? balancing,
    int? errorsBitmask,
  }) =>
      BmsReading(
        time: time ?? this.time,
        protocol: protocol,
        cellVoltages: cellVoltages ?? this.cellVoltages,
        cellResistances: cellResistances,
        totalVoltage: totalVoltage ?? this.totalVoltage,
        current: current ?? this.current,
        temp1: temp1 ?? this.temp1,
        temp2: temp2 ?? this.temp2,
        mosTemp: mosTemp ?? this.mosTemp,
        errorsBitmask: errorsBitmask ?? this.errorsBitmask,
        balanceCurrent: balanceCurrent,
        balancing: balancing ?? this.balancing,
        soc: soc ?? this.soc,
        remainingAh: remainingAh ?? this.remainingAh,
        nominalAh: nominalAh,
        cycleCount: cycleCount,
        cycleCapacityAh: cycleCapacityAh,
        soh: soh,
        runtimeSeconds: runtimeSeconds,
        chargeEnabled: chargeEnabled ?? this.chargeEnabled,
        dischargeEnabled: dischargeEnabled ?? this.dischargeEnabled,
        heating: heating,
        batteryTypeCode: batteryTypeCode,
        detailLogCount: detailLogCount,
        emergencySeconds: emergencySeconds,
      );
}

enum AlarmLevel { info, warning, danger }

class BmsAlarm {
  const BmsAlarm(this.bit, this.title, this.advice, this.level);
  final int bit;
  final String title;
  final String advice;
  final AlarmLevel level;

  // Urutan bit mengikuti DEFAULT_ERRORS_JK02 di esphome-jk-bms.
  static const Map<int, BmsAlarm> table = {
    0: BmsAlarm(0, 'Kabel balancer bermasalah', 'Ada kabel sensor sel yang hambatannya tinggi atau longgar. Periksakan sambungan kabel balancer.', AlarmLevel.warning),
    1: BmsAlarm(1, 'MOSFET BMS terlalu panas', 'Kurangi beban / berhenti sebentar sampai BMS dingin.', AlarmLevel.danger),
    2: BmsAlarm(2, 'Jumlah sel tidak sesuai setelan', 'Jumlah sel terdeteksi berbeda dengan setelan BMS. Periksakan ke teknisi.', AlarmLevel.warning),
    4: BmsAlarm(4, 'Baterai sudah penuh', 'Pengisian berhenti otomatis. Charger boleh dicabut.', AlarmLevel.info),
    5: BmsAlarm(5, 'Tegangan pack terlalu tinggi', 'BMS memutus pengisian. Cabut charger dan cek charger Anda.', AlarmLevel.danger),
    6: BmsAlarm(6, 'Arus cas terlalu besar', 'Charger terlalu kuat untuk baterai ini.', AlarmLevel.danger),
    7: BmsAlarm(7, 'Korsleting saat mengecas', 'Cabut charger segera dan periksakan.', AlarmLevel.danger),
    8: BmsAlarm(8, 'Terlalu panas untuk dicas', 'Tunggu baterai dingin sebelum mengecas.', AlarmLevel.danger),
    9: BmsAlarm(9, 'Terlalu dingin untuk dicas', 'Baterai LFP tidak boleh dicas di bawah 0°C.', AlarmLevel.warning),
    10: BmsAlarm(10, 'Gangguan komunikasi internal BMS', 'Coba matikan-nyalakan BMS. Jika berulang, periksakan.', AlarmLevel.warning),
    11: BmsAlarm(11, 'Ada sel yang tegangannya terlalu rendah', 'Segera cas baterai.', AlarmLevel.danger),
    12: BmsAlarm(12, 'Baterai hampir habis total', 'BMS memutus daya untuk melindungi baterai. Segera cas.', AlarmLevel.danger),
    13: BmsAlarm(13, 'Arus pemakaian terlalu besar', 'Tarikan gas terlalu berat / beban berlebih. BMS memutus daya sementara.', AlarmLevel.danger),
    14: BmsAlarm(14, 'Korsleting saat dipakai', 'Matikan motor dan periksakan kelistrikan.', AlarmLevel.danger),
    15: BmsAlarm(15, 'Terlalu panas saat dipakai', 'Berhenti dan biarkan baterai dingin.', AlarmLevel.danger),
    16: BmsAlarm(16, 'MOSFET pengisian bermasalah', 'Periksakan BMS ke teknisi.', AlarmLevel.danger),
    17: BmsAlarm(17, 'MOSFET pemakaian bermasalah', 'Periksakan BMS ke teknisi.', AlarmLevel.danger),
    18: BmsAlarm(18, 'Modul GPS terputus', 'Abaikan jika Anda tidak memakai modul GPS.', AlarmLevel.info),
    19: BmsAlarm(19, 'Password BMS belum diganti', 'Hanya pengingat dari BMS. Aman diabaikan, atau ganti password di aplikasi JK.', AlarmLevel.info),
    20: BmsAlarm(20, 'Gagal menyalakan daya keluar', 'Coba matikan-nyalakan motor.', AlarmLevel.warning),
    21: BmsAlarm(21, 'Baterai terlalu panas', 'Berhenti, matikan motor, biarkan dingin.', AlarmLevel.danger),
    22: BmsAlarm(22, 'Sensor suhu bermasalah', 'Periksakan sambungan sensor suhu.', AlarmLevel.warning),
    23: BmsAlarm(23, 'Modul pre-charge bermasalah', 'Periksakan ke teknisi.', AlarmLevel.warning),
    24: BmsAlarm(24, 'Gagal pulih dari korsleting', 'Periksakan kelistrikan motor.', AlarmLevel.danger),
    25: BmsAlarm(25, 'Arus pemakaian berlebih (tingkat 2)', 'Kurangi beban.', AlarmLevel.danger),
    26: BmsAlarm(26, 'Arus pemakaian berlebih (tingkat 3)', 'Kurangi beban.', AlarmLevel.danger),
    27: BmsAlarm(27, 'Terlalu dingin untuk dipakai', 'Biarkan baterai hangat dulu.', AlarmLevel.warning),
    28: BmsAlarm(28, 'Dikunci jarak jauh (GPS)', 'Baterai dikunci lewat modul GPS.', AlarmLevel.warning),
  };

  static List<BmsAlarm> fromBitmask(int mask) {
    final list = <BmsAlarm>[];
    for (var bit = 0; bit < 32; bit++) {
      if ((mask >> bit) & 1 == 1) {
        final a = table[bit];
        if (a != null) list.add(a);
      }
    }
    list.sort((a, b) => b.level.index.compareTo(a.level.index));
    return list;
  }
}

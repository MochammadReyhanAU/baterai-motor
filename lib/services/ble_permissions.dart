import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Hasil pengecekan izin Bluetooth.
class PermissionResult {
  const PermissionResult(this.ok, [this.message, this.permanentlyDenied = false]);
  final bool ok;
  final String? message;
  final bool permanentlyDenied;
}

class BlePermissions {
  static int? _sdk;

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<int> androidSdk() async {
    if (_sdk != null) return _sdk!;
    final info = await DeviceInfoPlugin().androidInfo;
    return _sdk = info.version.sdkInt;
  }

  /// Android 11 ke bawah memerlukan Lokasi aktif untuk memindai BLE.
  static Future<bool> needsLocationService() async => isAndroid && await androidSdk() <= 30;

  /// Minta izin yang diperlukan. iOS menanyakan izin Bluetooth sendiri saat
  /// pertama kali memindai, jadi di iOS langsung dianggap OK.
  static Future<PermissionResult> ensure() async {
    if (!isAndroid) return const PermissionResult(true);
    final sdk = await androidSdk();
    if (sdk >= 31) {
      final s = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
      final denied = s.values.where((v) => !v.isGranted).toList();
      if (denied.isEmpty) return const PermissionResult(true);
      final permanent = denied.any((v) => v.isPermanentlyDenied);
      return PermissionResult(
        false,
        'Izin "Perangkat di sekitar" dibutuhkan untuk mencari baterai.'
        '${permanent ? ' Buka Setelan aplikasi › Izin › Perangkat di sekitar › Izinkan.' : ''}',
        permanent,
      );
    }
    final loc = await Permission.locationWhenInUse.request();
    if (loc.isGranted) return const PermissionResult(true);
    return PermissionResult(
      false,
      'Di Android versi ini, izin Lokasi wajib untuk mencari perangkat Bluetooth (aplikasi tidak memakai lokasi Anda).'
      '${loc.isPermanentlyDenied ? ' Buka Setelan aplikasi › Izin › Lokasi › Izinkan.' : ''}',
      loc.isPermanentlyDenied,
    );
  }

  static Future<void> openSettings() => openAppSettings();
}
